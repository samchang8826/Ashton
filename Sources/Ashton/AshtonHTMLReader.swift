//
//  AshtonHTMLReader.swift
//  Ashton
//
//  Created by Michael Schwarz on 17.09.17.
//  Copyright © 2017 Michael Schwarz. All rights reserved.
//

import Foundation
import CoreGraphics


final class AshtonHTMLReader: NSObject {

    private var attributesStack: [[NSAttributedString.Key: Any]] = []
    private var output: NSMutableAttributedString!
    private var parsedTags: [AshtonXMLParser.Tag] = []
    private var appendNewlineBeforeNextContent = false
    private let xmlParser = AshtonXMLParser()

    func decode(_ html: Ashton.HTML, defaultAttributes: [NSAttributedString.Key: Any] = [:]) -> NSAttributedString {
        self.output = NSMutableAttributedString()
        self.parsedTags = []
        self.appendNewlineBeforeNextContent = false
        self.attributesStack = [defaultAttributes]
        
        self.xmlParser.delegate = self
        self.xmlParser.parse(string: html)

        return self.output
    }

    func clearCaches() {
        FontBuilder.fontCache = [:]
        AshtonXMLParser.styleAttributesCache = [:]
    }
}

// MARK: - AshtonXMLParserDelegate

extension AshtonHTMLReader: AshtonXMLParserDelegate {
    
    func didParseContent(_ parser: AshtonXMLParser, string: String) {
        self.appendToOutput(string)
    }
    
    func didOpenTag(_ parser: AshtonXMLParser, name: AshtonXMLParser.Tag, attributes: [NSAttributedString.Key : Any]?) {
        if self.appendNewlineBeforeNextContent {
            self.appendToOutput("\n")
            self.appendNewlineBeforeNextContent = false
            self.attributesStack.removeLast()
        }

        var attributes = attributes ?? [:]
        let currentAttributes = self.attributesStack.last ?? [:]

        if let derivedFontBuilder = self.makeDerivedFontBuilder(forTag: name) {
            attributes[.font] = derivedFontBuilder.makeFont()
        }

        attributes.merge(currentAttributes, uniquingKeysWith: { (current, _) in current })

        self.attributesStack.append(attributes)
        self.parsedTags.append(name)
    }
    
    func didCloseTag(_ parser: AshtonXMLParser) {
        guard self.attributesStack.isEmpty == false, self.parsedTags.isEmpty == false else {
            return
        }

        if self.parsedTags.removeLast() == .p {
            if self.appendNewlineBeforeNextContent == true {
                self.appendToOutput("\n")
            } else {
                self.appendNewlineBeforeNextContent = true
            }
        } else {
            self.attributesStack.removeLast()
        }
    }
}

// MARK: - Private

private extension AshtonHTMLReader {

    func appendToOutput(_ string: String) {
        if let attributes = self.attributesStack.last, attributes.isEmpty == false {
            self.output.append(NSAttributedString(string: string, attributes: attributes))
        } else {
            self.output.append(NSAttributedString(string: string))
        }
    }

    func makeDerivedFontBuilder(forTag tag: AshtonXMLParser.Tag) -> FontBuilder? {
        guard tag == .strong || tag == .em else { return nil }
        guard let currentFont = self.attributesStack.last?[.font] as? Font else { return nil }

        let fontBuilder = FontBuilder()
        fontBuilder.configure(with: currentFont)
        fontBuilder.isBold = (tag == .strong)
        fontBuilder.isItalic = (tag == .em)
        return fontBuilder
    }
}

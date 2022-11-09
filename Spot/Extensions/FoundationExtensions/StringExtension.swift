//
//  StringExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/19/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation

public extension String {

    func indices(of string: String) -> [Int] {
        var indices = [Int]()
        var searchStartIndex = self.startIndex

        while searchStartIndex < self.endIndex,
            let range = self.range(of: string, range: searchStartIndex..<self.endIndex),
            !range.isEmpty {
            let index = distance(from: self.startIndex, to: range.lowerBound)
            indices.append(index)
            searchStartIndex = range.upperBound
        }

        return indices
    }

    func getKeywordArray() -> [String] {
        var keywords: [String] = []

        keywords.append(contentsOf: getKeywordsFrom(index: 0))
        let atIndexes = indices(of: " ")

        for index in atIndexes {
            if index == count - 1 { continue }
            keywords.append(contentsOf: getKeywordsFrom(index: index + 1))
        }

        return keywords
    }

    func getKeywordsFrom(index: Int) -> [String] {
        var keywords: [String] = []
        if index > count { return keywords }
        let subString = suffix(count - index)

        var word = ""
        for sub in subString {
            word = word + String(sub)
            keywords.append(word)
        }

        return keywords
    }

    /// Default value of 10.
    /// This is to match based on last 10 digits to eliminate country codes and formatting
    func formatNumber(numberOfDigits: Int = 10) -> String {
        var newNumber = components(separatedBy: CharacterSet.decimalDigits.inverted).joined() /// remove dashes and spaces
        newNumber = String(newNumber.suffix(numberOfDigits))
        return newNumber
    }

    func spacesTrimmed() -> String {
        var newString = self
        while newString.last?.isWhitespace ?? false { newString = String(newString.dropLast(1))}
        while newString.first?.isWhitespace ?? false { newString = String(newString.dropFirst(1))}
        return newString
    }

    func getAttributedText(boldString: String, font: UIFont) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(
            string: self,
            attributes: [NSAttributedString.Key.font: font]
        )
        let boldFontAttribute: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: UIFont(name: "SFCompactText-Heavy", size: font.pointSize) as Any
        ]
        let range = (self as NSString).range(of: boldString)
        attributedString.addAttributes(boldFontAttribute, range: range)
        return attributedString
    }
}

extension NSAttributedString {
    func shrinkLineHeight() -> NSAttributedString {
        let attributedString = NSMutableAttributedString(attributedString: self)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.lineHeightMultiple = 0.75
        paragraphStyle.alignment = .center
        attributedString.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: string.count)
        )
        
        return NSAttributedString(attributedString: attributedString)
    }
}

//
//  NSAttributedStringExtension.swift
//  Spot
//
//  Created by Kenny Barone on 12/30/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation

extension NSAttributedString {
    func shrinkLineHeight(multiple: CGFloat, kern: CGFloat) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(attributedString: self)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.lineHeightMultiple = multiple
        paragraphStyle.alignment = .center
        let range = NSRange(location: 0, length: string.count)
        attributedString.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: range
        )
        attributedString.addAttribute(
            .kern, value: kern,
            range: range
        )

        return NSAttributedString(attributedString: attributedString)
    }

    static func getAttString(
        caption: String,
        taggedFriends: [String],
        font: UIFont,
        maxWidth: CGFloat
    ) -> ((NSMutableAttributedString, [(rect: CGRect, username: String)])) {
        let attString = NSMutableAttributedString(string: caption)
        attString.addAttribute(NSAttributedString.Key.font, value: font, range: NSRange(0...attString.length - 1))

        var freshRect: [(rect: CGRect, username: String)] = []
        var tags: [(username: String, range: NSRange)] = []

        let words = caption.components(separatedBy: .whitespacesAndNewlines)
        for word in words {
            let username = String(word.dropFirst())
            if word.hasPrefix("@") && taggedFriends.contains(where: { $0 == username }) {
                /// get first index of this word
                let atIndexes = caption.indices(of: String(word))
                let currentIndex = atIndexes[0]
                /// make tag rect out of the username + @
                let tag = (username: String(word.dropFirst()), range: NSRange(location: currentIndex, length: word.count))
                if !tags.contains(where: { $0 == tag }) {
                    tags.append(tag)
                    let range = NSRange(location: currentIndex, length: word.count)
                    /// bolded range out of username + @
                    attString.addAttribute(NSAttributedString.Key.font, value: UIFont(name: "SFCompactText-Semibold", size: font.pointSize) as Any, range: range)
                }
            }
        }

        for tag in tags {
            var rect = (rect: getRect(str: attString, range: tag.range, maxWidth: maxWidth), username: tag.username)
            rect.0 = CGRect(x: rect.0.minX, y: rect.0.minY, width: rect.0.width, height: rect.0.height)

            if (!freshRect.contains(where: { $0 == rect })) {
                freshRect.append(rect)
            }
        }
        return ((attString, freshRect))
    }

    static func getRect(str: NSAttributedString, range: NSRange, maxWidth: CGFloat) -> CGRect {
        let textStorage = NSTextStorage(attributedString: str)
        let textContainer = NSTextContainer(size: CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude))
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        textContainer.lineFragmentPadding = 0
        let pointer = UnsafeMutablePointer<NSRange>.allocate(capacity: 1)
        layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: pointer)
        var rect = layoutManager.boundingRect(forGlyphRange: pointer.move(), in: textContainer)
        rect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
        return rect
    }
}

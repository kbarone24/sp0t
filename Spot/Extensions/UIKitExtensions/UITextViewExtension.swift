//
//  UITextViewExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

extension UITextView {

    // convert to nsRange in order to get correct cursor position with emojis
    func getCursorPosition() -> Int {
        var cursorPosition = 0
        if let selectedRange = selectedTextRange {
            let utfPosition = offset(from: beginningOfDocument, to: selectedRange.end)
            let positionRange = NSRange(location: 0, length: utfPosition)
            let stringOffset = Range(positionRange, in: text!)!
            let indexPosition = stringOffset.upperBound
            cursorPosition = text.distance(from: text.startIndex, to: indexPosition)
        }
        return cursorPosition
    }

    // run when user taps a username to tag
    func addUsernameAtCursor(username: String) {
        var tagText = text ?? ""
        let cursorPosition = getCursorPosition()

        var wordIndices = text.indices(of: " ")
        wordIndices.append(contentsOf: text.indices(of: "\n")) /// add new lines
        if !wordIndices.contains(0) { wordIndices.insert(0, at: 0) } /// first word not included
        wordIndices.sort(by: { $0 < $1 })

        var currentWordIndex = 0; var nextWordIndex = 0; var i = 0
        /// get current word
        for index in wordIndices where index < cursorPosition {
            if i == wordIndices.count - 1 { currentWordIndex = index; nextWordIndex = text.count } else if cursorPosition <= wordIndices[i + 1] { currentWordIndex = index; nextWordIndex = wordIndices[i + 1] }
            i += 1
        }

        let suffix = text.suffix(text.count - currentWordIndex) /// get end of string to figure out where @ is

        /// from index represents the text for this string after the @
        guard let atIndex = String(suffix).indices(of: "@").first else { return }
        let start = currentWordIndex + atIndex + 1
        let fromIndex = text.index(text.startIndex, offsetBy: start)

        /// word length = number of characters typed of the username so far
        let wordLength = nextWordIndex - currentWordIndex - 2
        /// remove any characters after the @

        /// patch fix for emojis not working at the end of strings -> start from end of string and work backwards
        if nextWordIndex == tagText.count {
            while tagText.last != "@" { tagText.removeLast() }
            tagText.append(contentsOf: username)

        } else {
            /// standard removal process with string.index -> string.index is fucked up if using emojis bc it uses utf16 characters so this might fail if you try to insert in the middle of a string with an emoji coming before it in that string but this is an edge case
            if wordLength > 0 {for _ in 0...wordLength - 1 { tagText.remove(at: fromIndex) } }
            /// insert username after @
            tagText.insert(contentsOf: username, at: fromIndex) //// append username
        }

        text = tagText
    }
}

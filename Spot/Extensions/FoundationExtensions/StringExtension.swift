//
//  StringExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/19/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import CoreLocation

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
            word += String(sub)
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

    func isValidUsername() -> Bool {
        let regEx = "^[a-zA-Z0-9_.]*$"
        let pred = NSPredicate(format: "SELF MATCHES %@", regEx)
        return pred.evaluate(with: self) && count > 1
    }

    func isValidEmail() -> Bool {
        let regEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let pred = NSPredicate(format: "SELF MATCHES %@", regEx)
        return pred.evaluate(with: self)
    }

    func getTagUserString(cursorPosition: Int) -> (text: String, containsAt: Bool) {
        let atIndices = indices(of: "@")
        var wordIndices = indices(of: " ")
        wordIndices.append(contentsOf: indices(of: "\n")) /// add new lines
        if !wordIndices.contains(0) { wordIndices.insert(0, at: 0) } /// first word not included
        wordIndices.sort(by: { $0 < $1 })

        for atIndex in atIndices where cursorPosition > atIndex {
            var i = 0
            for w in wordIndices {
                // cursor is > current word, < next word, @ is 1 more than current word , < next word OR last word in string
                if (w <= cursorPosition
                    && (i == wordIndices.count - 1
                        || cursorPosition <= wordIndices[i + 1]))
                    && ((atIndex == 0 && i == 0
                         || atIndex == w + 1)
                        && (i == wordIndices.count - 1
                            || cursorPosition <= wordIndices[i + 1])) {

                    let start = index(startIndex, offsetBy: w)
                    let end = index(startIndex, offsetBy: cursorPosition)
                    let range = start..<end
                    let currentWord = self[range].replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "@", with: "").replacingOccurrences(of: "\n", with: "")
                    return (currentWord, true)
                } else { i += 1; continue }
            }
        }
        return ("", false)
    }

    func getCoordinate(completion: @escaping(_ coordinate: CLLocationCoordinate2D?, _ error: Error?) -> Void ) {
        CLGeocoder().geocodeAddressString(self) {
            completion($0?.first?.location?.coordinate, $1)
        }
    }

    func getAttributedStringWithImage(image: UIImage) -> NSMutableAttributedString {
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = image
        imageAttachment.bounds = CGRect(x: 0, y: 3, width: imageAttachment.image?.size.width ?? 0, height: imageAttachment.image?.size.height ?? 0)
        let attachmentString = NSAttributedString(attachment: imageAttachment)
        let completeText = NSMutableAttributedString(string: "")
        completeText.append(attachmentString)
        completeText.append(NSAttributedString(string: " "))
        completeText.append(NSAttributedString(string: self))
        return completeText
    }

    internal func getQueriedUsers(userList: [UserProfile]) -> [UserProfile] {
        let searchText = self
        var queriedUsers: [UserProfile] = []
        let usernameList = userList.map({ $0.username })
        let nameList = userList.map({ $0.name })

        let filteredUsernames = searchText.isEmpty ? usernameList : usernameList.filter({(dataString: String) -> Bool in
            // If dataItem matches the searchText, return true to include it
            return dataString.range(of: searchText, options: [.anchored, .caseInsensitive]) != nil
        })

        let filteredNames = searchText.isEmpty ? nameList : nameList.filter({(dataString: String) -> Bool in
            return dataString.range(of: searchText, options: [.anchored, .caseInsensitive]) != nil
        })

        for username in filteredUsernames {
            if let user = userList.first(where: { $0.username == username }) { queriedUsers.append(user) }
        }

        for name in filteredNames {
            if let user = userList.first(where: { $0.name == name }) {
                if !queriedUsers.contains(where: { $0.id == user.id }) { queriedUsers.append(user) }
            }
        }
        return queriedUsers
    }

    func isBlocked() -> Bool {
        let userID = self
        return (UserDataModel.shared.userInfo.blockedBy?.contains(userID) ?? false) || (UserDataModel.shared.userInfo.blockedUsers?.contains(userID) ?? false)
    }

    internal func getTaggedUsers() -> [UserProfile] {
        var selectedUsers: [UserProfile] = []
        let words = self.components(separatedBy: .whitespacesAndNewlines)
        for w in words {
            let username = String(w.dropFirst())
            if w.hasPrefix("@") {
                if let f = UserDataModel.shared.userInfo.friendsList.first(where: { $0.username == username }) {
                    selectedUsers.append(f)
                }
            }
        }
        return selectedUsers
    }

    func getCaptionHeight(fontSize: CGFloat, maxCaption: CGFloat) -> CGFloat {
        let caption = self
        let tempLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 88, height: UIScreen.main.bounds.height))
        tempLabel.text = caption
        tempLabel.font = UIFont(name: "SFCompactText-Medium", size: fontSize)
        tempLabel.numberOfLines = 0
        tempLabel.lineBreakMode = .byWordWrapping
        tempLabel.sizeToFit()

        return maxCaption != 0 ? min(maxCaption, tempLabel.frame.height.rounded(.up)) : tempLabel.frame.height.rounded(.up)
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

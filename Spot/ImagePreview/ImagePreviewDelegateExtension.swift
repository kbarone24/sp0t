//
//  ImagePreviewDelegateExtension.swift
//  Spot
//
//  Created by Kenny Barone on 11/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

extension ImagePreviewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // cancel caption tap when textView is open
        if gestureRecognizer.accessibilityValue == "caption_tap" && textView.isFirstResponder {
            return false
        }
        
        if gestureRecognizer.accessibilityValue == "tap_to_close" {
            return false
        }
        
        return true
    }
}

extension ImagePreviewController: ChooseSpotDelegate {
    func finishPassing(spot: MapSpot?) {
        cancelOnDismiss = false
        if spot != nil {
            UploadPostModel.shared.setSpotValues(spot: spot)
            spotNameButton.spotName = spot?.spotName ?? ""
        } else {
            newSpotNameView.textView.becomeFirstResponder()
        }

    }
    func cancelSpotSelection() {
        UploadPostModel.shared.setSpotValues(spot: nil)
        spotNameButton.spotName = nil
    }
 }

extension ImagePreviewController: TagFriendsDelegate {
    func finishPassing(selectedUser: UserProfile) {
        textView.addUsernameAtCursor(username: selectedUser.username)
        removeTagTable()
    }
}

extension ImagePreviewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        HapticGenerator.shared.play(.medium)
        swipeToClose.isEnabled = true
        tapToClose.isEnabled = true
        if textView.text == textViewPlaceholder { textView.text = ""; textView.alpha = 1.0 }
        textView.isUserInteractionEnabled = true

       atButton.isHidden = false
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        swipeToClose.isEnabled = false
        tapToClose.isEnabled = false
        if textView.text == "" { textView.text = textViewPlaceholder; textView.alpha = 0.6 }
        textView.isUserInteractionEnabled = false

        atButton.isHidden = true
        removeTagTable()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // return on done button tap
        if text == "\n" { textView.endEditing(true); return false }

        let maxLines: CGFloat = 6
        let maxHeight: CGFloat = (textView.font?.lineHeight ?? 0) * maxLines + 30 // lineheight * # lines  + textContainer insets

        let currentText = textView.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: text)

        let val = getCaptionHeight(text: updatedText) <= maxHeight
        return val
    }

    func textViewDidChange(_ textView: UITextView) {
        let cursor = textView.getCursorPosition()
        let text = textView.text ?? ""
        let tagTuple = text.getTagUserString(cursorPosition: cursor)
        let tagString = tagTuple.text
        let containsAt = tagTuple.containsAt
        if !containsAt {
            removeTagTable()
            textView.autocorrectionType = .default
        } else {
            addTagTable(tagString: tagString)
            textView.autocorrectionType = .no
        }
    }

    func removeTagTable() {
        tagFriendsView.removeFromSuperview()
        spotNameButton.isHidden = false
    }

    func addTagTable(tagString: String) {
        tagFriendsView.setUp(userList: UserDataModel.shared.userInfo.friendsList, textColor: .white, delegate: self, searchText: tagString)
        postDetailView.addSubview(tagFriendsView)
        tagFriendsView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(90)
            $0.bottom.equalTo(spotNameButton.snp.bottom)
        }
        
        spotNameButton.isHidden = true
    }

    func getCaptionHeight(text: String) -> CGFloat {
        let temp = UITextView(frame: textView.frame)
        temp.text = text
        temp.font = UIFont(name: "SFCompactText-Regular", size: 19)
        temp.textContainerInset = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        temp.isScrollEnabled = false
        temp.textContainer.maximumNumberOfLines = 6

        let size = temp.sizeThatFits(CGSize(width: temp.bounds.width, height: UIScreen.main.bounds.height))
        return max(51, size.height)
    }

    @objc func swipeToClose(_ sender: UIPanGestureRecognizer) {
        if !self.textView.isFirstResponder { return }
        let direction = sender.velocity(in: view)

        if abs(direction.y) > 100 {
            textView.resignFirstResponder()
            swipeToClose.isEnabled = false
            tapToClose.isEnabled = false
        }
    }

    @objc func tapToClose(_ sender: UITapGestureRecognizer) {
        if !self.textView.isFirstResponder { return }
        print("frame y", sender.location(in: postDetailView).y)
        if sender.location(in: postDetailView).y > spotNameButton.frame.minY { print(">"); return }
        textView.resignFirstResponder()
        swipeToClose.isEnabled = false
        tapToClose.isEnabled = false
    }
}

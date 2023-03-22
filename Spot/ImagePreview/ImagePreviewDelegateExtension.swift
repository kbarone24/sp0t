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

extension ImagePreviewController: PostAccessoryDelegate {
    func cancelSpot() {
        newSpotNameView.textView.text = ""
        UploadPostModel.shared.setSpotValues(spot: nil)
        spotNameButton.name = nil
    }

    func cancelMap() {
        UploadPostModel.shared.setMapValues(map: nil)
        mapNameButton.name = nil
        newMapMode = false
    }
}

extension ImagePreviewController: ChooseSpotDelegate {
    func toggle(cancel: Bool) {
        cancelOnDismiss = cancel
    }

    func finishPassing(spot: MapSpot?) {
        cancelOnDismiss = false
        if spot != nil {
            UploadPostModel.shared.setSpotValues(spot: spot)
            spotNameButton.name = spot?.spotName ?? ""
        } else {
            newSpotNameView.textView.becomeFirstResponder()
        }
    }
 }

extension ImagePreviewController: ChooseMapDelegate {
    func finishPassing(map: CustomMap?) {
        if let map {
            UploadPostModel.shared.setMapValues(map: map)
            mapNameButton.name = map.mapName
        } else {
            launchNewMap()
        }
    }

    func launchNewMap() {
        DispatchQueue.main.async {
            let mapObject = self.newMapMode ? UploadPostModel.shared.mapObject : nil
            let vc = NewMapController(mapObject: mapObject, newMapMode: false)
            vc.delegate = self
            self.present(vc, animated: true)
        }
    }
}

extension ImagePreviewController: NewMapDelegate {
    func finishPassing(map: CustomMap) {
        newMapMode = true
        UploadPostModel.shared.setMapValues(map: map)
        mapNameButton.name = map.mapName
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
        return textView.shouldChangeText(range: range, replacementText: text, maxChar: 350)
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
    }

    func addTagTable(tagString: String) {
        tagFriendsView.setUp(userList: UserDataModel.shared.userInfo.friendsList, textColor: .white, delegate: self, searchText: tagString)
        postDetailView.addSubview(tagFriendsView)
        tagFriendsView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(90)
            $0.bottom.equalTo(textView.snp.top)
        }
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
        if sender.location(in: postDetailView).y > spotNameButton.frame.minY { return }
        textView.resignFirstResponder()
        swipeToClose.isEnabled = false
        tapToClose.isEnabled = false
    }
}

//
//  NewMapDelegate.swift
//  Spot
//
//  Created by Kenny Barone on 2/21/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel

extension NewMapController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        return updatedText.count <= 50
    }

    func textFieldDidChangeSelection(_ textField: UITextField) {
        createButton?.isEnabled = textField.text?.trimmingCharacters(in: .whitespaces).count ?? 0 > 0
        nextButton?.isEnabled = textField.text?.trimmingCharacters(in: .whitespaces).count ?? 0 > 0
     //   textField.attributedText = NSAttributedString(string: textField.text ?? "")
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        keyboardPan.isEnabled = true
        readyToDismiss = false
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        keyboardPan.isEnabled = false
        readyToDismiss = true
    }
}

extension NewMapController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (mapObject?.memberIDs.count ?? 0) + 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MapMemberCell", for: indexPath) as? MapMemberCell else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "Default", for: indexPath)
        }
        if indexPath.row == 0 {
            let user = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: "")
            cell.cellSetUp(user: user)
        } else {
            guard let profile = mapObject?.memberProfiles?[safe: indexPath.row - 1] else { return cell }
            cell.cellSetUp(user: profile)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let friendsList = UserDataModel.shared.userInfo.getSelectedFriends(memberIDs: mapObject?.memberIDs ?? [])
        let vc = FriendsListController(
            parentVC: .newMap,
            allowsSelection: true,
            showsSearchBar: true,
            canAddFriends: false,
            friendIDs: UserDataModel.shared.userInfo.friendIDs,
            friendsList: friendsList,
            confirmedIDs: UploadPostModel.shared.postObject?.addedUsers ?? []
        )
        vc.delegate = self
        present(vc, animated: true)
    }
}

extension NewMapController: PrivacySliderDelegate {
    func finishPassing(rawPosition: Int) {
        mapPrivacyView.set(privacyLevel: UploadPrivacyLevel(rawValue: rawPosition) ?? .Private)
        togglePrivacy(tag: rawPosition)
    }
}

extension NewMapController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        return readyToDismiss
    }
}

extension NewMapController: FriendsListDelegate {
    func finishPassing(openProfile: UserProfile) {
        return
    }

    func finishPassing(selectedUsers: [UserProfile]) {
        var members = selectedUsers
        members.append(UserDataModel.shared.userInfo)
        let memberIDs = members.map({ $0.id ?? "" })
        mapObject?.memberIDs = memberIDs
        mapObject?.likers = memberIDs
        mapObject?.memberProfiles = members
        DispatchQueue.main.async { self.collaboratorsCollection.reloadData() }
    }
}

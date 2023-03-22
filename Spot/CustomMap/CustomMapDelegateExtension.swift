//
//  CustomMapDelegateExtension.swift
//  Spot
//
//  Created by Kenny Barone on 9/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import MapKit
import UIKit
import Mixpanel

extension CustomMapController: CustomMapHeaderDelegate {
    func openFriendsList(add: Bool) {
        guard let mapData = mapData else { return }
        let friendsList = UserDataModel.shared.userInfo.getSelectedFriends(memberIDs: mapData.memberIDs)
        // add = user is adding friends to the map (show friends). !add = user is viewing map members
        let friendsVC = FriendsListController(
            parentVC: add ? .mapAdd : .mapMembers,
            allowsSelection: add,
            showsSearchBar: add,
            canAddFriends: !add,
            friendIDs: add ? UserDataModel.shared.userInfo.friendIDs : mapData.memberIDs,
            friendsList: add ? friendsList : [],
            confirmedIDs: add ? mapData.memberIDs : []
        )
        friendsVC.delegate = self
        DispatchQueue.main.async { self.present(friendsVC, animated: true) }
    }

    func openEditMap() {
        guard let mapData = mapData else { return }
        let editVC = EditMapController(mapData: mapData)
        editVC.customMapVC = self
        editVC.modalPresentationStyle = .fullScreen
        present(editVC, animated: true)
    }

    func addDetailsActionSheet() {
        //TODO: enable user to delete map
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(
            UIAlertAction(title: "Share map", style: .default) { [weak self] _ in
                //TODO: enable user to share map
                print("share map tap")
            })
        if mapData?.founderID == UserDataModel.shared.uid {
            alert.addAction(
                UIAlertAction(title: "Edit map", style: .default) { [weak self] _ in
                    self?.openEditMap()
                })
        } else {
            alert.addAction(
                UIAlertAction(title: "Report map", style: .destructive) { [weak self] _ in
                    self?.reportMap()
                })
        }
        alert.addAction(
            UIAlertAction(title: "Dismiss", style: .cancel) { _ in
            })
        present(alert, animated: true)
    }

    func addUnfollowActionSheet(following: Bool) {
        let alertAction = following ? "Unfollow map" : "Leave map"
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: alertAction, style: .destructive, handler: { (_) in
            self.showUnfollowAlert(following: following)
        }))
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: { (_) in }))
        DispatchQueue.main.async { self.present(alert, animated: true) }
    }

    func followMap() {
        Mixpanel.mainInstance().track(event: "CustomMapFollowMap")
        mapData?.likers.append(UserDataModel.shared.uid)
        if mapData?.communityMap ?? false {
            mapData?.memberIDs.append(UserDataModel.shared.uid)
        }
        if firstMaxFourMapMemberList.count < 4 {
            firstMaxFourMapMemberList.append(UserDataModel.shared.userInfo)
        }

        guard let mapData else { return }
        UserDataModel.shared.userInfo.mapsList.append(mapData)
        mapService?.followMap(customMap: mapData, completion: { _ in })
        sendEditNotification()

        DispatchQueue.main.async { self.collectionView.reloadData() }
    }

    private func sendEditNotification() {
        guard let mapData = mapData else { return }
        NotificationCenter.default.post(Notification(name: Notification.Name("EditMap"), object: nil, userInfo: ["map": mapData as Any]))
    }

    private func reportMap() {
        let alertController = UIAlertController(title: "Report map", message: nil, preferredStyle: .alert)

        alertController.addAction(
            UIAlertAction(title: "Report", style: .destructive) { [weak self] _ in
                if let txtField = alertController.textFields?.first, let text = txtField.text {
                    Mixpanel.mainInstance().track(event: "ReportMapTap")
                    self?.mapService?.reportMap(mapID: self?.mapData?.id ?? "", feedbackText: text, userID: UserDataModel.shared.uid)
                    self?.showConfirmationAction()
                    Mixpanel.mainInstance().track(event: "CustomMapReportTap")
                }
            }
        )

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
            Mixpanel.mainInstance().track(event: "CustomMapReportCancelTap")
        }))
        alertController.addTextField { (textField) in
            textField.autocorrectionType = .default
            textField.placeholder = "Why are you reporting this map?"
        }

        present(alertController, animated: true, completion: nil)
    }

    private func showConfirmationAction() {
        let text = "Thank you for the feedback. We will review your report ASAP."
        let alert = UIAlertController(title: "Success!", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default))
        present(alert, animated: true, completion: nil)
    }

    private func showUnfollowAlert(following: Bool) {
        let title = following ? "Unfollow this map?" : "Leave this map?"
        let alert = UIAlertController(title: title, message: "", preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = .light

        let actionTitle = following ? "Unfollow" : "Leave"
        let unfollowAction = UIAlertAction(title: actionTitle, style: .destructive) { _ in
            self.unfollowMap()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)
        alert.addAction(unfollowAction)
        DispatchQueue.main.async { self.present(alert, animated: true) }
    }

    private func unfollowMap() {
        guard let userIndex = self.mapData?.likers.firstIndex(of: UserDataModel.shared.uid) else { return }
        Mixpanel.mainInstance().track(event: "CustomMapUnfollow")

        mapData?.likers.remove(at: userIndex)
        if let memberIndex = self.mapData?.memberIDs.firstIndex(of: UserDataModel.shared.uid) {
            mapData?.memberIDs.remove(at: memberIndex)
        }
        if let i = firstMaxFourMapMemberList.firstIndex(where: { $0.id == uid }) {
            firstMaxFourMapMemberList.remove(at: i)
        }
        UserDataModel.shared.userInfo.mapsList.removeAll(where: { $0.id == self.mapData?.id ?? "_" })

        guard let mapData else { return }
        mapService?.leaveMap(customMap: mapData, completion: { _ in })
        sendEditNotification()

        DispatchQueue.main.async { self.collectionView.reloadData() }
    }
}

extension CustomMapController: FriendsListDelegate {
    func finishPassing(openProfile: UserProfile) {
        let profileVC = ProfileViewController(userProfile: openProfile)
        DispatchQueue.main.async { self.navigationController?.pushViewController(profileVC, animated: true) }
    }

    func finishPassing(selectedUsers: [UserProfile]) {
        Mixpanel.mainInstance().track(event: "CustomMapInviteFriendsComplete")
        var addedUserIDs: [String] = []
        for user in selectedUsers {
            if !(mapData?.memberIDs.contains(where: { $0 == user.id ?? "_" }) ?? false) {
                mapData?.memberIDs.append(user.id ?? "")
                addedUserIDs.append(user.id ?? "")
            }
            if !(mapData?.likers.contains(where: { $0 == user.id ?? "_" }) ?? false) { mapData?.likers.append(user.id ?? "") }
        }
        addNewUsersInDB(addedUsers: addedUserIDs)
    }

    private func addNewUsersInDB(addedUsers: [String]) {
        guard let mapData = mapData else { return }
        sendEditNotification()
        mapService?.addNewUsersToMap(customMap: mapData, addedUsers: addedUsers)
    }
}

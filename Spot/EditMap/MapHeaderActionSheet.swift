//
//  MapHeaderActionSheet.swift
//  Spot
//
//  Created by Kenny Barone on 10/20/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation
import Mixpanel
import UIKit

extension CustomMapHeaderCell {
    func addActionSheet() {
        let following = actionButton.titleLabel?.text == "Following"
        let alertAction = following ? "Unfollow map" : "Leave map"
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: alertAction, style: .destructive, handler: { (_) in
            self.showUnfollowAlert()
        }))
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: { (_) in
            print("User click Dismiss button")
        }))
        guard let vc = viewContainingController() as? CustomMapController else { return }
        vc.present(alert, animated: true)
    }

    func showUnfollowAlert() {
        let following = actionButton.titleLabel?.text == "Following"
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
        let containerVC = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? UIViewController()
        containerVC.present(alert, animated: true)
    }

    func unfollowMap() {
        Mixpanel.mainInstance().track(event: "CustomMapUnfollow")
        guard let userIndex = self.mapData?.likers.firstIndex(of: UserDataModel.shared.uid) else { return }
        mapData?.likers.remove(at: userIndex)
        if let memberIndex = self.mapData?.memberIDs.firstIndex(of: UserDataModel.shared.uid) {
            mapData?.memberIDs.remove(at: memberIndex)
        }

        UserDataModel.shared.userInfo.mapsList.removeAll(where: { $0.id == self.mapData?.id ?? "_" })

        let db = Firestore.firestore()
        let mapsRef = db.collection("maps").document(mapData?.id ?? "")
        mapsRef.updateData(["likers": FieldValue.arrayRemove([UserDataModel.shared.uid]), "memberIDs": FieldValue.arrayRemove([UserDataModel.shared.uid])])
        sendEditNotification()
    }
}

//
//  ProfileActionSheet.swift
//  Spot
//
//  Created by Kenny Barone on 10/20/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import FirebaseFirestore
import Mixpanel
import UIKit
import Firebase

extension ProfileViewController {
    func addOptionsActionSheet() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if relation == .blocked {
            alert.addAction(UIAlertAction(title: "Unblock user", style: .default) { (_) in
                self.showUnblockUserAlert()
            })
        } else {
            alert.addAction(UIAlertAction(title: "Block user", style: .destructive) { (_) in
                self.showBlockUserAlert()
            })
        }
        alert.addAction(UIAlertAction(title: "Report user", style: .destructive) { (_) in
            self.showReportUserAlert()
        })
        if relation == .friend {
            alert.addAction(UIAlertAction(title: "Remove friend", style: .destructive) { (_) in
                self.showRemoveFriendAlert()
            })
        }
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        present(alert, animated: true)
    }

    func addRemoveFriendActionSheet() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Remove friend", style: .destructive) { (_) in
            self.showRemoveFriendAlert()
        })
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        present(alert, animated: true)
    }

    func showRemoveFriendAlert() {
        let alert = UIAlertController(title: "Remove friend?", message: "", preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = .light
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { _ in
            self.removeFriend(blocked: false)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func showBlockUserAlert() {
        let message = relation == .friend ? "Blocking \(userProfile?.username ?? "") will also remove them as a friend." : ""
        let alert = UIAlertController(title: "Block \(userProfile?.username ?? "")?", message: message, preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = .light
        alert.addAction(UIAlertAction(title: "Block", style: .destructive) { _ in
              self.blockUser()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func showUnblockUserAlert() {
        let alert = UIAlertController(title: "Unblock user?", message: "", preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = .light
        alert.addAction(UIAlertAction(title: "Unblock", style: .destructive) { _ in
              self.unblockUser()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func showReportUserAlert() {
        let alert = UIAlertController(title: "Report user?", message: "", preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = .light
        alert.addAction(UIAlertAction(title: "Report user", style: .destructive, handler: { (_) in
            if let txtField = alert.textFields?.first, let text = txtField.text {
                Mixpanel.mainInstance().track(event: "ReportUserTap")
                let db = Firestore.firestore()
                db.collection("feedback").addDocument(data: [
                    "feedbackText": text,
                    "reportedUserID": self.userProfile?.id ?? "",
                    "type": "reportUser",
                    "reporterID": UserDataModel.shared.uid
                ])
                self.showConfirmationAction(block: false)
            }
        }))
        alert.addTextField { (textField) in
            textField.autocorrectionType = .default
            textField.placeholder = "Why are you reporting this user?"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func showConfirmationAction(block: Bool) {
        let text = block ? "User successfully blocked." : "Thank you for the feedback. We will review your report ASAP."
        let alert = UIAlertController(title: "Success!", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default) { _ in
            DispatchQueue.main.async { self.navigationController?.popViewController(animated: true) }
        })
        present(alert, animated: true, completion: nil)
    }

    func removeFriend(blocked: Bool) {
        Mixpanel.mainInstance().track(event: "RemoveFriend")
        guard let userID = userProfile?.id,
              let friendsService = try? ServiceContainer.shared.service(for: \.friendsService)  else {
            return
        }
        
        friendsService.removeFriend(friendID: userID)
        NotificationCenter.default.post(name: NSNotification.Name("FriendRemove"), object: nil, userInfo: ["userID": userID])
        relation = blocked ? .blocked : .stranger
        DispatchQueue.main.async { self.collectionView.reloadData() }
    }

    func blockUser() {
        Mixpanel.mainInstance().track(event: "BlockUser")
        if relation == .friend {
            self.removeFriend(blocked: true)
        } else {
            relation = .blocked
            DispatchQueue.main.async { self.collectionView.reloadData() }
        }
        UserDataModel.shared.userInfo.blockedUsers?.append(userProfile?.id ?? "")
        NotificationCenter.default.post(name: NSNotification.Name("BlockUser"), object: nil, userInfo: ["userID": userProfile?.id ?? ""])
        blockUserInDB()
        self.showConfirmationAction(block: true)
    }

    func blockUserInDB() {
        let db = Firestore.firestore()
        guard let userID = userProfile?.id else { return }
        db.collection("users").document(UserDataModel.shared.uid).updateData([
            "blockedUsers": FieldValue.arrayUnion([userID])
        ])
        db.collection("users").document(userID).updateData([
            "blockedBy": FieldValue.arrayUnion([UserDataModel.shared.uid])
        ])
    }

    func unblockUser() {
        Mixpanel.mainInstance().track(event: "Unblock user")
        unblockUserDB()
        relation = .stranger
        UserDataModel.shared.userInfo.blockedUsers?.removeAll(where: { $0 == userProfile?.id ?? "" })
        DispatchQueue.main.async { self.collectionView.reloadData() }
    }

    func unblockUserDB() {
        let db = Firestore.firestore()
        guard let userID = userProfile?.id else { return }
        db.collection("users").document(UserDataModel.shared.uid).updateData([
            "blockedUsers": FieldValue.arrayRemove([userID])
        ])
        db.collection("users").document(userID).updateData([
            "blockedBy": FieldValue.arrayRemove([UserDataModel.shared.uid])
        ])
    }
}

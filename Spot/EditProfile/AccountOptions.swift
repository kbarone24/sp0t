//
//  AccountOptions.swift
//  Spot
//
//  Created by Kenny Barone on 11/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import Mixpanel
import Firebase
import FirebaseAuth
import FirebaseFirestore

protocol DeleteAccountDelegate: AnyObject {
    func finishPassing()
}

extension EditProfileViewController: DeleteAccountDelegate {
    @objc func addActionSheet() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Logout", style: .default, handler: { (_) in
            self.addLogoutAlert()
        }))
        alert.addAction(UIAlertAction(title: "Delete account", style: .destructive, handler: { (_) in
            self.addDeleteAlert()
        }))
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        present(alert, animated: true)
    }

    func addLogoutAlert() {
        let alert = UIAlertController(title: "Are you sure you want to log out?", message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Log out", style: .default, handler: { _ in
            Mixpanel.mainInstance().track(event: "Logout")
            do {
                try Auth.auth().signOut()
                DispatchQueue.main.async {
                    self.returnToLandingPage()
                }
            } catch let signOutError as NSError {
                print("Error signing out: %@", signOutError)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        DispatchQueue.main.async { self.present(alert, animated: true) }
    }

    func addDeleteAlert() {
        let alert = UIAlertController(title: "Delete account", message: "Are you sure you want to delete your account? This action cannot be undone.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Delete",
                                      style: .destructive,
                                      handler: {(_: UIAlertAction) in
            Mixpanel.mainInstance().track(event: "DeleteAccountTap")
            self.askForCode()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default))
        DispatchQueue.main.async { self.present(alert, animated: true) }
    }

    func addConfirmAction() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Success", message: "Account successfully deleted", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: {_ in
                self.returnToLandingPage()
            }))
            self.present(alert, animated: true)
        }
    }

    func askForCode() {
        PhoneAuthProvider.provider().verifyPhoneNumber(UserDataModel.shared.userInfo.phone ?? "", uiDelegate: nil) { (verificationID, _) in
            if let verificationID = verificationID {
                let vc = ConfirmCodeController()
                vc.verificationID = verificationID
                vc.codeType = .deleteAccount
                vc.deleteAccountDelegate = self
                DispatchQueue.main.async { self.present(vc, animated: true) }
            } else {
                self.showErrorMessage()
            }
        }
    }

    func showErrorMessage() {
        let alert = UIAlertController()
        alert.title = "Authentication error"
        alert.message = "We were unable to validate your credentials. Please email contact@sp0t.app for help."
        present(alert, animated: true)
    }

    func finishPassing() {
        deleteAccount()
    }

    func deleteAccount() {
        guard let friendsService = try? ServiceContainer.shared.service(for: \.friendsService) else {
            return
        }
        
        DispatchQueue.main.async {
            self.activityIndicator.startAnimating()
        }
        
        // delete from friends' friendsList
        for id in UserDataModel.shared.userInfo.friendIDs {
            friendsService.removeFriendFromFriendsList(userID: id, friendID: UserDataModel.shared.uid)
        }

        let dispatch = DispatchGroup()
        dispatch.enter()
        dispatch.enter()
        dispatch.enter()
        deleteUserFromUsernames { _ in
            dispatch.leave()
        }
        deleteUserFromMaps { _ in
            dispatch.leave()
        }
        deleteUserFromNotifications { _ in
            dispatch.leave()
        }

        dispatch.notify(queue: .main) {
            self.activityIndicator.stopAnimating()
            // delete profile
            self.db.collection("users").document(UserDataModel.shared.uid).delete()
            // delete number from user defaults
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: "phoneNumber")
            // deauthenticate
            let user = Auth.auth().currentUser
            user?.delete { error in
                if error == nil {
                    self.addConfirmAction()
                }
            }
        }
    }

    private func deleteUserFromMaps(completion: @escaping (_ done: Bool) -> Void) {
        let uid = UserDataModel.shared.uid
        db.collection("maps").whereField("likers", arrayContains: uid).getDocuments { snap, _ in
            guard let snap = snap else { completion(false); return }
            for doc in snap.documents {
                doc.reference.updateData(["memberIDs": FieldValue.arrayRemove([uid]), "likers": FieldValue.arrayRemove([uid])])
            }
            completion(true)
        }
    }

    private func deleteUserFromNotifications(completion: @escaping (_ done: Bool) -> Void) {
        db.collection("users").document(UserDataModel.shared.uid).collection("notifications").getDocuments { snap, _ in
            guard let snap = snap else { completion(false); return }
            for doc in snap.documents {
                doc.reference.delete()
            }
            completion(true)
        }
    }

    private func deleteUserFromUsernames(completion: @escaping (_ done: Bool) -> Void) {
        db.collection("usernames").whereField("username", isEqualTo: UserDataModel.shared.userInfo.username).getDocuments { snap, _ in
            if let doc = snap?.documents.first {
                doc.reference.delete()
            }
            completion(true)
        }
    }
}

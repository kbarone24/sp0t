//
//  ProfileActionSheet.swift
//  Spot
//
//  Created by Kenny Barone on 8/11/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel

extension ProfileViewController {
    func addOptionsActionSheet() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if viewModel.cachedProfile.friendStatus == .blocked {
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
        if viewModel.cachedProfile.friendStatus == .friends {
            alert.addAction(UIAlertAction(title: "Remove friend", style: .destructive) { (_) in
                self.showRemoveFriendAlert()
            })
        }
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        present(alert, animated: true)
    }

    func showRemoveFriendAlert() {
        let alert = UIAlertController(title: "Remove friend?", message: "", preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = .light
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { _ in
            Mixpanel.mainInstance().track(event: "ProfileRemoveFriendConfirm")
            self.viewModel.removeFriend()
            self.refresh.send(false)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func showBlockUserAlert() {
        let alert = UIAlertController(title: "Block \(viewModel.cachedProfile.username)?", message: "", preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = .light
        alert.addAction(UIAlertAction(title: "Block", style: .destructive) { _ in
            Mixpanel.mainInstance().track(event: "ProfileBlockUserConfirm")
            self.viewModel.blockUser()
            self.refresh.send(false)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func showUnblockUserAlert() {
        let alert = UIAlertController(title: "Unblock user?", message: "", preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = .light
        alert.addAction(UIAlertAction(title: "Unblock", style: .destructive) { _ in
            Mixpanel.mainInstance().track(event: "ProfileUnblockUserConfirm")
            self.viewModel.unblockUser()
            self.refresh.send(false)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func showReportUserAlert() {
        let alert = UIAlertController(title: "Report user?", message: "", preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = .light
        alert.addAction(UIAlertAction(title: "Report user", style: .destructive, handler: { (_) in
            if let txtField = alert.textFields?.first, let text = txtField.text {
                Mixpanel.mainInstance().track(event: "ProfileReportUserConfirm")
                self.viewModel.reportUser(text: text)
                self.showConfirmationAction(block: false)
                self.refresh.send(false)
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
}

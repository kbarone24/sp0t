//
//  ProfileActionSheet.swift
//  Spot
//
//  Created by Kenny Barone on 10/20/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

extension ProfileViewController {
    func addActionSheet() {
        let alertAction = "Remove friend"
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: alertAction, style: .destructive, handler: { (_) in
            self.showRemoveFriendAlert()
        }))
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: { (_) in
            print("User click Dismiss button")
        }))
        present(alert, animated: true)
    }
    
    func showRemoveFriendAlert() {
        let alert = UIAlertController(title: "Remove friend?", message: "", preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = .light
        
        let unfollowAction = UIAlertAction(title: "Remove", style: .destructive) { action in
            self.removeFriend()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(unfollowAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }
    
    func removeFriend() {
        Mixpanel.mainInstance().track(event: "RemoveFriend")
        removeFriend(friendID: userProfile!.id!)
        NotificationCenter.default.post(name: NSNotification.Name("FriendRemove"), object: nil, userInfo: ["userID": userProfile!.id!])
        relation = .stranger
        DispatchQueue.main.async { self.collectionView.reloadData() }
    }
}

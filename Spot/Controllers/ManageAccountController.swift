//
//  ManageAccountController.swift
//  Spot
//
//  Created by Kenny Barone on 3/31/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel
import Firebase

class ManageAccountController: UIViewController {
        
    var tableView: UITableView!
    var deleteMask: UIView!
    var activityIndicator: CustomActivityIndicator!
    var indicatorText: UILabel!

    var deleteCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView = UITableView(frame: UIScreen.main.bounds)
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isScrollEnabled = false
        tableView.allowsSelection = false
        tableView.isUserInteractionEnabled = true
        tableView.register(ManageAccountHeader.self, forHeaderFooterViewReuseIdentifier: "ManageHeader")
        tableView.register(DeleteAccountCell.self, forCellReuseIdentifier: "DeleteAccount")
        view.addSubview(tableView)
        
        deleteMask = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        deleteMask.backgroundColor = UIColor(named: "SpotBlack")
        deleteMask.isHidden = true
        view.addSubview(deleteMask)
        
        activityIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 150, width: UIScreen.main.bounds.width, height: 30))
        activityIndicator.isHidden = true
        deleteMask.addSubview(activityIndicator)
        
        indicatorText = UILabel(frame: CGRect(x: 30, y: activityIndicator.frame.maxY + 30, width: UIScreen.main.bounds.width - 60, height: 40))
        indicatorText.text = "Deleting your account. Do not exit the app or your account might not be deleted"
        indicatorText.textColor = .white
        indicatorText.font = UIFont(name: "SFCompactText-Regular", size: 14)
        indicatorText.textAlignment = .center
        indicatorText.lineBreakMode = .byWordWrapping
        indicatorText.numberOfLines = 0
        deleteMask.addSubview(indicatorText)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
}

extension ManageAccountController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "DeleteAccount") as? DeleteAccountCell else { return UITableViewCell() }
        cell.deleteButton.addTarget(self, action: #selector(deleteAccountTap(_:)), for: .touchUpInside)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "ManageHeader") as? ManageAccountHeader else { return UITableViewHeaderFooterView() }
        header.exitButton.addTarget(self, action: #selector(exitTap(_:)), for: .touchUpInside)
        return header
    }
    
    @objc func exitTap(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func deleteAccountTap(_ sender: UIButton) {
        let alert = UIAlertController(title: "Delete Account?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Delete Account", style: .destructive, handler: { action in
            switch action.style{
                
            case .destructive:
                Mixpanel.mainInstance().track(event: "DeleteAccount")
                self.deleteAccount1()
                
            default:
                return
            }}))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
            switch action.style{
            default: return
            }}))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func deleteAccount1() {
        let alert = UIAlertController(title: "Delete Account?", message: "Deleting your account will delete all of your spots, posts, and memories. Only delete your account if you're sure you don't want to come back.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Delete Account", style: .destructive, handler: { action in
            switch action.style{
            
            case .destructive:
                Mixpanel.mainInstance().track(event: "DeleteAccount")
                self.deleteAccount2()
                
            default:
                return
            }}))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
            switch action.style{
            default: return
            }}))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func deleteAccount2() {
        deleteMask.isHidden = false
        activityIndicator.startAnimating()
        deleteFromFriends(friendIDs: UserDataModel.shared.userInfo.friendIDs)
        deleteUser(username: UserDataModel.shared.userInfo.username)
    }
}

class ManageAccountHeader: UITableViewHeaderFooterView {
    
    var exitButton: UIButton!
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView

        exitButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 56, y: 8, width: 44, height: 36))
        exitButton.imageEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        exitButton.setImage(UIImage(named: "CancelButton"), for: .normal)
        addSubview(exitButton)
        
        let manageTitle = UILabel(frame: CGRect(x: 100, y: 15, width: UIScreen.main.bounds.width - 200, height: 20))
        manageTitle.text = "Manage Account"
        manageTitle.textColor = .white
        manageTitle.textAlignment = .center
        manageTitle.font = UIFont(name: "SFCompactText-Regular", size: 16)
        addSubview(manageTitle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

class DeleteAccountCell: UITableViewCell {
    
    var deleteButton: UIButton!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        
        deleteButton = UIButton(frame: CGRect(x: 9, y: 5, width: 200, height: 40))
        deleteButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 9, bottom: 5, right: 10)
        deleteButton.contentHorizontalAlignment = .left
        deleteButton.setTitle("Delete Account", for: .normal)
        deleteButton.setTitleColor(UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1), for: .normal)
        deleteButton.titleLabel?.textAlignment = .left
        deleteButton.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 14)
        contentView.addSubview(deleteButton)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// delete functions
extension ManageAccountController {
    
    /// go through friends list and delete from each friends friendsList, delete from each users posts' friendsList, delete from each users notifications
    func deleteFromFriends(friendIDs: [String]) {
        
        let db = Firestore.firestore()
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

        var fIndex = 0
        
        for id in friendIDs {

            db.collection("users").document(id).updateData(["friendsList" : FieldValue.arrayRemove([uid])])
            
            let postNotiRef = db.collection("users").document(id).collection("notifications")
            let query = postNotiRef.whereField("senderID", isEqualTo: uid)
            
            query.getDocuments { (querysnapshot, err) in
                
                if err != nil || querysnapshot!.documents.count == 0 { fIndex += 1; if fIndex == friendIDs.count { self.finishDelete()}; return }
                
                for doc in querysnapshot!.documents {
                    doc.reference.delete()
                    if doc == querysnapshot?.documents.last { fIndex += 1; if fIndex == friendIDs.count { self.finishDelete()}; return }
                }
            }
        }
    }
   /*
    /// go through all posts and delete user likes, comments, from posts' friendsList for now
    func deleteFromPosts(deletedUserID: String) {
        /// error handling should be fine for deletedIDs
    }
    
    /// delete all posts pertaining to this user, should remove user from spot visitorLists as well
    func deleteUserPosts(deletedUserID: String) {
    }
    
    /// delete all spots pertaining to this user, if only post / non-public spot, delete all posts at the spot
    func deleteUserSpots(deletedUserID: String, spotsList: [String]) {
        for spot in spotsList {
            
        }
    }
    */
    /// delete user from "users" + delete username from "usernames"
    func deleteUser(username: String) {
        
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        let db = Firestore.firestore()

        db.collection("usernames").whereField("username", isEqualTo: username).getDocuments { (snap, err) in
            if let doc = snap?.documents.first {
                doc.reference.delete()
            }
        }

        db.collection("users").document(uid).collection("notifications").getDocuments { (snap, err) in
            
            if err != nil || snap!.documents.count == 0 { db.collection("users").document(uid).delete(); self.finishDelete() }
            /// delete user notis
            for doc in snap!.documents {
                doc.reference.delete()
                if doc == snap!.documents.last { db.collection("users").document(uid).delete(); self.finishDelete(); self.finishDelete() }
            }
        }
    }
    
    func finishDelete() {
        deleteCount += 1
        if deleteCount == 2 {
            logOut()
        }
    }
    
    func logOut() {
        
        UserDataModel.shared.destroy()
        /// this should eventually delete the user but they'll need to re-enter credentials so will have to manually delete from Auth for now
        do {
            try Auth.auth().signOut()
        } catch let signOutError as NSError {
            print ("Error signing out: %@", signOutError)
        }
        if let loginVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "LandingPage") as? LandingPageController {
            //  loginVC.modalPresentationStyle = .fullScreen
            
            let keyWindow = UIApplication.shared.connectedScenes
                .filter({$0.activationState == .foregroundActive})
                .map({$0 as? UIWindowScene})
                .compactMap({$0})
                .first?.windows
                .filter({$0.isKeyWindow}).first
            keyWindow?.rootViewController = loginVC
        }
    }
}
//Auth.auth().signOut()
//Auth.auth().currentUser!.delete(completion: { (err) in


//
//  FriendsListController.swift
//  Spot
//
//  Created by kbarone on 6/5/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel
import FirebaseUI

class FriendsListController: UIViewController {
    
    lazy var friendIDs: [String] = []
    lazy var friendsList: [UserProfile] = []
    
    let db: Firestore! = Firestore.firestore()
    var tableView : UITableView!
    
    unowned var profileVC: ProfileViewController!
    var loadingIndicator: CustomActivityIndicator!
    var listener1: ListenerRegistration!
    
    var userManager: SDWebImageManager!
    lazy var active = true
    lazy var tableOffset: CGFloat = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        userManager = SDWebImageManager()
        setUpTable()
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateFriendsList(_:)), name: NSNotification.Name("FriendsListLoad"), object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeListeners()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        addLoadingIndicator()
    }
    
    func setUpTable() {
        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.isUserInteractionEnabled = true
        tableView.allowsSelection = true 
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        tableView.register(FriendsListCell.self, forCellReuseIdentifier: "FriendsListCell")
        tableView.register(FriendsListHeader.self, forHeaderFooterViewReuseIdentifier: "FriendsListHeader")
        view.addSubview(tableView)
        
        /// friendsList won't be passed for strangers friend's list on profile
        if self.friendsList.isEmpty {
            print("friends list empty")
            DispatchQueue.global(qos: .userInitiated).async { self.getFriendInfo() }
        } else {
            tableView.reloadData()
            tableView.setContentOffset(CGPoint(x: tableView.contentOffset.x, y: tableOffset), animated: false)
            tableOffset = 0
        }
    }
    
    func getFriendInfo() {
        DispatchQueue.main.async {
            if self.loadingIndicator != nil && !self.loadingIndicator.isHidden {
                self.loadingIndicator.startAnimating()
            }
        }

        for friend in self.friendIDs {
            self.listener1 = self.db.collection("users").document(friend).addSnapshotListener { [weak self] (friendSnap, err) in
                guard let self = self else { return }
                
                    do {
                        let info = try friendSnap?.data(as: UserProfile.self)
                        guard var userInfo = info else { return }
                        
                        userInfo.id = friendSnap!.documentID
                        
                        self.friendsList.append(userInfo)
                        self.profileVC.userInfo.friendsList = self.friendsList
                        
                        DispatchQueue.main.async {
                            self.removeLoadingIndicator()
                            self.tableView.reloadData()
                        }
                } catch { return }
            }
        }
    }
    
    func addLoadingIndicator() {
        loadingIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 40, width: UIScreen.main.bounds.width, height: 30))
        if self.friendsList.isEmpty {
            tableView.addSubview(loadingIndicator)
            loadingIndicator.startAnimating()
        }
    }
    
    func removeLoadingIndicator() {
        if loadingIndicator != nil && !loadingIndicator.isHidden {
            loadingIndicator.removeFromSuperview()
            loadingIndicator.stopAnimating()
        }
    }
    
    @objc func updateFriendsList(_ sender: NSNotification) {
        /// update friends list if selected before full friends list loaded on
        if profileVC != nil && profileVC.uid == profileVC.id {
            friendsList = profileVC.mapVC.friendsList
            self.tableView.reloadData()
        }
    }
    
    func removeListeners() {
        if listener1 != nil { listener1.remove() }
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FriendsListLoad"), object: nil)
        
        active = false
        if userManager != nil { userManager.cancelAll() }
    }
}

extension FriendsListController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friendsList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FriendsListCell", for: indexPath) as! FriendsListCell
        cell.setUp(friend: friendsList[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 52
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "FriendsListHeader") as? FriendsListHeader {
            let count = !friendIDs.isEmpty ? friendIDs.count : friendsList.count
            let isCurrentUser = profileVC != nil && profileVC.id == profileVC.uid
            header.setUp(friendCount: count, isCurrentUser: isCurrentUser)
            return header
        } else { return UITableViewHeaderFooterView() }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedUser = self.friendsList[indexPath.row]
        
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "Profile") as? ProfileViewController {
                
                vc.userInfo = selectedUser
                vc.mapVC = self.profileVC.mapVC
                vc.id = selectedUser.id!
                
                profileVC.shadowScroll.isScrollEnabled = false
                profileVC.friendsListScrollDistance = tableView.contentOffset.y
                
                vc.view.frame = profileVC.view.frame
                profileVC.addChild(vc)
                profileVC.view.addSubview(vc.view)
                vc.didMove(toParent: profileVC)
                
                profileVC.mapVC.customTabBar.tabBar.isHidden = true
        }
            
    }
}

class FriendsListCell: UITableViewCell {
    
    var profilePic: UIImageView!
    var name: UILabel!
    var username: UILabel!
    
    func setUp(friend: UserProfile) {
        
        self.backgroundColor = UIColor(named: "SpotBlack")
        self.selectionStyle = .none
        
        resetCell()
        
        profilePic = UIImageView(frame: CGRect(x: 18, y: 8, width: 36, height: 36))
        profilePic.layer.cornerRadius = 18
        profilePic.clipsToBounds = true
        self.addSubview(profilePic)

        let url = friend.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }
        
        name = UILabel(frame: CGRect(x: 60, y: 9, width: UIScreen.main.bounds.width - 70, height: 20))
        name.text = friend.name
        name.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        name.font = UIFont(name: "SFCamera-Semibold", size: 13)
        name.sizeToFit()
        self.addSubview(name)
        
        username = UILabel(frame: CGRect(x: 61, y: name.frame.maxY + 1, width: UIScreen.main.bounds.width - 70, height: 20))
        username.text = friend.username
        username.textColor = UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha: 1)
        username.font = UIFont(name: "SFCamera-Regular", size: 13)
        username.sizeToFit()
        self.addSubview(username)
    }
    
    func resetCell() {
        if profilePic != nil { profilePic.image = UIImage() }
        if name != nil { name.text = "" }
        if username != nil { username.text = "" }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        /// cancel image fetch when cell leaves screen
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
    }
}

class FriendsListHeader: UITableViewHeaderFooterView {
    
    var privacyIcon: UIImageView!
    var numFriends: UILabel!
    var backButton: UIButton!
    var searchContacts: UIButton!
    
    func setUp(friendCount: Int, isCurrentUser: Bool) {
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView
        
        resetCell()
                
        numFriends = UILabel(frame: CGRect(x: 100, y: 11, width: UIScreen.main.bounds.width - 200, height: 16))
        var friendText = "\(friendCount) friends"
        if friendCount == 1 {friendText = String(friendText.dropLast())}
        numFriends.text = friendText
        numFriends.font = UIFont(name: "SFCamera-Semibold", size: 14)
        numFriends.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        numFriends.textAlignment = .center
        self.addSubview(numFriends)
        
        if isCurrentUser {
            searchContacts = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 40, y: 4, width: 33, height: 31.6))
            searchContacts.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            searchContacts.setImage(UIImage(named: "SearchContactsButton"), for: .normal)
            searchContacts.addTarget(self, action: #selector(searchContacts(_:)), for: .touchUpInside)
            self.addSubview(searchContacts)
        }
        
        backButton = UIButton(frame: CGRect(x: 5, y: 4, width: 35, height: 35))
        backButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        backButton.setImage(UIImage(named: "BackButton"), for: .normal)
        backButton.addTarget(self, action: #selector(exit(_:)), for: .touchUpInside)
        self.addSubview(backButton)
        
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func resetCell() {
        if numFriends != nil { numFriends.text = "" }
        if backButton != nil { backButton.setImage(UIImage(), for: .normal) }
        if searchContacts != nil { searchContacts.setImage(UIImage(), for: .normal)}
    }
    
    @objc func exit(_ sender: UIButton) {
        if let friendsListVC = self.viewContainingController() as? FriendsListController {
            friendsListVC.dismiss(animated: true, completion: nil)
        }
    }
    
    @objc func searchContacts(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(withIdentifier: "SearchContacts") as? SearchContactsViewController {
            if let friendsListVC = self.viewContainingController() as? FriendsListController {
                friendsListVC.present(vc, animated: true)
            }
        }
    }
}

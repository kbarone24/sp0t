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
        
    unowned var profileVC: ProfileViewController!
    unowned var postVC: PostViewController!
    
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

    var tableView : UITableView!
    
    lazy var friendIDs: [String] = []
    lazy var friendsList: [UserProfile] = []

    var loadingIndicator: CustomActivityIndicator!
    
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
        Mixpanel.mainInstance().track(event: "FriendsListOpen")
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
            DispatchQueue.global(qos: .userInitiated).async { self.getFriendInfo() }
            
        } else {
            tableView.reloadData()
            tableView.setContentOffset(CGPoint(x: tableView.contentOffset.x, y: tableOffset), animated: false)
            tableOffset = 0
        }
        
        if profileVC == nil { return }
        
        if uid == profileVC.id {
            let offsetY: CGFloat = UserDataModel.shared.largeScreen ? 145 : 125
            let addFriendsButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 158, y: UIScreen.main.bounds.height - offsetY, width: 138, height: 49))
            addFriendsButton.setImage(UIImage(named: "FriendsListAddFriends"), for: .normal)
            addFriendsButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            addFriendsButton.addTarget(self, action: #selector(addFriendsTap(_:)), for: .touchUpInside)
            addFriendsButton.imageView?.contentMode = .scaleAspectFit
            view.addSubview(addFriendsButton)
        }
    }
    
    // get friends from friendIDs for profile (non-active user)
    func getFriendInfo() {
        
        DispatchQueue.main.async {
            if self.loadingIndicator != nil && !self.loadingIndicator.isHidden {
                self.loadingIndicator.startAnimating()
            }
        }

        var friendIndex = 0

        for friend in self.friendIDs {
                        
            if !self.friendsList.contains(where: {$0.id == friend}) {
                var emptyProfile = UserProfile(username: "", name: "", imageURL: "", currentLocation: "", userBio: "")
                emptyProfile.id = friend
                self.friendsList.append(emptyProfile) } /// append empty here so they appear in order

            self.db.collection("users").document(friend).getDocument { [weak self] (friendSnap, err) in
                guard let self = self else { return }
                
                    do {
                        
                        let info = try friendSnap?.data(as: UserProfile.self)
                        guard var userInfo = info else { friendIndex += 1; if friendIndex == self.friendIDs.count { self.reloadTable() }; return }
                        
                        userInfo.id = friendSnap!.documentID
                        
                        if let i = self.friendsList.firstIndex(where: {$0.id == friend}) {
                            self.friendsList[i] = userInfo
                        }
                        self.profileVC.userInfo.friendsList = self.friendsList
                        
                        friendIndex += 1
                        if friendIndex == self.friendIDs.count {
                            self.reloadTable()
                        }
                        
                    } catch { friendIndex += 1; if friendIndex == self.friendIDs.count { self.reloadTable() }; return }
            }
        }
    }
    
    func reloadTable() {
        DispatchQueue.main.async {
            self.removeLoadingIndicator()
            self.tableView.reloadData()
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
        if profileVC != nil && uid == profileVC.id {
            friendsList = UserDataModel.shared.friendsList
            self.tableView.reloadData()
        }
    }
    
    @objc func addFriendsTap(_ sender: UIButton) {
        
        if let vc = storyboard?.instantiateViewController(identifier: "FindFriends") as? FindFriendsController {
            present(vc, animated: true, completion: nil)
        }
    }
    
    func removeListeners() {
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
        guard let friend = friendsList[safe: indexPath.row] else { return cell }
        cell.setUp(friend: friend)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 61
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "FriendsListHeader") as? FriendsListHeader {
            let count = !friendIDs.isEmpty ? friendIDs.count : friendsList.count
            header.setUp(friendCount: count)
            return header
        } else { return UITableViewHeaderFooterView() }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedUser = self.friendsList[indexPath.row]
        
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "Profile") as? ProfileViewController {
            
            vc.userInfo = selectedUser
            vc.id = selectedUser.id!
            
            if profileVC != nil {
                /// add on top of profile
                profileVC.shadowScroll.isScrollEnabled = false
                profileVC.friendsListScrollDistance = tableView.contentOffset.y
                vc.mapVC = profileVC.mapVC
                
                vc.view.frame = profileVC.view.frame
                profileVC.addChild(vc)
                profileVC.view.addSubview(vc.view)
                vc.didMove(toParent: profileVC)

                profileVC.mapVC.customTabBar.tabBar.isHidden = true
            
            } else {
                /// add on top of post
                vc.mapVC = postVC.mapVC
                postVC.openFriendsList = true
                
                vc.view.frame = postVC.view.frame
                postVC.addChild(vc)
                postVC.view.addSubview(vc.view)
                vc.didMove(toParent: postVC)
            }
            
            self.dismiss(animated: false, completion: nil)
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
        
        profilePic = UIImageView(frame: CGRect(x: 14, y: 8.5, width: 44, height: 44))
        profilePic.layer.cornerRadius = 22
        profilePic.clipsToBounds = true
        self.addSubview(profilePic)

        let url = friend.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }
        
        name = UILabel(frame: CGRect(x: profilePic.frame.maxX + 9, y: 14.5, width: UIScreen.main.bounds.width - 186, height: 15))
        name.textAlignment = .left
        name.lineBreakMode = .byTruncatingTail
        name.text = friend.name
        name.textColor = UIColor(red: 0.946, green: 0.946, blue: 0.946, alpha: 1)
        name.font = UIFont(name: "SFCamera-Semibold", size: 13.5)
        self.addSubview(name)
                
        username = UILabel(frame: CGRect(x: profilePic.frame.maxX + 9, y: name.frame.maxY + 1, width: 150, height: 15))
        username.text = friend.username
        username.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        username.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        username.textAlignment = .left
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
    
    func setUp(friendCount: Int) {
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView
        
        resetCell()
                
        numFriends = UILabel(frame: CGRect(x: 100, y: 15, width: UIScreen.main.bounds.width - 200, height: 16))
        var friendText = "\(friendCount) friends"
        if friendCount == 1 {friendText = String(friendText.dropLast())}
        numFriends.text = friendText
        numFriends.font = UIFont(name: "SFCamera-Regular", size: 16)
        numFriends.textColor = .white
        numFriends.textAlignment = .center
        self.addSubview(numFriends)
        
        backButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 40, y: 7, width: 35, height: 35))
        backButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        backButton.setImage(UIImage(named: "CancelButton"), for: .normal)
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

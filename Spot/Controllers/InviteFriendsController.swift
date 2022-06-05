//
//  InviteFriendsToSpotController.swift
//  Spot
//
//  Created by kbarone on 9/17/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//
/*
import Foundation
import UIKit
import Firebase
import Mixpanel
import FirebaseUI

protocol InviteFriendsDelegate {
    func finishPassingSelectedFriends(selected: [UserProfile])
}

class InviteFriendsController: UIViewController {
    
    weak var editVC: EditSpotController!
    weak var spotVC: SpotViewController!
    
    var delegate: InviteFriendsDelegate?
    
    var searchBarContainer: UIView!
    var searchBar: UISearchBar!
    var cancelButton: UIButton!
    var tableView: UITableView!
    
    lazy var queried = false
    lazy var friendsList: [UserProfile] = []
    lazy var queryFriends: [UserProfile] = []
    lazy var selectedFriends: [UserProfile] = []
    
    ///friends list is the initital mapvc friends object, query friends is what rows will show (adjusted for search), selectedfriends tracks selected rows
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Mixpanel.mainInstance().track(event: "InviteFriendsOpen")
        setUpViews()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func setUpViews() {
        
        searchBarContainer = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 122))
        searchBarContainer.backgroundColor = nil
        view.addSubview(searchBarContainer)
        
        let inviteLabel = UILabel(frame: CGRect(x: 21, y: 30, width: 200, height: 20))
        inviteLabel.text = "Invite friends"
        inviteLabel.font = UIFont(name: "SFCompactText-Semibold", size: 17)
        inviteLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        searchBarContainer.addSubview(inviteLabel)

        let doneButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 63, y: 15, width: 56, height: 26))
        doneButton.setTitle("Done", for: .normal)
        doneButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        doneButton.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 15)
        doneButton.addTarget(self, action: #selector(doneTapped(_:)), for: .touchUpInside)
        doneButton.contentHorizontalAlignment = .center
        doneButton.contentVerticalAlignment = .center
        searchBarContainer.addSubview(doneButton)
        
        searchBar = UISearchBar(frame: CGRect(x: 16, y: 66, width: UIScreen.main.bounds.width - 97, height: 36))
        searchBar.searchBarStyle = .default
        searchBar.barTintColor = UIColor(red: 0.133, green: 0.133, blue: 0.137, alpha: 1)
        searchBar.tintColor = .white
        searchBar.searchTextField.backgroundColor = UIColor(red: 0.133, green: 0.133, blue: 0.137, alpha: 1)
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.showsCancelButton = false
        searchBar.searchTextField.font = UIFont(name: "SFCompactText-Regular", size: 13)
        searchBar.clipsToBounds = true
        searchBar.layer.masksToBounds = true
        searchBar.searchTextField.layer.masksToBounds = true
        searchBar.searchTextField.clipsToBounds = true
        searchBar.layer.cornerRadius = 8
        searchBar.searchTextField.layer.cornerRadius = 8
        searchBar.placeholder = "Search friends"
        searchBarContainer.addSubview(searchBar)
        
        cancelButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 68, y: 67, width: 50, height: 30))
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1), for: .normal)
        cancelButton.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 16)
        cancelButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        cancelButton.addTarget(self, action: #selector(searchCancelTap(_:)), for: .touchUpInside)
        cancelButton.isHidden = true
        searchBarContainer.addSubview(cancelButton)
        
        let bottomLine = UIView(frame: CGRect(x: 0, y: searchBarContainer.frame.maxY - 1, width: UIScreen.main.bounds.width, height: 1))
        bottomLine.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        searchBarContainer.addSubview(bottomLine)
        
        tableView = UITableView(frame: CGRect(x: 0, y: searchBarContainer.frame.maxY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - searchBarContainer.frame.maxY))
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.isUserInteractionEnabled = true
        tableView.showsVerticalScrollIndicator = false
        tableView.allowsMultipleSelection = true
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 430, right: 0)
        tableView.register(FriendsListCell.self, forCellReuseIdentifier: "FriendsListCell")
        tableView.register(SelectedFriendsHeader.self, forHeaderFooterViewReuseIdentifier: "SelectedHeader")
        view.addSubview(tableView)
        tableView.reloadData()
    }
    
    @objc func backTapped(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func doneTapped(_ sender: UIButton) {
      
        /*
       if editVC != nil {
            var inviteList = self.selectedFriends.map({($0.id!)})
            if !inviteList.contains(editVC.uid) { inviteList.append(editVC.uid) }
            editVC.spotObject.privacyLevel = "invite"
            editVC.spotObject.inviteList = inviteList
            editVC.tableView.reloadData()
            
        } else if spotVC != nil {
            
            var selectedList = self.selectedFriends.map({$0.id!})
            if !selectedList.contains(spotVC.uid) { selectedList.append(spotVC.uid) }
            var initialList: [String] = []
            
            if spotVC.spotObject.privacyLevel == "invite" {
                initialList = spotVC.spotObject.inviteList ?? []
                spotVC.spotObject.inviteList = selectedList
                
            } else {
                initialList = spotVC.spotObject.visitorList
                spotVC.spotObject.visitorList = selectedList
            }
            
            spotVC.memberList.removeAll()
            spotVC.getVisitorInfo(refresh: true)
            spotVC.updateUserList(initialList: initialList)
            ///update db
        } else {
        
            delegate?.finishPassingSelectedFriends(selected: selectedFriends)
        }
        */
        
        delegate?.finishPassingSelectedFriends(selected: selectedFriends)
        Mixpanel.mainInstance().track(event: "InviteFriendsSave", properties: ["friendCount": self.selectedFriends.count])
        self.dismiss(animated: true, completion: nil)
    
    }
}

extension InviteFriendsController: UISearchBarDelegate {
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        
        queried = true
        cancelButton.alpha = 0.0
        cancelButton.isHidden = false
        
        UIView.animate(withDuration: 0.1) {
            self.cancelButton.alpha = 1.0
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        
        self.searchBar.text = ""
        self.queryFriends = self.friendsList
        queried = false
        
        UIView.animate(withDuration: 0.1, animations: {
            self.cancelButton.alpha = 0.0

        }) { [weak self] _ in
            guard let self = self else { return }
            self.cancelButton.isHidden = true
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.queryFriends.removeAll()
            let usernameList = self.friendsList.map({$0.username})
            let nameList = self.friendsList.map({$0.name})
            
            let filteredUsernames = searchText.isEmpty ? usernameList : usernameList.filter({(dataString: String) -> Bool in
                // If dataItem matches the searchText, return true to include it
                return dataString.range(of: searchText, options: .caseInsensitive) != nil
            })
            
            let filteredNames = searchText.isEmpty ? nameList : nameList.filter({(dataString: String) -> Bool in
                return dataString.range(of: searchText, options: .caseInsensitive) != nil
            })
            
            for username in filteredUsernames {
                if let friend = self.friendsList.first(where: {$0.username == username}) { self.queryFriends.append(friend) }
            }
            
            for name in filteredNames {
                if let friend = self.friendsList.first(where: {$0.name == name}) {

                    if !self.queryFriends.contains(where: {$0.id == friend.id}) { self.queryFriends.append(friend) }
                }
            }
            DispatchQueue.main.async { self.tableView.reloadData() }
        }
    }
    
    @objc func searchCancelTap(_ sender: UIButton) {
        searchBar.resignFirstResponder()
    }
}

extension InviteFriendsController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return queryFriends.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "FriendsListCell", for: indexPath) as! FriendsListCell
        if indexPath.row >= queryFriends.count { return UITableViewCell() }
        let friend = queryFriends[indexPath.row]
        cell.setUp(friend: friend)
        
        if self.selectedFriends.contains(where: {$0.id == friend.id}) {
            cell.setSelected(true, animated: false)
            cell.backgroundColor = UIColor(red: 0.029, green: 0.287, blue: 0.256, alpha: 1)
        } else {
            cell.setSelected(false, animated: false)
            cell.backgroundColor = UIColor(named: "SpotBlack")
        }

        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return selectedFriends.count == 0 ? 0 : 60
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SelectedHeader") as? SelectedFriendsHeader else { return UITableViewHeaderFooterView() }
        header.setUp(selectedFriends: selectedFriends)
        return header
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let friend = queried ? queryFriends[indexPath.row] : friendsList[indexPath.row]
        selectedFriends.insert(friend, at: 0)
        queryFriends.removeAll(where: {$0.id == friend.id})
        friendsList.removeAll(where: {$0.id == friend.id})
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
    
    func showVisitorMessage() {
        let errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 120, width: UIScreen.main.bounds.width, height: 32))
        let errorLabel = UILabel(frame: CGRect(x: 23, y: 6, width: UIScreen.main.bounds.width - 46, height: 18))

        errorBox.backgroundColor = UIColor.lightGray
        errorLabel.textColor = UIColor.white
        errorLabel.textAlignment = .center
        errorLabel.text = "This person has already posted here"
        errorLabel.font = UIFont(name: "SFCompactText-Regular", size: 13)
        
        view.addSubview(errorBox)
        errorBox.addSubview(errorLabel)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { 
            errorLabel.removeFromSuperview()
            errorBox.removeFromSuperview()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 61
    }
    
}

class SelectedFriendsHeader: UITableViewHeaderFooterView {
    
    var bottomLine: UIView!
    var selectedFriends: [UserProfile] = []
    
    var addFriendsCollection: UploadPillCollectionView  = UploadPillCollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    
    func setUp(selectedFriends: [UserProfile]) {
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView
        
        self.selectedFriends = selectedFriends
        
        if bottomLine != nil { bottomLine.backgroundColor = nil }
        bottomLine = UIView(frame: CGRect(x: 0, y: 59, width: UIScreen.main.bounds.width, height: 1))
        bottomLine.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        addSubview(bottomLine)
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.sectionInset = UIEdgeInsets(top: 0, left: 13, bottom: 0, right: 13)
        
        if addFriendsCollection.numberOfItems(inSection: 0) > 0 {
            addFriendsCollection.reloadData()
            return
        }
        
        addFriendsCollection.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 43)
        addFriendsCollection.backgroundColor = nil
        addFriendsCollection.delegate = self
        addFriendsCollection.dataSource = self
        addFriendsCollection.register(UploadFriendCell.self, forCellWithReuseIdentifier: "FriendCell")
        addFriendsCollection.showsHorizontalScrollIndicator = false
        addFriendsCollection.setCollectionViewLayout(layout, animated: false)
        addSubview(addFriendsCollection)
    }

}

extension SelectedFriendsHeader: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return selectedFriends.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FriendCell", for: indexPath) as? UploadFriendCell else { return UICollectionViewCell() }
        cell.setUp(user: selectedFriends[indexPath.row])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: getCellWidth(user: selectedFriends[indexPath.row]), height: 42)
    }
    
    func getCellWidth(user: UserProfile) -> CGFloat {
        
        let tempName = UILabel(frame: CGRect(x: 0, y: 0, width: 250, height: 18))
        tempName.font = UIFont(name: "SFCompactText-Regular", size: 12.5)
    
        tempName.text = user.username
        tempName.sizeToFit()
        
        let nameWidth = tempName.frame.width
        
        return nameWidth + 49
    }
}

class UploadFriendCell: UICollectionViewCell {
    
    var userView: UIView!
    var profilePic: UIImageView!
    var username: UILabel!
    var exitButton: UIButton!
    
    var user: UserProfile!
        
    func setUp(user: UserProfile) {
        
        resetView()
        backgroundColor = nil
        self.user = user
        
        userView = UIView(frame: CGRect(x: 0, y: 6, width: self.bounds.width - 9, height: 36))
        userView.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        userView.layer.borderWidth = 1
        userView.layer.cornerRadius = 10
        userView.layer.cornerCurve = .continuous
        userView.layer.borderColor = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1).cgColor
        addSubview(userView)
        
        profilePic = UIImageView(frame: CGRect(x: 6, y: 5, width: 24, height: 24))
        profilePic.layer.cornerRadius = 12
        profilePic.layer.cornerCurve = .continuous
        profilePic.layer.masksToBounds = true
        profilePic.contentMode = .scaleAspectFill
        userView.addSubview(profilePic)

        let url = user.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 50, height: 50), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }

        username = UILabel(frame: CGRect(x: profilePic.frame.maxX + 4, y: 10, width: self.bounds.width - profilePic.frame.maxX - 10, height: 16))
        username.text = user.username
        username.font = UIFont(name: "SFCompactText-Regular", size: 12.5)
        username.textColor = UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1)
        username.sizeToFit()
        userView.addSubview(username)
    
        exitButton = UIButton(frame: CGRect(x: self.bounds.width - 23, y: -5, width: 27, height: 27))
        exitButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        exitButton.setImage(UIImage(named: "CheckInX"), for: .normal)
        exitButton.addTarget(self, action: #selector(exitTap(_:)), for: .touchUpInside)
        addSubview(exitButton)
    }
    
    @objc func exitTap(_ sender: UIButton) {
        guard let inviteVC = viewContainingController() as? InviteFriendsController else { return }
        inviteVC.selectedFriends.removeAll(where: {$0.id == user.id})
        inviteVC.friendsList.insert(user, at: 0)
        DispatchQueue.main.async { inviteVC.tableView.reloadData() }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
    }
    
    func resetView() {
        if profilePic != nil { profilePic.image = UIImage() }
        if username != nil { username.text = "" }
        if userView != nil { for sub in userView.subviews { sub.removeFromSuperview() }; userView.backgroundColor = .clear; userView.layer.borderColor = UIColor.clear.cgColor }
        if exitButton != nil { exitButton.setImage(UIImage(), for: .normal)}
    }
}
*/

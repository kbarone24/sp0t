//
//  InviteFriendsToSpotController.swift
//  Spot
//
//  Created by kbarone on 9/17/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel

class InviteFriendsController: UIViewController {
    
    weak var uploadVC: UploadPostController!
    weak var editVC: EditSpotController!
    
    var searchBarContainer: UIView!
    var searchBar: UISearchBar!
    var cancelButton: UIButton!
    var tableView: UITableView!
    
    lazy var queried = false
    lazy var friendsList: [UserProfile] = []
    lazy var queryFriends: [UserProfile] = []
    lazy var selectedFriends: [UserProfile] = []
    lazy var visitorList: [String] = []
    
    ///friends list is the initital mapvc friends object, query friends is what rows will show (adjusted for search), selectedfriends tracks selected rows
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Mixpanel.mainInstance().track(event: "InviteFriendsOpen")
        addTopBar()
        setUpViews()
    }
    
    func addTopBar() {
        let topBar = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 45))
        topBar.backgroundColor = nil
        view.addSubview(topBar)
        
        let backButton = UIButton(frame: CGRect(x: 16, y: 18, width: 24, height: 18.66))
        backButton.setImage(UIImage(named: "BackArrow"), for: .normal)
        backButton.addTarget(self, action: #selector(backTapped(_:)), for: .touchUpInside)
        backButton.tintColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        topBar.addSubview(backButton)
        
        let titleView = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 75, y: 14, width: 150, height: 23))
        titleView.text = "Invite friends"
        titleView.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        titleView.font = UIFont(name: "SFCamera-Regular", size: 15)
        titleView.textAlignment = .center
        topBar.addSubview(titleView)
        
        let doneButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 53, y: 19, width: 40, height: 16))
        doneButton.setTitle("Done", for: .normal)
        doneButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        doneButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 15)
        doneButton.addTarget(self, action: #selector(doneTapped(_:)), for: .touchUpInside)
        topBar.addSubview(doneButton)
    }
    
    func setUpViews() {
        searchBarContainer = UIView(frame: CGRect(x: 0, y: 60, width: UIScreen.main.bounds.width, height: 40))
        searchBarContainer.backgroundColor = nil
        view.addSubview(searchBarContainer)
        
        searchBar = UISearchBar(frame: CGRect(x: 14, y: 3, width: UIScreen.main.bounds.width - 28, height: 36))
        searchBar.searchBarStyle = .default
        searchBar.barTintColor = UIColor(red: 0.133, green: 0.133, blue: 0.137, alpha: 1)
        searchBar.searchTextField.backgroundColor = UIColor(red: 0.133, green: 0.133, blue: 0.137, alpha: 1)
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.showsCancelButton = false
        searchBar.searchTextField.font = UIFont(name: "SFCamera-Regular", size: 13)
        searchBar.clipsToBounds = true
        searchBar.layer.masksToBounds = true
        searchBar.searchTextField.layer.masksToBounds = true
        searchBar.searchTextField.clipsToBounds = true
        searchBar.layer.cornerRadius = 8
        searchBar.searchTextField.layer.cornerRadius = 8
        searchBar.placeholder = "Search friends"
        searchBarContainer.addSubview(searchBar)
        
        cancelButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 65, y: 5.5, width: 50, height: 30))
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1), for: .normal)
        cancelButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 16)
        cancelButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        cancelButton.addTarget(self, action: #selector(searchCancelTap(_:)), for: .touchUpInside)
        cancelButton.isHidden = true
        searchBarContainer.addSubview(cancelButton)
        
        tableView = UITableView(frame: CGRect(x: 0, y: 110, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = UIEdgeInsets(top: 0, left: -20, bottom: 0, right: 0)
        tableView.separatorColor = UIColor(named: "SpotBlack")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.isUserInteractionEnabled = true
        tableView.showsVerticalScrollIndicator = false
        tableView.allowsMultipleSelection = true
        tableView.contentInset = UIEdgeInsets(top: 15, left: 0, bottom: 150, right: 0)
        tableView.register(FriendsListCell.self, forCellReuseIdentifier: "FriendsListCell")
        view.addSubview(tableView)
        tableView.reloadData()
    }
    
    @objc func backTapped(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func doneTapped(_ sender: UIButton) {
        
        if uploadVC != nil {
            /// for uploadVC we want to just show 1 friend, it's implied the user has access
            uploadVC.inviteList = self.selectedFriends.map({($0.id ?? "")})
            uploadVC.postPrivacy = "invite"
            uploadVC.tableView.reloadData()
            
        } else if editVC != nil {
            var inviteList = self.selectedFriends.map({($0.id ?? "")})
            if !inviteList.contains(editVC.uid) { inviteList.append(editVC.uid) }
            editVC.spotObject.privacyLevel = "invite"
            editVC.spotObject.inviteList = inviteList
            editVC.tableView.reloadData()
        }
        
        Mixpanel.mainInstance().track(event: "InviteFriendsSave", properties: ["friendCount": self.selectedFriends.count])
        self.dismiss(animated: true, completion: nil)
    }
}

extension InviteFriendsController: UISearchBarDelegate {
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        self.queried = true

        self.searchBar.frame = CGRect(x: self.searchBar.frame.minX, y: self.searchBar.frame.minY, width: UIScreen.main.bounds.width - 85, height: self.searchBar.frame.height)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.cancelButton.isHidden = false
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        self.searchBar.text = ""
        self.queryFriends = self.friendsList
        queried = false
        
        UIView.animate(withDuration: 0.1) {
            self.cancelButton.isHidden = true
            self.searchBar.frame = CGRect(x: self.searchBar.frame.minX, y: self.searchBar.frame.minY, width: UIScreen.main.bounds.width - 28, height: self.searchBar.frame.height)
        }
        
        DispatchQueue.main.async { self.tableView.reloadData() }
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
            cell.backgroundColor = UIColor(red: 0.045, green: 0.454, blue: 0.405, alpha: 0.45)
        } else {
            cell.setSelected(false, animated: false)
            cell.backgroundColor = UIColor(named: "SpotBlack")
        }

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let friend = queryFriends[indexPath.row]
        if let cell = tableView.cellForRow(at: indexPath) as? FriendsListCell {
        
            if let index = selectedFriends.firstIndex(where: {$0.id == friend.id}) {
                ///cant uninvite a user that has visited
                if self.editVC != nil && self.editVC.spotObject.visitorList.contains(where: {$0 == friend.id}) { self.showVisitorMessage(); return }
                
                self.selectedFriends.remove(at: index)
                cell.setSelected(false, animated: false)
                cell.backgroundColor = UIColor(named: "SpotBlack")
                tableView.reloadData()
                
            } else {
                self.selectedFriends.append(friend)
                cell.setSelected(true, animated: false)
                cell.backgroundColor = UIColor(red: 0.045, green: 0.454, blue: 0.405, alpha: 0.45)
                tableView.reloadData()
            }
        }
    }
    
    func showVisitorMessage() {
        let errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 120, width: UIScreen.main.bounds.width, height: 32))
        let errorLabel = UILabel(frame: CGRect(x: 23, y: 6, width: UIScreen.main.bounds.width - 46, height: 18))

        errorBox.backgroundColor = UIColor.lightGray
        errorLabel.textColor = UIColor.white
        errorLabel.textAlignment = .center
        errorLabel.text = "This person has already posted here"
        errorLabel.font = UIFont(name: "SFCamera-Regular", size: 12)
        
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

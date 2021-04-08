//
//  FindFriendsController.swift
//  Spot
//
//  Created by Kenny Barone on 3/28/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import FirebaseUI
import Mixpanel

enum FriendStatus {
    case none
    case pending
    case friends
}

class FindFriendsController: UIViewController {
    
    unowned var mapVC: MapViewController!
    let db: Firestore = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    
    var titleView: UIView!
    var mainView: UIView!
    
    var searchBarContainer: UIView!
    var searchBar: UISearchBar!
    var cancelButton: UIButton!
    var resultsTable: UITableView!
    var searchIndicator: CustomActivityIndicator!
    
    lazy var suggestedUsers: [(UserProfile, FriendStatus)] = []
    lazy var queryUsers: [(UserProfile, FriendStatus)] = []
    lazy var searchRefreshCount = 0
    lazy var searchTextGlobal = ""

    var sendInvitesView: SendInvitesView!
    var searchContactsView: SearchContactsView!
    var suggestedIndicator: CustomActivityIndicator!
    var suggestedTable: UITableView!

    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "SpotBlack")

        setUpTitleView()
        loadSearchBar()
        loadOutletViews()
        loadSuggestedTable()
        
        DispatchQueue.global(qos: .userInitiated).async { self.getSuggestedFriends() }
        
        NotificationCenter.default.addObserver(self, selector: #selector(notifyRequestSent(_:)), name: NSNotification.Name("FriendRequest"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyInviteSent(_:)), name: NSNotification.Name("SentInvite"), object: nil)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        
        if suggestedIndicator != nil && suggestedUsers.count == 0 && !suggestedTable.isHidden {
            /// resume frozen indicator animation
            DispatchQueue.main.async { self.suggestedIndicator.startAnimating() }
            
        } else if suggestedTable != nil && !suggestedTable.isHidden {
            /// reload to allow user interaction
            DispatchQueue.main.async { self.suggestedTable.reloadData() }
        }
        
        Mixpanel.mainInstance().track(event: "FindFriendsOpen")
    }
    
    func setUpTitleView() {

        // nav bar-like titleview
        titleView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        titleView.backgroundColor = nil
        view.addSubview(titleView)
        
        let titleLabel = UILabel(frame: CGRect(x: 100, y: 15, width: UIScreen.main.bounds.width - 200, height: 16))
        titleLabel.text = "Add friends"
        titleLabel.font = UIFont(name: "SFCamera-Regular", size: 16)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleView.addSubview(titleLabel)
        
        let backButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 40, y: 7, width: 35, height: 35))
        backButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        backButton.setImage(UIImage(named: "CancelButton"), for: .normal)
        backButton.addTarget(self, action: #selector(exit(_:)), for: .touchUpInside)
        titleView.addSubview(backButton)
    }
    
    func loadSearchBar() {
        
        searchBarContainer = UIView(frame: CGRect(x: 0, y: titleView.frame.maxY + 5, width: UIScreen.main.bounds.width, height: 60))
        searchBarContainer.backgroundColor = nil
        view.addSubview(searchBarContainer)
        
        searchBar = UISearchBar(frame: CGRect(x: 14, y: 11, width: UIScreen.main.bounds.width - 28, height: 36))
        searchBar.searchBarStyle = .default
        searchBar.barTintColor = UIColor(red: 0.133, green: 0.133, blue: 0.137, alpha: 1)
        searchBar.searchTextField.backgroundColor = UIColor(red: 0.133, green: 0.133, blue: 0.137, alpha: 1)
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.placeholder = "Search for users"
        searchBar.searchTextField.font = UIFont(name: "SFCamera-Regular", size: 13)
        searchBar.clipsToBounds = true
        searchBar.layer.masksToBounds = true
        searchBar.searchTextField.layer.masksToBounds = true
        searchBar.searchTextField.clipsToBounds = true
        searchBar.layer.cornerRadius = 8
        searchBar.searchTextField.layer.cornerRadius = 8
        
        searchBarContainer.addSubview(searchBar)
        
        cancelButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 60, y: 13, width: 50, height: 30))
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha: 1.00), for: .normal)
        cancelButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 14)
        cancelButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        cancelButton.addTarget(self, action: #selector(searchCancelTap(_:)), for: .touchUpInside)
        cancelButton.isHidden = true
        searchBarContainer.addSubview(cancelButton)
        
        resultsTable = UITableView(frame: CGRect(x: 0, y: searchBarContainer.frame.maxY + 10, width: UIScreen.main.bounds.width, height: 300))
        resultsTable.dataSource = self
        resultsTable.delegate = self
        resultsTable.isScrollEnabled = false
        resultsTable.backgroundColor = UIColor(named: "SpotBlack")
        resultsTable.separatorStyle = .none
        resultsTable.allowsSelection = false
        resultsTable.isHidden = true
        resultsTable.register(SuggestedFriendSearchCell.self, forCellReuseIdentifier: "SuggestedSearch")
        resultsTable.tag = 1

        searchIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 20, width: UIScreen.main.bounds.width, height: 30))
        searchIndicator.isHidden = true
        resultsTable.addSubview(searchIndicator)
        
        view.addSubview(resultsTable)
    }
    
    func loadOutletViews() {
        
        /// set up outlet views to search contacts + send invites
        mainView = UIView(frame: CGRect(x: 0, y: searchBarContainer.frame.maxY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - searchBarContainer.frame.maxY))
        mainView.backgroundColor = nil
        view.addSubview(mainView)
        
        sendInvitesView = SendInvitesView(frame: CGRect(x: 0, y: 5, width: UIScreen.main.bounds.width, height: 76))
        sendInvitesView.setUp(invites: 5 - mapVC.userInfo.sentInvites.count)
        sendInvitesView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(presentSendInvites(_:))))
        mainView.addSubview(sendInvitesView)
        
        searchContactsView = SearchContactsView(frame: CGRect(x: 0, y: sendInvitesView.frame.maxY, width: UIScreen.main.bounds.width, height: 76))
        searchContactsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(presentSearchContacts(_:))))
        mainView.addSubview(searchContactsView)
    }
    
    func loadSuggestedTable() {
    
        suggestedTable = UITableView(frame: CGRect(x: 0, y: searchContactsView.frame.maxY + 15, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - searchContactsView.frame.maxY - 15))
        suggestedTable.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 200, right: 0)
        suggestedTable.backgroundColor = UIColor(named: "SpotBlack")
        suggestedTable.tag = 0
        suggestedTable.separatorStyle = .none
        suggestedTable.allowsSelection = false
        suggestedTable.delegate = self
        suggestedTable.dataSource = self
        suggestedTable.isScrollEnabled = UIScreen.main.bounds.height < 650
        suggestedTable.register(SuggestedFriendCell.self, forCellReuseIdentifier: "SuggestedFriend")
        suggestedTable.register(SuggestedFriendsHeader.self, forHeaderFooterViewReuseIdentifier: "SuggestedHeader")
        mainView.addSubview(suggestedTable)
        
        suggestedIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 20, width: UIScreen.main.bounds.width, height: 30))
        suggestedIndicator.isHidden = true
        suggestedTable.addSubview(suggestedIndicator)
    }
    
    @objc func notifyRequestSent(_ sender: NSNotification) {
        
        /// notify request sent from search contacts and update suggested users if necessary
        if let receiverID = sender.userInfo?.first?.value as? String {
            if let i = suggestedUsers.firstIndex(where: {$0.0.id == receiverID}) {
                suggestedUsers[i].1 = .pending
                suggestedTable.reloadData()
            }
            mapVC.userInfo.pendingFriendRequests.append(receiverID)
        }
    }
    
    @objc func notifyInviteSent(_ sender: NSNotification) {
        sendInvitesView.setUp(invites: 5 - mapVC.userInfo.sentInvites.count)
    }
    
    @objc func presentSendInvites(_ sender: UITapGestureRecognizer) {
        
        let adminID = mapVC.uid == "kwpjnnDCSKcTZ0YKB3tevLI1Qdi2" || mapVC.uid == "Za1OQPFoCWWbAdxB5yu98iE8WZT2"
        if mapVC.userInfo.sentInvites.count > 4 && !adminID { return }
        
        if let vc = storyboard?.instantiateViewController(identifier: "SendInvites") as? SendInvitesController {
            vc.mapVC = mapVC
            present(vc, animated: true, completion: nil)
        }
    }
    
    @objc func presentSearchContacts(_ sender: UITapGestureRecognizer) {
        if let vc = storyboard?.instantiateViewController(identifier: "SearchContacts") as? SearchContactsViewController {
            vc.mapVC = mapVC
            present(vc, animated: true, completion: nil)
        }
    }

    
    @objc func exit(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func searchCancelTap(_ sender: UIButton) {
        searchBar.resignFirstResponder()
    }
    
    func getSuggestedFriends() {
        
        /// get mutual friends by cycling through friends of everyone on friendsList
        
        var mutuals: [(id: String, count: Int)] = []
        
        var x = 0 /// outer friends list counter
                
        for friend in mapVC.friendsList {
            
            var y = 0 /// inner friendslist counter
            if mapVC.adminIDs.contains(friend.id!) { x += 1; if x == mapVC.friendsList.count { runMutualSort(mutuals: mutuals) }; continue }
            
            for id in friend.friendIDs {
                
                /// only add non-friends + people we haven't sent a request to yet
                if !mapVC.friendIDs.contains(id) && !mapVC.userInfo.pendingFriendRequests.contains(id) && id != uid {
                    
                    
                    if let i = mutuals.firstIndex(where: {$0.id == id}) {
                        /// increment mutuals index if already added to mutuals
                        mutuals[i].count += 1
                        y += 1; if y == friend.friendIDs.count { x += 1; if x == mapVC.friendsList.count { runMutualSort(mutuals: mutuals) }}
                    } else {
                        /// add new mutual to mutuals
                        mutuals.append((id: id, count: 1))
                        y += 1; if y == friend.friendIDs.count { x += 1; if x == mapVC.friendsList.count { runMutualSort(mutuals: mutuals) }}
                    }
                } else { y += 1; if y == friend.friendIDs.count { x += 1; if x == mapVC.friendsList.count { runMutualSort(mutuals: mutuals) }} }
            }
        }
    }
    
    func runMutualSort(mutuals: [(id: String, count: Int)]) {
        
        var mutuals = mutuals
        mutuals.sort(by: {$0.count > $1.count})
        
        if mutuals.count < 10 {
            /// go through users friend requests to suggest users
            getPendingFriends(mutuals: mutuals)
        } else {
            /// get spotsCount + cities
            getUserSpots(mutuals: mutuals)
        }
    }
    
    func getPendingFriends(mutuals: [(id: String, count: Int)]) {
        
        let pendingRequests = mapVC.userInfo.pendingFriendRequests
        if pendingRequests.count == 0 { getUserSpots(mutuals: mutuals) }
        
        var mutuals = mutuals
        var secondaryMutuals: [(id: String, secondaryCount: Int)] = [] /// get "mutuals" from pending friend requests to fill up the rest of suggestions
        
        var pendingIndex = 0
        for id in pendingRequests {
            self.db.collection("users").document(id).getDocument { [weak self] (snap, err) in
                guard let self = self else { return }
                
                if let friendsList = snap?.get("friendsList") as? [String] {
                    
                    for id in friendsList {
                        if !self.mapVC.friendIDs.contains(id) && !self.mapVC.userInfo.pendingFriendRequests.contains(id) {
                            
                            if let i = secondaryMutuals.firstIndex(where: {$0.id == id}) {
                                secondaryMutuals[i].secondaryCount += 1
                            } else {
                                secondaryMutuals.append((id: id, secondaryCount: 1))
                            }
                        }
                        
                        if id == friendsList.last {
                            pendingIndex += 1
                            if pendingIndex == pendingRequests.count {
                                /// add secondary mutuals at the end of the array
                                secondaryMutuals.sort(by: {$0.secondaryCount > $1.secondaryCount})
                                for user in secondaryMutuals { mutuals.append((id: user.id, count: 0)) }
                                self.getUserSpots(mutuals: mutuals)
                            }
                        }
                    }
                } else {
                    pendingIndex += 1
                    if pendingIndex == pendingRequests.count {
                        /// add secondary mutuals at the end of the array
                        secondaryMutuals.sort(by: {$0.secondaryCount > $1.secondaryCount})
                        for user in secondaryMutuals { mutuals.append((id: user.id, count: 0)) }
                        self.getUserSpots(mutuals: mutuals)
                    }
                }
            }
        }
    }
    
    func getUserSpots(mutuals: [(id: String, count: Int)]) {
        
        var index = 0
        let topMutuals = mutuals.prefix(20)
        if topMutuals.count == 0 { removeTable() }
        
        /// get user data for  top 10 mutuals
        for user in topMutuals {
            
            self.db.collection("users").document(user.id).getDocument { [weak self] (snap, err) in
                guard let self = self else { return }
                
                do {
                    let userIn = try snap?.data(as: UserProfile.self)
                    guard var userInfo = userIn else { index += 1; if index == topMutuals.count { self.finishSuggestedLoad()}; return }
                  
                    userInfo.id = user.id
                    userInfo.mutualFriends = user.count
                    
                    /// get spotsList to sort top mutuals by
                    self.db.collection("users").document(user.id).collection("spotsList").getDocuments { [weak self] (listSnap, err) in
                        guard let self = self else { return }
                        
                        if err != nil || listSnap?.documents.count == 0 {
                            self.suggestedUsers.append((userInfo, .none))
                            index += 1; if index == topMutuals.count { self.finishSuggestedLoad()} ; return
                        }
                        
                        for doc in listSnap!.documents {
                            userInfo.spotsList.append(doc.documentID)
                            if doc == listSnap?.documents.last {
                                self.suggestedUsers.append((userInfo, .none))
                                index += 1; if index == topMutuals.count { self.finishSuggestedLoad()}; return
                            }
                        }
                    }
                    
                } catch {
                    index += 1
                    if index == topMutuals.count { self.finishSuggestedLoad() }
                }
            }
        }
    }
    
    func finishSuggestedLoad() {
        /// sort by combined spots x mutual friends
        suggestedUsers.sort(by: {$0.0.spotsList.count + $0.0.mutualFriends > $1.0.spotsList.count + $1.0.mutualFriends})
        DispatchQueue.main.async {
            self.suggestedIndicator.stopAnimating()
            self.suggestedTable.reloadData()
        }
    }
    
    func removeTable() {
        suggestedTable.isHidden = true
    }
}

extension FindFriendsController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let dataSource = tableView.tag == 0 ? suggestedUsers : queryUsers
        let maxRows = mapVC.largeScreen ? 5 : 4
        return dataSource.count > maxRows ? maxRows : dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestedFriend") as? SuggestedFriendCell {
            let user = suggestedUsers[indexPath.row]
            cell.setUp(user: user.0, status: user.1)
            return cell
            
        } else if let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestedSearch") as? SuggestedFriendSearchCell {
            let user = queryUsers[indexPath.row]
            cell.setUp(user: user.0, status: user.1)
            return cell
            
        } else { return UITableViewCell() }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SuggestedHeader") as? SuggestedFriendsHeader {
            return header
        } else { return UITableViewHeaderFooterView() }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.tag == 0 ? 76 : 60
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return tableView.tag == 0 ? 28 : 0
    }
    
}

extension FindFriendsController: UISearchBarDelegate {
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        
        UIView.animate(withDuration: 0.1) {
            self.searchBar.frame = CGRect(x: self.searchBar.frame.minX, y: self.searchBar.frame.minY, width: UIScreen.main.bounds.width - 93, height: self.searchBar.frame.height)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.cancelButton.isHidden = false
            self.resultsTable.isHidden = false
            self.searchIndicator.isHidden = true
            self.mainView.isHidden = true
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        
        self.searchBar.text = ""
        emptyQueries()
        
        UIView.animate(withDuration: 0.1) {
            self.cancelButton.isHidden = true
            self.searchBar.frame = CGRect(x: self.searchBar.frame.minX, y: self.searchBar.frame.minY, width: UIScreen.main.bounds.width - 28, height: self.searchBar.frame.height)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.searchIndicator.stopAnimating()
            self.resultsTable.reloadData()
            self.resultsTable.isHidden = true
            self.mainView.isHidden = false
        }
    }

    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        searchTextGlobal = searchText
        emptyQueries()
        resultsTable.reloadData()
        
        if !searchIndicator.isAnimating() { searchIndicator.startAnimating() }
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.runQuery), object: nil)
        self.perform(#selector(self.runQuery), with: nil, afterDelay: 0.65)
    }
    
    func emptyQueries() {
        searchRefreshCount = 0
        queryUsers.removeAll()
    }
    
    @objc func runQuery() {
        queryUsers.removeAll()
        DispatchQueue.global(qos: .userInitiated).async {
            self.runNameQuery(searchText: self.searchTextGlobal)
            self.runUsernameQuery(searchText: self.searchTextGlobal)
        }
    }
    
    func runNameQuery(searchText: String) {
        /// query names for matches
        let userRef = db.collection("users")
        let maxVal = "\(searchText.lowercased())uf8ff"
        let nameQuery = userRef.whereField("lowercaseName", isGreaterThanOrEqualTo: searchText.lowercased()).whereField("lowercaseName", isLessThanOrEqualTo: maxVal as Any)
        
        nameQuery.getDocuments{ [weak self] (snap, err) in
            
            guard let self = self else { return }
            guard let docs = snap?.documents else { return }
            if !self.queryValid(searchText: searchText) { return }
            
            if docs.count == 0 { self.reloadResultsTable() }
            
            for doc in docs {
                do {
                    
                    let userInfo = try doc.data(as: UserProfile.self)
                    guard var info = userInfo else { if doc == docs.last { self.reloadResultsTable() }; return }
                    info.id = doc.documentID
                    
                    /// add any user who matches here except for active user
                    if !self.queryUsers.contains(where: {$0.0.id == info.id}) && info.id != self.uid {
                        if !self.queryValid(searchText: searchText) { return }
                        let status: FriendStatus = self.mapVC.friendIDs.contains(info.id!) ? .friends : self.mapVC.userInfo.pendingFriendRequests.contains(info.id!) ? .pending : .none
                        self.queryUsers.append((info, status))
                    }

                    if doc == docs.last { self.reloadResultsTable() }
                    
                } catch { if doc == docs.last { self.reloadResultsTable() } }
            }
        }
    }
    
    func runUsernameQuery(searchText: String) {
        ///query usernames for matches
        let userRef = db.collection("users")
        let maxVal = "\(searchText.lowercased())uf8ff"
        let usernameQuery = userRef.whereField("username", isGreaterThanOrEqualTo: searchText.lowercased()).whereField("username", isLessThanOrEqualTo: maxVal as Any)
        
        usernameQuery.getDocuments { [weak self] (snap, err) in
            
            guard let self = self else { return }
            guard let docs = snap?.documents else { self.reloadResultsTable(); return }
            if !self.queryValid(searchText: searchText) { return }
            
            if docs.count == 0 { self.reloadResultsTable() }

            for doc in docs {
                do {
                    
                    let userInfo = try doc.data(as: UserProfile.self)
                    guard var info = userInfo else { if doc == docs.last { self.reloadResultsTable() }; return }
                    info.id = doc.documentID
                    
                    /// add any user who matches here except for active user
                    if !self.queryUsers.contains(where: {$0.0.id == info.id}) && info.id != self.uid {
                        if !self.queryValid(searchText: searchText) { return }
                        let status: FriendStatus = self.mapVC.friendIDs.contains(info.id!) ? .friends : self.mapVC.userInfo.pendingFriendRequests.contains(info.id!) ? .pending : .none
                        self.queryUsers.append((info, status))
                    }
                    
                    if doc == docs.last { self.reloadResultsTable() }
                    
                } catch { if doc == docs.last { self.reloadResultsTable() } }
            }
        }
    }
    
    func queryValid(searchText: String) -> Bool {
        return searchText == searchTextGlobal && searchText != ""
    }
    
    func reloadResultsTable() {
        
        searchRefreshCount += 1
        if searchRefreshCount < 2 { return }
        
        if resultsTable.isHidden { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.searchIndicator.stopAnimating()
            self.resultsTable.reloadData()
            return
        }
    }
}

class SendInvitesView: UIView {
    
    var sendImage: UIImageView!
    var sendLabel: UILabel!
    var invitesLabel: UILabel!
    
    func setUp(invites: Int) {
        
        if sendImage != nil { sendImage.image = UIImage() }
        sendImage = UIImageView(frame: CGRect(x: 14, y: 12, width: 56, height: 56))
        sendImage.image = UIImage(named: "SendInvitesIcon")
        addSubview(sendImage)
        
        if sendLabel != nil { sendLabel.text = "" }
        sendLabel = UILabel(frame: CGRect(x: sendImage.frame.maxX + 12, y: 24, width: 100, height: 14))
        sendLabel.text = "Send Invites"
        sendLabel.textColor = invites == 0 ? UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1) : UIColor.white
        sendLabel.font = UIFont(name: "SFCamera-Semibold", size: 15)
        addSubview(sendLabel)
        
        if invitesLabel != nil { invitesLabel.text = "" }
        invitesLabel = UILabel(frame: CGRect(x: sendImage.frame.maxX + 12, y: sendLabel.frame.maxY + 2, width: 140, height: 16))
        let contactsString = invites == 1 ? "\(invites) invite" : "\(invites) invites"
        invitesLabel.text = contactsString + " remaining"
        invitesLabel.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        invitesLabel.font = UIFont(name: "SFCamera-Regular", size: 13)
        addSubview(invitesLabel)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = nil
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SearchContactsView: UIView {
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        backgroundColor = nil
        
        let contactsImage = UIImageView(frame: CGRect(x: 14, y: 12, width: 56, height: 56))
        contactsImage.image = UIImage(named: "SearchContactsIcon")
        addSubview(contactsImage)
        
        let searchLabel = UILabel(frame: CGRect(x: contactsImage.frame.maxX + 12, y: 24, width: 150, height: 14))
        searchLabel.text = "Search contacts"
        searchLabel.textColor = UIColor.white
        searchLabel.font = UIFont(name: "SFCamera-Semibold", size: 15)
        addSubview(searchLabel)
        
        let contactsLabel = UILabel(frame: CGRect(x: contactsImage.frame.maxX + 12, y: searchLabel.frame.maxY + 2, width: UIScreen.main.bounds.width - (contactsImage.frame.maxX + 12), height: 16))
        contactsLabel.text = "See which of your friends are already on sp0t"
        contactsLabel.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        contactsLabel.font = UIFont(name: "SFCamera-Regular", size: 13)
        contactsLabel.clipsToBounds = false
        contactsLabel.numberOfLines = 0
        contactsLabel.lineBreakMode = .byWordWrapping
        addSubview(contactsLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

class SuggestedFriendsHeader: UITableViewHeaderFooterView {
    
    var label: UILabel!
    var refreshButton: UIButton!
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView

        if label != nil { label.text = "" }
        label = UILabel(frame: CGRect(x: 14, y: 3, width: 125, height: 20))
        label.text = "Suggested friends"
        label.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        label.font = UIFont(name: "SFCamera-Regular", size: 13)
        addSubview(label)
        
        if refreshButton != nil { refreshButton.setTitle("", for: .normal) }
        refreshButton = UIButton(frame: CGRect(x: label.frame.maxX, y: 0, width: 60, height: 26))
        refreshButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        refreshButton.setTitle("REFRESH", for: .normal)
        refreshButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        refreshButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 10.5)
        refreshButton.contentVerticalAlignment = .center
        refreshButton.contentHorizontalAlignment = .center
        refreshButton.addTarget(self, action: #selector(refreshTap(_:)), for: .touchUpInside)
        addSubview(refreshButton)
    }
    
    @objc func refreshTap(_ sender: UIButton) {
        if let vc = viewContainingController() as? FindFriendsController {
            Mixpanel.mainInstance().track(event: "FindFriendsRefresh")
            vc.suggestedUsers.shuffle()
            DispatchQueue.main.async { vc.suggestedTable.reloadData() }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SuggestedFriendCell: UITableViewCell {
    
    var userID = ""
    
    var profilePic: UIImageView!
    var nameLabel: UILabel!
    var usernameLabel: UILabel!
    var mutualsLabel: UILabel!
    var separatorView: UIView!
    var spotsLabel: UILabel!
    var addFriendButton: UIButton!
    var bottomLine: UIView!
    
    func setUp(user: UserProfile, status: FriendStatus) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        contentView.isUserInteractionEnabled = false
        
        resetView()
        userID = user.id!
        
        profilePic = UIImageView(frame: CGRect(x: 14, y: 12, width: 52, height: 52))
        profilePic.layer.masksToBounds = false
        profilePic.layer.cornerRadius = profilePic.frame.height/2
        profilePic.clipsToBounds = true
        profilePic.contentMode = UIView.ContentMode.scaleAspectFill
        self.addSubview(profilePic)
        
        let url = user.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }

        nameLabel = UILabel(frame: CGRect(x: profilePic.frame.maxX + 11, y: 13.5, width: 200, height: 15))
        nameLabel.text = user.name
        nameLabel.textColor = UIColor(red: 0.946, green: 0.946, blue: 0.946, alpha: 1)
        nameLabel.font = UIFont(name: "SFCamera-Semibold", size: 13.5)
        nameLabel.sizeToFit()
        nameLabel.textAlignment = .left
        
        addSubview(nameLabel)
        
        usernameLabel = UILabel(frame: CGRect(x: profilePic.frame.maxX + 11, y: nameLabel.frame.maxY + 1, width: 200, height: 16))
        usernameLabel.text = "@" + user.username
        usernameLabel.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        usernameLabel.font = UIFont(name: "SFCamera-Regular", size: 12)
        usernameLabel.sizeToFit()
        addSubview(usernameLabel)
        
        if user.mutualFriends > 0 {
            mutualsLabel = UILabel(frame: CGRect(x: profilePic.frame.maxX + 11, y: usernameLabel.frame.maxY + 3, width: 60, height: 14.5))
            var mutualsText = "\(user.mutualFriends)"
            mutualsText += user.mutualFriends == 1 ? " mutual friend" : " mutual friends"
            mutualsLabel.text = mutualsText
            mutualsLabel.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
            mutualsLabel.font = UIFont(name: "SFCamera-Regular", size: 12)
            mutualsLabel.sizeToFit()
            addSubview(mutualsLabel)
            
            if user.spotsList.count > 1 {
                separatorView = UIView(frame: CGRect(x: mutualsLabel.frame.maxX + 9, y: mutualsLabel.frame.midY - 0.7, width: 5, height: 2))
                separatorView.backgroundColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
                separatorView.layer.cornerRadius = 0.5
                addSubview(separatorView)
            }
        }

        if user.spotsList.count > 1 {
            let minX = user.mutualFriends > 0 ? separatorView.frame.maxX + 11 : profilePic.frame.maxX + 11
            spotsLabel = UILabel(frame: CGRect(x: minX, y: usernameLabel.frame.maxY + 3, width: 60, height: 14.5))
            var spotsText = "\(user.spotsList.count)"
            spotsText += user.spotsList.count == 1 ? " spot" : " spots"
            spotsLabel.text = spotsText
            spotsLabel.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
            spotsLabel.font = UIFont(name: "SFCamera-Regular", size: 12)
            addSubview(spotsLabel)
        }

        addFriendButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 112, y: 17, width: 104, height: 42))
        addFriendButton.imageEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        addFriendButton.imageView?.contentMode = .scaleAspectFit
        
        switch status {
        case .friends:
            addFriendButton.setImage(UIImage(named: "ContactsFriends"), for: UIControl.State.normal)
        case .pending:
            addFriendButton.setImage(UIImage(named: "ContactsPending"), for: UIControl.State.normal)
        default:
            addFriendButton.setImage(UIImage(named: "ContactsAddFriend"), for: .normal)
            addFriendButton.addTarget(self, action: #selector(addFriendTap(_:)), for: .touchUpInside)
        }
        
        addSubview(addFriendButton)
        
        bottomLine = UIView(frame: CGRect(x: 0, y: 75, width: UIScreen.main.bounds.width, height: 1))
        bottomLine.backgroundColor = UIColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1)
        addSubview(bottomLine)
    }
    
    func resetView() {
        if profilePic != nil { profilePic.image = UIImage() }
        if nameLabel != nil { nameLabel.text = "" }
        if usernameLabel != nil { usernameLabel.text = "" }
        if mutualsLabel != nil { mutualsLabel.text = "" }
        if separatorView != nil { separatorView.backgroundColor = nil }
        if spotsLabel != nil { spotsLabel.text = "" }
        if addFriendButton != nil { addFriendButton.setImage(UIImage(), for: .normal) }
        if bottomLine != nil { bottomLine.backgroundColor = nil }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
    }
    
    @objc func addFriendTap(_ sender: UIButton) {

        if let vc = viewContainingController() as? FindFriendsController {
            
            Mixpanel.mainInstance().track(event: "FindFriendsAddFriend")

            /// add friend from DB
            DispatchQueue.global(qos: .utility).async { self.addFriend(senderProfile: vc.mapVC.userInfo, receiverID: self.userID) }
            
            /// adjust UX with new pending
            if let i = vc.suggestedUsers.firstIndex(where: {$0.0.id == userID}) {
                vc.suggestedUsers[i].1 = .pending
                vc.mapVC.userInfo.pendingFriendRequests.append(userID)
                DispatchQueue.main.async { vc.suggestedTable.reloadData() }
            }
        }
    }
}

class SuggestedFriendSearchCell: UITableViewCell {
    
    var userID: String = ""
    
    var profilePic: UIImageView!
    var nameLabel: UILabel!
    var usernameLabel: UILabel!
    var addFriendButton: UIButton!

    func setUp(user: UserProfile, status: FriendStatus) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        contentView.isUserInteractionEnabled = false
        
        userID = user.id!
        resetView()

        profilePic = UIImageView(frame: CGRect(x: 14, y: 10, width: 44, height: 44))
        profilePic.layer.masksToBounds = false
        profilePic.layer.cornerRadius = profilePic.frame.height/2
        profilePic.clipsToBounds = true
        profilePic.contentMode = UIView.ContentMode.scaleAspectFill
        self.addSubview(profilePic)
        
        let url = user.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }

        nameLabel = UILabel(frame: CGRect(x: profilePic.frame.maxX + 9, y: 16, width: 200, height: 15))
        nameLabel.text = user.name
        nameLabel.textColor = UIColor(red: 0.946, green: 0.946, blue: 0.946, alpha: 1)
        nameLabel.font = UIFont(name: "SFCamera-Semibold", size: 13.5)
        nameLabel.sizeToFit()
        nameLabel.textAlignment = .left
        
        addSubview(nameLabel)
        
        usernameLabel = UILabel(frame: CGRect(x: profilePic.frame.maxX + 9, y: nameLabel.frame.maxY + 1, width: 200, height: 16))
        usernameLabel.text = "@" + user.username
        usernameLabel.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        usernameLabel.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        usernameLabel.sizeToFit()
        addSubview(usernameLabel)
        
        addFriendButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 112, y: 8, width: 104, height: 42))
        addFriendButton.imageEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        addFriendButton.imageView?.contentMode = .scaleAspectFit
        
        switch status {
        case .friends:
            addFriendButton.setImage(UIImage(named: "ContactsFriends"), for: UIControl.State.normal)
        case .pending:
            addFriendButton.setImage(UIImage(named: "ContactsPending"), for: UIControl.State.normal)
        default:
            addFriendButton.setImage(UIImage(named: "ContactsAddFriend"), for: .normal)
            addFriendButton.addTarget(self, action: #selector(addFriendTap(_:)), for: .touchUpInside)
        }

        addSubview(addFriendButton)
    }
    
    func resetView() {
        if profilePic != nil { profilePic.image = UIImage() }
        if nameLabel != nil { nameLabel.text = "" }
        if usernameLabel != nil { usernameLabel.text = "" }
        if addFriendButton != nil { addFriendButton.setImage(UIImage(), for: .normal) }
    }
    
    @objc func addFriendTap(_ sender: UIButton) {
        
        if let vc = viewContainingController() as? FindFriendsController {
            
            Mixpanel.mainInstance().track(event: "FindFriendsSearchAddFriend")

        /// send friend request from DB
            DispatchQueue.global(qos: .utility).async { self.addFriend(senderProfile: vc.mapVC.userInfo, receiverID: self.userID) }
            
            /// update local data
            if let i = vc.queryUsers.firstIndex(where: {$0.0.id == userID}) {
                vc.queryUsers[i].1 = .pending
                vc.mapVC.userInfo.pendingFriendRequests.append(userID)
                DispatchQueue.main.async { vc.resultsTable.reloadData() }
                
                if let i = vc.suggestedUsers.firstIndex(where: {$0.0.id == userID}) {
                    vc.suggestedUsers[i].1 = .pending
                    DispatchQueue.main.async { vc.suggestedTable.reloadData() }
                }
            }
        }
    }

}

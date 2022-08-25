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
import Geofirestore
import CoreLocation

enum FriendStatus {
    case none
    case pending
    case friends
}

class FindFriendsController: UIViewController {
    
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
    lazy var nearbyEnteredCount = 0
    lazy var nearbyAppendCount = 0
    
    var sendInvitesView: SendInvitesView!
    var searchContactsView: SearchContactsView!
    var suggestedIndicator: CustomActivityIndicator!
    var suggestedTable: UITableView!
    
    var contentDrawer: DrawerView?
    let sp0tb0tID = "T4KMLe3XlQaPBJvtZVArqXQvaNT2"
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        view.backgroundColor = .white
        
        self.title = "Find Friends"
        navigationItem.backButtonTitle = ""
        
        navigationController!.navigationBar.barTintColor = UIColor.white
        navigationController!.navigationBar.isTranslucent = false
        navigationController!.navigationBar.barStyle = .black
        navigationController!.navigationBar.tintColor = UIColor.black
        navigationController?.view.backgroundColor = .white
        navigationController?.navigationBar.addWhiteBackground()
        
        
        navigationController!.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0, green: 0, blue: 0, alpha: 1),
            .font: UIFont(name: "SFCompactText-Heavy", size: 20)!
        ]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "BackArrowDark"),
            style: .plain,
            target: self,
            action: #selector(self.exit(_:))
        )
        
        loadSearchBar()
        loadOutletViews()
        loadSuggestedTable()
        
        DispatchQueue.global(qos: .userInitiated).async { self.getSuggestedFriends() }
        
        NotificationCenter.default.addObserver(self, selector: #selector(notifyRequestSent(_:)), name: NSNotification.Name("FriendRequest"), object: nil)
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
    
    func loadSearchBar() {
        
        searchBarContainer = UIView {
            $0.backgroundColor = nil
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        searchBarContainer.snp.makeConstraints{
            $0.leading.trailing.equalToSuperview()
            $0.top.equalToSuperview().offset(20)
            $0.width.equalToSuperview()
            $0.height.equalTo(36)
        }
        
        searchBar = UISearchBar {
            $0.searchBarStyle = .default
            $0.tintColor = UIColor(named: "SpotGreen")
            $0.barTintColor = UIColor(red: 0.945, green: 0.945, blue: 0.949, alpha: 1)
            $0.searchTextField.backgroundColor = UIColor(red: 0.945, green: 0.945, blue: 0.949, alpha: 1)
            $0.searchTextField.leftView?.tintColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            $0.delegate = self
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
            $0.placeholder = "Search users"
            $0.searchTextField.font = UIFont(name: "SFCompactText-Medium", size: 15)
            $0.clipsToBounds = true
            $0.layer.masksToBounds = true
            $0.searchTextField.layer.masksToBounds = true
            $0.searchTextField.clipsToBounds = true
            $0.layer.cornerRadius = 2
            $0.searchTextField.layer.cornerRadius = 2
            $0.backgroundImage = UIImage()
            $0.translatesAutoresizingMaskIntoConstraints = false
            searchBarContainer.addSubview($0)
        }
        searchBar.snp.makeConstraints{
            $0.leading.equalToSuperview().offset(16)
            $0.trailing.equalToSuperview().offset(-16)
            $0.top.bottom.equalToSuperview()
        }
        
        cancelButton = UIButton{
            $0.setTitle("Cancel", for: .normal)
            $0.setTitleColor(UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1), for: .normal)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 14)
            $0.titleLabel?.textAlignment = .center
            $0.titleEdgeInsets = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
            $0.addTarget(self, action: #selector(searchCancelTap(_:)), for: .touchUpInside)
            $0.isHidden = true
            searchBarContainer.addSubview($0)
        }
        
        cancelButton.snp.makeConstraints{
            $0.trailing.equalToSuperview().offset(-16)
            $0.centerY.equalTo(searchBar.snp.centerY)
        }
        
        resultsTable = UITableView {
            $0.dataSource = self
            $0.delegate = self
            $0.isScrollEnabled = false
            $0.backgroundColor = .white
            $0.separatorStyle = .none
            $0.allowsSelection = false
            $0.isHidden = true
            $0.register(ContactCell.self, forCellReuseIdentifier: "ContactCell")
            $0.tag = 1
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        resultsTable.snp.makeConstraints{
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(searchBarContainer.snp.bottom)
            $0.width.equalToSuperview()
            $0.height.equalTo(UIScreen.main.bounds.height - searchBarContainer.frame.maxY)
        }
        
        searchIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 20, width: UIScreen.main.bounds.width, height: 30))
        searchIndicator.isHidden = true
        resultsTable.addSubview(searchIndicator)
    }
    
    func loadOutletViews() {
        
        /// set up outlet views to search contacts + send invites
        mainView = UIView{
            $0.backgroundColor = nil
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        mainView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(searchBarContainer.snp.bottom).offset(20)
            $0.bottom.equalToSuperview()
        }
        
        sendInvitesView = SendInvitesView()
        sendInvitesView.setUp()
        sendInvitesView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(presentSendInvites(_:))))
        mainView.addSubview(sendInvitesView)
        
        sendInvitesView.snp.makeConstraints{
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(60)
            $0.top.equalToSuperview()
        }
        
        searchContactsView = SearchContactsView()
        searchContactsView.setUp()
        searchContactsView.isUserInteractionEnabled = true
        searchContactsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(presentSearchContacts(_:))))
        mainView.addSubview(searchContactsView)
        
        searchContactsView.snp.makeConstraints{
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(60)
            $0.top.equalTo(sendInvitesView.snp.bottom).offset(20)
        }
        
    }
    
    func loadSuggestedTable() {
        
        suggestedTable = UITableView {
            $0.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            $0.backgroundColor = .white
            $0.tag = 0
            $0.separatorStyle = .none
            $0.allowsSelection = false
            $0.delegate = self
            $0.dataSource = self
            $0.isScrollEnabled = false
            $0.register(ContactCell.self, forCellReuseIdentifier: "ContactCell")
            $0.register(SuggestedFriendsHeader.self, forHeaderFooterViewReuseIdentifier: "SuggestedHeader")
            mainView.addSubview($0)
        }
        suggestedTable.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(searchContactsView.snp.bottom).offset(20)
            $0.bottom.equalToSuperview().offset(-50)
        }
        
        suggestedIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 40, width: UIScreen.main.bounds.width, height: 30))
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
            UserDataModel.shared.userInfo.pendingFriendRequests.append(receiverID)
        }
    }
    
    @objc func presentSendInvites(_ sender: UITapGestureRecognizer) {
        
        let adminID = uid == "kwpjnnDCSKcTZ0YKB3tevLI1Qdi2" || uid == "Za1OQPFoCWWbAdxB5yu98iE8WZT2"
        if UserDataModel.shared.userInfo.sentInvites.count > 7 && !adminID { return }
        
        let sendInvitesVC = SendInvitesController()
        navigationController!.pushViewController(sendInvitesVC, animated: true)
    }
    
    @objc func presentSearchContacts(_ sender: UITapGestureRecognizer) {
        let searchContactsVC = SearchContactsController()
        navigationController!.pushViewController(searchContactsVC, animated: true)
    }
    
    
    @objc func exit(_ sender: UIButton) {
        if let drawer = contentDrawer {
            drawer.closeAction()
        } else { navigationController!.popViewController(animated: true)
        }
    }
    
    @objc func searchCancelTap(_ sender: UIButton) {
        searchBar.resignFirstResponder()
    }
    
    func getSuggestedFriends() {
        
        /// get mutual friends by cycling through friends of everyone on friendsList
        
        var mutuals: [(id: String, count: Int)] = []
        
        var x = 0 /// outer friends list counter
        
        for friend in UserDataModel.shared.userInfo.friendsList {
            
            var y = 0 /// inner friendslist counter
            if UserDataModel.shared.adminIDs.contains(friend.id!) { x += 1; if x == UserDataModel.shared.userInfo.friendsList.count { runMutualSort(mutuals: mutuals) }; continue }
            
            for id in friend.friendIDs {
                
                /// only add non-friends + people we haven't sent a request to yet
                if !UserDataModel.shared.userInfo.friendIDs.contains(id) && !UserDataModel.shared.userInfo.pendingFriendRequests.contains(id) && id != uid && id != sp0tb0tID {
                    
                    if let i = mutuals.firstIndex(where: {$0.id == id}) {
                        /// increment mutuals index if already added to mutuals
                        mutuals[i].count += 1
                        y += 1; if y == friend.friendIDs.count { x += 1; if x == UserDataModel.shared.userInfo.friendsList.count { runMutualSort(mutuals: mutuals) }}
                    } else {
                        /// add new mutual to mutuals
                        mutuals.append((id: id, count: 1))
                        y += 1; if y == friend.friendIDs.count { x += 1; if x == UserDataModel.shared.userInfo.friendsList.count { runMutualSort(mutuals: mutuals) }}
                    }
                } else { y += 1; if y == friend.friendIDs.count { x += 1; if x == UserDataModel.shared.userInfo.friendsList.count { runMutualSort(mutuals: mutuals) }} }
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
            addSortedFriends(mutuals: mutuals)
        }
    }
    
    func getPendingFriends(mutuals: [(id: String, count: Int)]) {
        var pendingRequests = UserDataModel.shared.userInfo.pendingFriendRequests
        
        var mutuals = mutuals
        var secondaryMutuals: [(id: String, secondaryCount: Int)] = [] /// get "mutuals" from pending friend requests to fill up the rest of suggestions
        
        var pendingIndex = 0
        if pendingRequests.count == 0 {
            if mutuals.count < 5 {
                getNearbyUsers(radius: 0.5)
            } else {
                addSortedFriends(mutuals: mutuals)
            }
            return
        }

        for id in pendingRequests {
            self.db.collection("users").document(id).getDocument { [weak self] (snap, err) in
                guard let self = self else { return }
                
                if let friendsList = snap?.get("friendsList") as? [String] {
                    
                    for id in friendsList {
                        if !UserDataModel.shared.userInfo.friendIDs.contains(id) && !UserDataModel.shared.userInfo.pendingFriendRequests.contains(id) {
                            
                            if let i = secondaryMutuals.firstIndex(where: {$0.id == id}) {
                                secondaryMutuals[i].secondaryCount += 1
                            } else {
                                secondaryMutuals.append((id: id, secondaryCount: 1))
                            }
                        }
                        
                        if id == friendsList.last {
                            pendingIndex += 1
                            if pendingIndex == pendingRequests.count {
                                /// add secondary mutuals at the end of the array. sort by spotscore if the user doesn't have a lot of secondary mutuals (usually just spotbot as mutual)
                                secondaryMutuals.sort(by: {$0.secondaryCount > $1.secondaryCount})
                                for user in secondaryMutuals { mutuals.append((id: user.id, count: 0)) }
                                self.addSortedFriends(mutuals: mutuals)
                            }
                        }
                    }
                    
                } else {
                    pendingIndex += 1
                    if pendingIndex == pendingRequests.count {
                        /// add secondary mutuals at the end of the array
                        secondaryMutuals.sort(by: {$0.secondaryCount > $1.secondaryCount})
                        for user in secondaryMutuals { mutuals.append((id: user.id, count: 0)) }
                        self.addSortedFriends(mutuals: mutuals)
                    }
                }
            }
        }
    }
    
    func addSortedFriends(mutuals: [(id: String, count: Int)]) {
        
        var index = 0
        let topMutuals = mutuals.prefix(20) /// make the selection much larger for new users to always get top spotters in their suggested
        if topMutuals.count == 0 { removeTable() }
        
        /// get user data for top 20 mutuals
        for user in topMutuals {
            
            self.db.collection("users").document(user.id).getDocument { [weak self] (snap, err) in
                guard let self = self else { return }
                
                do {
                    let userIn = try snap?.data(as: UserProfile.self)
                    guard var userInfo = userIn else { index += 1; if index == topMutuals.count { self.finishSuggestedLoad()}; return }
                    userInfo.mutualFriends = user.count
                    self.suggestedUsers.append((userInfo, .none))
                    index += 1
                    if index == topMutuals.count { self.finishSuggestedLoad() }
                    
                } catch {
                    index += 1
                    if index == topMutuals.count { self.finishSuggestedLoad() }
                }
            }
        }
    }
    
    func getNearbyUsers(radius: CGFloat) {
        let geoFirestore = GeoFirestore(collectionRef: Firestore.firestore().collection("posts"))
        let circleQuery = geoFirestore.query(withCenter: UserDataModel.shared.currentLocation, radius: radius)
        let _ = circleQuery.observe(.documentEntered, with: loadPostFromDB)
        let _ = circleQuery.observeReady { [weak self] in
            guard let self = self else { return }
            if self.nearbyEnteredCount < 5 {
                self.nearbyEnteredCount = 0
                self.nearbyAppendCount = 0
                self.getNearbyUsers(radius: radius * 2)
            }
        }
    }
    
    func loadPostFromDB(key: String?, location: CLLocation?) {
        nearbyEnteredCount += 1
        guard let postKey = key else { return }
        getPost(postID: postKey) { post in
            if post.posterID != "" && !UserDataModel.shared.userInfo.friendIDs.contains(where: {$0 == post.posterID}) && !self.suggestedUsers.contains(where: {$0.0.id == post.posterID}) { self.suggestedUsers.append((post.userInfo!, .none)) }
            self.nearbyAppendCount += 1
            if self.nearbyEnteredCount == self.nearbyAppendCount {
                self.finishSuggestedLoad()
            }
        }
    }
    
    func finishSuggestedLoad() {
        /// sort by combined spots x mutual friends
        suggestedUsers.sort(by: {$0.0.spotScore!/5 + $0.0.mutualFriends > $1.0.spotScore!/5 + $1.0.mutualFriends})
        
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
        let maxRows = UserDataModel.shared.screenSize == 0 ? 4 : 5
        return dataSource.count > maxRows ? maxRows : dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let dataSource = tableView.tag == 0 ? suggestedUsers : queryUsers
        if let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCell") as? ContactCell {
            let user = dataSource[indexPath.row]
            cell.set(contact: user.0, inviteContact: nil, friend: user.1, invited: .none)
            return cell
            
        }  else { return UITableViewCell() }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SuggestedHeader") as? SuggestedFriendsHeader {
            return header
        } else { return UITableViewHeaderFooterView() }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return tableView.tag == 0 ? 28 : 0
    }
    
}

extension FindFriendsController: UISearchBarDelegate {
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        
        UIView.animate(withDuration: 0.1) {
            searchBar.snp.remakeConstraints{
                $0.leading.equalToSuperview().offset(16)
                $0.trailing.equalToSuperview().offset(-60)
                $0.top.equalToSuperview()
                $0.height.equalTo(36)
            }
            self.view.layoutIfNeeded()
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
        
        UIView.animate(withDuration: 0.1) {
            self.cancelButton.isHidden = true
            searchBar.snp.updateConstraints{
                $0.trailing.equalToSuperview().offset(-16)
            }
            self.view.layoutIfNeeded()
        }
        
        self.searchBar.text = ""
        
        emptyQueries()
        
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
        let nameQuery = userRef.whereField("nameKeywords", arrayContains: searchText.lowercased()).limit(to: 5)
        
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
                        let status: FriendStatus = UserDataModel.shared.userInfo.friendIDs.contains(info.id!) ? .friends : UserDataModel.shared.userInfo.pendingFriendRequests.contains(info.id!) ? .pending : .none
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
        let usernameQuery = userRef.whereField("usernameKeywords", arrayContains: searchText.lowercased()).limit(to: 5)
        
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
                        let status: FriendStatus = UserDataModel.shared.userInfo.friendIDs.contains(info.id!) ? .friends : UserDataModel.shared.userInfo.pendingFriendRequests.contains(info.id!) ? .pending : .none
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
    
    var inviteFriendsIcon: UIImageView!
    var carot: UIImageView!
    var inviteFriendsText: UILabel!
    
    func setUp() {
        
        self.backgroundColor = .white
        
        inviteFriendsIcon = UIImageView {
            $0.layer.masksToBounds = false
            $0.clipsToBounds = false
            $0.contentMode = UIView.ContentMode.left
            $0.isHidden = false
            $0.translatesAutoresizingMaskIntoConstraints = true
            $0.image =  UIImage(named: "InviteFriends")
            $0.layer.cornerRadius = 0
            self.addSubview($0)
        }
        
        inviteFriendsIcon.snp.makeConstraints{
            $0.width.height.equalTo(56)
            $0.centerY.equalToSuperview()
            $0.leading.equalToSuperview().offset(16)
        }
        
        carot = UIImageView {
            $0.layer.masksToBounds = false
            $0.clipsToBounds = false
            $0.contentMode = UIView.ContentMode.right
            $0.isHidden = false
            $0.translatesAutoresizingMaskIntoConstraints = true
            $0.image =  UIImage(named: "SideCarat")
            $0.layer.cornerRadius = 0
            self.addSubview($0)
        }
        
        carot.snp.makeConstraints{
            $0.width.equalTo(12.73)
            $0.height.equalTo(19.8)
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().offset(-20)
        }
        
        inviteFriendsText = UILabel{
            $0.text = "Invite Friends"
            $0.numberOfLines = 0
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 16)
            $0.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview($0)
        }
        
        inviteFriendsText.snp.makeConstraints{
            $0.centerY.equalToSuperview()
            $0.leading.equalTo(inviteFriendsIcon.snp.trailing).offset(10)
        }
        
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
    
    var searchContactsIcon: UIImageView!
    var carot: UIImageView!
    var searchContactsText: UILabel!
    
    func setUp(){
        
        self.backgroundColor = .white
        
        searchContactsIcon = UIImageView {
            $0.layer.masksToBounds = false
            $0.clipsToBounds = false
            $0.contentMode = UIView.ContentMode.left
            $0.isHidden = false
            $0.translatesAutoresizingMaskIntoConstraints = true
            $0.image =  UIImage(named: "SearchContacts")
            $0.layer.cornerRadius = 0
            self.addSubview($0)
        }
        
        searchContactsIcon.snp.makeConstraints{
            $0.width.height.equalTo(56)
            $0.centerY.equalToSuperview()
            $0.leading.equalToSuperview().offset(16)
        }
        
        
        carot = UIImageView {
            $0.layer.masksToBounds = false
            $0.clipsToBounds = false
            $0.contentMode = UIView.ContentMode.right
            $0.isHidden = false
            $0.translatesAutoresizingMaskIntoConstraints = true
            $0.image =  UIImage(named: "SideCarat")
            $0.layer.cornerRadius = 0
            self.addSubview($0)
        }
        
        carot.snp.makeConstraints{
            $0.width.equalTo(12.73)
            $0.height.equalTo(19.8)
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().offset(-20)
        }
        
        
        searchContactsText = UILabel{
            $0.text = "Search contacts"
            $0.numberOfLines = 0
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 16)
            $0.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview($0)
        }
        
        searchContactsText.snp.makeConstraints{
            $0.centerY.equalToSuperview()
            $0.leading.equalTo(searchContactsIcon.snp.trailing).offset(10)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = nil
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
        backgroundView.backgroundColor = .white
        self.backgroundView = backgroundView
        
        if label != nil { label.text = "" }
        
        
        label = UILabel {
            $0.text = "Suggested friends"
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            addSubview($0)
        }
        
        label.snp.makeConstraints{
            $0.leading.equalToSuperview().offset(14)
            $0.centerY.equalToSuperview()
        }
        
        if refreshButton != nil { refreshButton.setTitle("", for: .normal) }
        
        refreshButton = UIButton{
            $0.setImage(UIImage(named: "RefreshIcon"), for: .normal)
            $0.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 4)
            $0.titleEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.setTitle("Refresh", for: .normal)
            $0.setTitleColor(UIColor(red: 0, green: 0, blue: 0, alpha: 1), for: .normal)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.contentVerticalAlignment = .center
            $0.contentHorizontalAlignment = .center
            $0.addTarget(self, action: #selector(refreshTap(_:)), for: .touchUpInside)
            addSubview($0)
        }
        
        refreshButton.snp.makeConstraints{
            $0.trailing.equalToSuperview().offset(-20)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(80)
            $0.height.equalTo(30)
        }
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


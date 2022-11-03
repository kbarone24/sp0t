//
//  FindFriendsController.swift
//  Spot
//
//  Created by Kenny Barone on 3/28/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import CoreLocation
import Firebase
import FirebaseUI
import Foundation
import Geofirestore
import Mixpanel
import UIKit
import Contacts

enum FriendStatus {
    case none
    case pending
    case friends
}

class FindFriendsController: UIViewController {
    let db: Firestore = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    var containerDrawerView: DrawerView?

    lazy var activeSearch = false
    lazy var contacts: [(UserProfile, FriendStatus)] = []
    lazy var mutuals: [(id: String, score: Int)] = []
    lazy var suggestedUsers: [(UserProfile, FriendStatus)] = []
    lazy var queryUsers: [(UserProfile, FriendStatus)] = []
    lazy var searchRefreshCount = 0
    lazy var searchTextGlobal = ""
    lazy var nearbyEnteredCount = 0
    lazy var nearbyAppendCount = 0

    lazy var searchBarContainer = UIView()
    lazy var searchBar = SpotSearchBar()
    lazy var cancelButton = TextCancelButton()
    lazy var searchIndicator = CustomActivityIndicator()
    lazy var activityIndicator = CustomActivityIndicator()

    lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        tableView.backgroundColor = .white
        tableView.tag = 0
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.isScrollEnabled = true
        tableView.register(ContactCell.self, forCellReuseIdentifier: "ContactCell")
        tableView.register(InviteFriendsCell.self, forCellReuseIdentifier: "InviteFriends")
        tableView.register(SearchContactsCell.self, forCellReuseIdentifier: "SearchContacts")
        tableView.register(FindFriendsHeader.self, forHeaderFooterViewReuseIdentifier: "FindFriendsHeader")
        return tableView
    }()

    let dispatch = DispatchGroup()
    var contactsAuth: CNAuthorizationStatus {
        return CNContactStore.authorizationStatus(for: .contacts)
    }

    var contactsHidden: Bool {
        return contactsAuth == .authorized && contacts.isEmpty
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        loadSearchBar()
        loadTableView()
        fetchTableData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Mixpanel.mainInstance().track(event: "FindFriendsOpen")
        NotificationCenter.default.addObserver(self, selector: #selector(notifyAddFriend(_:)), name: NSNotification.Name("ContactCellAddFriend"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyHideUser(_:)), name: NSNotification.Name("ContactCellHideUser"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyProfileAddFriend(_:)), name: NSNotification.Name("SendFriendRequest"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendsLoad), name: NSNotification.Name(("FriendsListLoad")), object: nil)
        setUpNavBar()
        configureDrawerView()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setUpNavBar() {
        title = "Find Friends"
        navigationItem.backButtonTitle = ""

        navigationController?.navigationBar.barTintColor = UIColor.white
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.tintColor = UIColor.black
        navigationController?.view.backgroundColor = .white
        navigationController?.navigationBar.addWhiteBackground()

        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0, green: 0, blue: 0, alpha: 1),
            .font: UIFont(name: "SFCompactText-Heavy", size: 20) as Any
        ]
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "BackArrowDark"),
            style: .plain,
            target: self,
            action: #selector(self.exit(_:))
        )
    }

    private func configureDrawerView() {
        containerDrawerView?.canInteract = false
        containerDrawerView?.swipeDownToDismiss = false
        containerDrawerView?.showCloseButton = false
        containerDrawerView?.present(to: .top)
    }

    private func loadSearchBar() {
        view.addSubview(searchBarContainer)
        searchBarContainer.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalToSuperview().offset(20)
            $0.width.equalToSuperview()
            $0.height.equalTo(50)
        }
        
        searchBar.delegate = self
        searchBar.searchTextField.attributedPlaceholder = NSAttributedString(
            string: "Search users",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)]
        )
        
        searchBarContainer.addSubview(searchBar)
        searchBar.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.trailing.equalToSuperview().offset(-16)
            $0.top.bottom.equalToSuperview()
        }
        
        cancelButton.addTarget(self, action: #selector(searchCancelTap(_:)), for: .touchUpInside)
        searchBarContainer.addSubview(cancelButton)
        cancelButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-16)
            $0.centerY.equalTo(searchBar.snp.centerY)
        }
        
        searchIndicator.isHidden = true
        tableView.addSubview(searchIndicator)
        searchIndicator.snp.makeConstraints {
            $0.top.equalTo(20)
            $0.centerX.equalToSuperview()
            $0.height.width.equalTo(30)
        }
    }

    private func loadTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.top.equalTo(searchBarContainer.snp.bottom).offset(10)
        }
        
        tableView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.top.equalToSuperview().offset(180)
            $0.centerX.equalToSuperview()
            $0.height.width.equalTo(30)
        }
        DispatchQueue.main.async { self.activityIndicator.startAnimating() }
    }

    @objc func notifyAddFriend(_ sender: NSNotification) {
        // notify request sent from search contacts and update suggested users if necessary
        if let receiverID = sender.userInfo?.first?.value as? String {
            updateFriendStatus(id: receiverID)
        }
    }

    func updateFriendStatus(id: String) {
        if let i = suggestedUsers.firstIndex(where: { $0.0.id == id }) {
            suggestedUsers[i].1 = .pending
        }
        if let i = contacts.firstIndex(where: { $0.0.id == id }) {
            contacts[i].1 = .pending
        }
        if let i = queryUsers.firstIndex(where: { $0.0.id == id }) {
            queryUsers[i].1 = .pending
        }
        DispatchQueue.main.async { self.tableView.reloadData() }
    }

    @objc func notifyHideUser(_ sender: NSNotification) {
        if let receiverID = sender.userInfo?.first?.value as? String {
            suggestedUsers.removeAll(where: { $0.0.id == receiverID })
            contacts.removeAll(where: { $0.0.id == receiverID })
            DispatchQueue.main.async { self.tableView.reloadData() }
        }
    }

    @objc func exit(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "FindFriendsExitTap")
        if let drawer = containerDrawerView {
            drawer.closeAction()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    @objc func searchCancelTap(_ sender: UIButton) {
        searchBar.resignFirstResponder()
    }

    @objc func searchContactsTap() {
        // ask for contacts access or open settings
        checkContactsAuth()
    }

    func checkContactsAuth() {
        switch contactsAuth {
        case .notDetermined:
            CNContactStore().requestAccess(for: CNEntityType.contacts) { [weak self] (access, _) in
                guard let self = self else { return }
                if access {
                    Mixpanel.mainInstance().track(event: "ContactsAuthEnabled")
                    self.runNewAuthContactsFetch()
                }
            }
        case .denied, .restricted:
            // prompt user to open settings
            let alert = UIAlertController(title: "Allow contacts access to add friends", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Open settings", style: .default, handler: { _ in
                guard let settingsString = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(settingsString, options: [:], completionHandler: nil)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            DispatchQueue.main.async { self.present(alert, animated: true) }

        case.authorized:
            // this should never run
            Mixpanel.mainInstance().track(event: "ContactsAuthEnabled")
            runNewAuthContactsFetch()

        @unknown default: return
        }
    }

    @objc func inviteFriendsTap() {
        Mixpanel.mainInstance().track(event: "FindFriendsInviteFriendsTap")
        // will update with app store link when accepted
        guard let url = URL(string: "https://testflight.apple.com/join/ewgGbjkR") else { return }
        let items = [url, "Join the global chill and add me on sp0t 🌎🦦👯"] as [Any]
        let activityView = UIActivityViewController(activityItems: items, applicationActivities: nil)
        DispatchQueue.main.async { self.present(activityView, animated: true) }
        activityView.completionWithItemsHandler = { activityType, completed, _, _ in
            if completed {
                Mixpanel.mainInstance().track(event: "FindFriendsInviteSent", properties: ["type": activityType?.rawValue ?? ""])
            } else {
                Mixpanel.mainInstance().track(event: "FindFriendsInviteCancelled")
            }
        }
    }

    func openProfile(user: UserProfile) {
        let profileVC = ProfileViewController(userProfile: user, presentedDrawerView: containerDrawerView)
        DispatchQueue.main.async { self.navigationController?.pushViewController(profileVC, animated: true) }
    }

    @objc func notifyProfileAddFriend(_ sender: Notification) {
        guard let userInfo = sender.userInfo else { return }
        if let userID = userInfo["userID"] as? String {
            updateFriendStatus(id: userID)
        }
    }

    @objc func notifyFriendsLoad() {
        fetchTableData()
    }
}

extension FindFriendsController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return activeSearch ? 1 : contactsHidden ? 2 : 3
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let maxRowsSearch = UserDataModel.shared.screenSize == 0 ? 3 : UserDataModel.shared.screenSize == 1 ? 4 : 5
        if activeSearch { return min(maxRowsSearch, queryUsers.count) }
        let suggestedRows = min(5, suggestedUsers.count)

        switch section {
        case 0: return 1
        case 1: return contactsHidden ? suggestedRows : contactsAuth == .authorized ? contacts.count : 1
        case 2: return suggestedRows
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if !activeSearch {
            // return invite friends for section 0
            if indexPath.section == 0, let cell = tableView.dequeueReusableCell(withIdentifier: "InviteFriends", for: indexPath) as? InviteFriendsCell {
                cell.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(inviteFriendsTap)))
                return cell
            }
            // return search contacts if no contact access
            if indexPath.section == 1, contactsAuth != .authorized, let cell = tableView.dequeueReusableCell(withIdentifier: "SearchContacts", for: indexPath) as? SearchContactsCell {
                cell.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(searchContactsTap)))
                return cell
            }
        }
        
        // populate contact cell with search results or contacts/suggested users
        var dataSource: [(UserProfile, FriendStatus)] = []
        var cellType: ContactCell.CellType = .contact
        if activeSearch {
            dataSource = queryUsers
            cellType = .search
        } else if indexPath.section == 1 && !contactsHidden {
            dataSource = contacts
            cellType = .contact
        } else {
            dataSource = suggestedUsers
            cellType = .suggested
        }
        if let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCell") as? ContactCell {
            let user = dataSource[indexPath.row]
            cell.setUp(contact: user.0, friendStatus: user.1, cellType: cellType)
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "FindFriendsHeader") as? FindFriendsHeader {
            // suggested friends = 1, add contacts = 0
            header.type = tableView.numberOfSections == 2 ? 1 : section - 1
            return header
        }
        return UITableViewHeaderFooterView()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if !activeSearch && indexPath.section == 0 {
            // bigger cell for invite friends
            return 132
        } else if !activeSearch {
            // add spacing under final row in section
            if indexPath.row == 0 && indexPath.section == 1 && contactsAuth != .authorized {
                return 100
            } else {
                let dataSource = indexPath.section == 1 && !contactsHidden ? contacts : suggestedUsers
                if indexPath.row == dataSource.count - 1 {
                    return 100
                }
            }
        }
        // standard contact cell
        return 70
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // no header for search results + invite friends section
        return activeSearch ? 0 : section > 0 ? 36 : 0
    }
}

//
//  FindFriendsController.swift
//  Spot
//
//  Created by Kenny Barone on 3/28/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import CoreLocation
import Firebase
import FirebaseFirestore
import FirebaseAuth
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

    lazy var friendsLoaded = false
    lazy var activeSearch = false
    lazy var contacts: [(UserProfile, FriendStatus)] = []
    lazy var queryUsers: [(UserProfile, FriendStatus)] = []
    lazy var searchTextGlobal = ""

    lazy var searchBarContainer = UIView()
    lazy var searchBar: SpotSearchBar = {
        let searchBar = SpotSearchBar()
        searchBar.backgroundColor = UIColor(red: 0.175, green: 0.175, blue: 0.175, alpha: 1)
        searchBar.barTintColor = UIColor(red: 0.175, green: 0.175, blue: 0.175, alpha: 1)
        searchBar.searchTextField.backgroundColor = UIColor(red: 0.175, green: 0.175, blue: 0.175, alpha: 1)
        searchBar.layer.cornerRadius = 15
        searchBar.searchTextField.layer.cornerRadius = 15
        return searchBar
    }()
    lazy var cancelButton = TextCancelButton()
    lazy var searchIndicator = UIActivityIndicatorView()
    lazy var activityIndicator = UIActivityIndicatorView()

    lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.tag = 0
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.isScrollEnabled = true
        tableView.showsVerticalScrollIndicator = false
        tableView.register(ContactCell.self, forCellReuseIdentifier: "ContactCell")
        tableView.register(FindFriendsButtonCell.self, forCellReuseIdentifier: "ButtonCell")
        tableView.register(ContactsEmptyStateCell.self, forCellReuseIdentifier: "EmptyState")
        tableView.register(FindFriendsHeader.self, forHeaderFooterViewReuseIdentifier: "FindFriendsHeader")
        return tableView
    }()

    let dispatch = DispatchGroup()
    var authorizedOnInitialLoad = false

    var contactsHidden: Bool {
        // only hide if user has already allowed contacts access
        return authorizedOnInitialLoad && ContactsFetcher.shared.contactsAuth == .authorized && contacts.isEmpty
    }

    lazy var mapPostService: MapPostServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.mapPostService)
        return service
    }()

    lazy var userService: UserServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.userService)
        return service
    }()

    private lazy var friendService: FriendsServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.friendsService)
        return service
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "SpotBlack")

        NotificationCenter.default.addObserver(self, selector: #selector(notifyProfileAddFriend(_:)), name: NSNotification.Name("SendFriendRequest"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendsLoad), name: NSNotification.Name(("FriendsListLoad")), object: nil)

        friendsLoaded = UserDataModel.shared.friendsFetched
        authorizedOnInitialLoad = ContactsFetcher.shared.contactsAuth == .authorized

        loadSearchBar()
        loadTableView()
        fetchTableData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "FindFriendsOpen")
    }

    deinit {
        print("find friends deinit")
        NotificationCenter.default.removeObserver(self)
    }

    private func setUpNavBar() {
        navigationItem.title = "Find sp0tters"
        navigationController?.setUpDarkNav(translucent: false)
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
            string: "Search by username",
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
        searchIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
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
        activityIndicator.isHidden = true
        activityIndicator.snp.makeConstraints {
            $0.top.equalToSuperview().offset(180)
            $0.centerX.equalToSuperview()
            $0.height.width.equalTo(30)
        }
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
    }

    func updateFriendStatus(id: String) {
        if let i = contacts.firstIndex(where: { $0.0.id == id }) {
            contacts[i].1 = .pending
        }
        if let i = queryUsers.firstIndex(where: { $0.0.id == id }) {
            queryUsers[i].1 = .pending
        }
        DispatchQueue.main.async { self.tableView.reloadData() }
    }

    @objc func exit(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "FindFriendsExitTap")
        navigationController?.popViewController(animated: true)
    }

    @objc func searchCancelTap(_ sender: UIButton) {
        searchBar.resignFirstResponder()
    }

    @objc func searchContactsTap() {
        // ask for contacts access or open settings
        checkContactsAuth()
    }

    func checkContactsAuth() {
        switch ContactsFetcher.shared.contactsAuth {
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
        guard let url = URL(string: "https://apps.apple.com/app/id1477764252") else { return }
        let items = [url, "Add me on sp0t 🌎🦦"] as [Any]
        
        DispatchQueue.main.async {
            let activityView = UIActivityViewController(activityItems: items, applicationActivities: nil)
            self.present(activityView, animated: true)
            activityView.completionWithItemsHandler = { activityType, completed, _, _ in
                if completed {
                    Mixpanel.mainInstance().track(event: "FindFriendsInviteSent", properties: ["type": activityType?.rawValue ?? ""])
                } else {
                    Mixpanel.mainInstance().track(event: "FindFriendsInviteCancelled")
                }
            }
        }
    }

    @objc func notifyProfileAddFriend(_ sender: Notification) {
        guard let userInfo = sender.userInfo else { return }
        if let userID = userInfo["userID"] as? String {
            updateFriendStatus(id: userID)
        }
    }

    @objc func notifyFriendsLoad() {
        if !friendsLoaded {
            fetchTableData()
            friendsLoaded = true
        }
    }
}

extension FindFriendsController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return activeSearch || contactsHidden ? 1 : 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let maxRowsSearch = UserDataModel.shared.screenSize == 0 ? 3 : UserDataModel.shared.screenSize == 1 ? 4 : 5
        if activeSearch { return min(maxRowsSearch, queryUsers.count) }

        switch section {
        case 0: return 1
        case 1: return contactsHidden ? 1 : max(contacts.count, 1)
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if !activeSearch {
            // return invite friends for section 0
            if indexPath.section == 0, let cell = tableView.dequeueReusableCell(withIdentifier: "ButtonCell", for: indexPath) as? FindFriendsButtonCell {
                cell.setUp(type: .InviteFriends)
                cell.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(inviteFriendsTap)))
                return cell
            }
            // return search contacts if no contact access
            if indexPath.section == 1, ContactsFetcher.shared.contactsAuth != .authorized, let cell = tableView.dequeueReusableCell(withIdentifier: "ButtonCell", for: indexPath) as? FindFriendsButtonCell {
                cell.setUp(type: .SearchContacts)
                cell.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(searchContactsTap)))
                return cell
            }
            // show empty state after initial fetch
            if indexPath.section == 1, contacts.isEmpty, let cell = tableView.dequeueReusableCell(withIdentifier: "EmptyState") as? ContactsEmptyStateCell {
                return cell
            }
        }
        
        // populate contact cell with search results or contacts/suggested users
        var dataSource: [(UserProfile, FriendStatus)] = []
        var cellType: ContactCell.CellType = .contact
        if activeSearch {
            dataSource = queryUsers
            cellType = .search
        } else {
            dataSource = contacts
            cellType = .contact
        }

        if let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCell") as? ContactCell, let user = dataSource[safe: indexPath.row] {
            cell.setUp(contact: user.0, friendStatus: user.1, cellType: cellType)
            cell.delegate = self
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "FindFriendsHeader") as? FindFriendsHeader {
            header.type = 0
            return header
        }
        return UITableViewHeaderFooterView()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if !activeSearch && indexPath.section == 0 || (indexPath.section == 1 && ContactsFetcher.shared.contactsAuth != .authorized) {
            // bigger cell for invite friends + searchContacts
            return 114
        } else if indexPath.section == 1 && contacts.isEmpty {
            // empty state cell
            return 40
        }
        // standard contact cell
        return 70
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // no header for search results + invite friends section
        if activeSearch || activityIndicator.isAnimating {
            return 0
        } else if section > 0 {
            if section == 1 && ContactsFetcher.shared.contactsAuth != .authorized {
                // only show header when contacts button is not showing
                return 0
            }
            return 80
        }
        return 0
    }
}

extension FindFriendsController: ContactCellDelegate {
    func addFriend(user: UserProfile) {
        guard let userID = user.id else { return }
        updateFriendStatus(id: userID)
        friendService?.addFriend(receiverID: userID, completion: nil)
    }

    func removeSuggestion(user: UserProfile) {
        guard let userID = user.id else { return }
        contacts.removeAll(where: { $0.0.id == userID })
        DispatchQueue.main.async { self.tableView.reloadData() }

        friendService?.removeSuggestion(userID: userID)
    }

    func openProfile(user: UserProfile) {
        let profileVC = ProfileViewController(userProfile: user)
        DispatchQueue.main.async {
            self.searchBar.resignFirstResponder()
            self.navigationController?.pushViewController(profileVC, animated: true)
        }
    }
}

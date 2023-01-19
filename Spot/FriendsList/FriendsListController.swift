//
//  FriendsListController.swift
//  Spot
//
//  Created by Kenny Barone on 6/25/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import Mixpanel
import UIKit

protocol FriendsListDelegate: AnyObject {
    func finishPassing(selectedUsers: [UserProfile])
    func finishPassing(openProfile: UserProfile)
}

final class FriendsListController: UIViewController {
    private let allowsSelection: Bool
    private let showsSearchBar: Bool
    private var readyToDismiss = true
    private var queried = false

    private lazy var activityIndicator = CustomActivityIndicator()
    private lazy var userService: UserServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.userService)
        return service
    }()

    private lazy var doneButton: UIButton = {
        let button = UIButton()
        button.setTitle("Done", for: .normal)
        button.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 16)
        return button
    }()

    private lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "CancelButtonDark"), for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        return button
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
        label.textAlignment = .center
        return label
    }()

    private lazy var tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = nil
        view.separatorStyle = .none
        view.showsVerticalScrollIndicator = false
        view.separatorStyle = .none
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private(set) lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.tintColor = UIColor(red: 0.396, green: 0.396, blue: 0.396, alpha: 1)
        searchBar.searchTextField.backgroundColor = UIColor(red: 0.945, green: 0.945, blue: 0.949, alpha: 1)
        searchBar.searchTextField.leftView?.tintColor = UIColor(red: 0.396, green: 0.396, blue: 0.396, alpha: 1)
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.placeholder = " Search"
        searchBar.clipsToBounds = true
        searchBar.layer.cornerRadius = 3
        searchBar.keyboardDistanceFromTextField = 250
        return searchBar
    }()

    private var confirmedIDs: [String] /// users who cannot be unselected
    private var friendIDs: [String]
    private var friendsList: [UserProfile]
    private var queriedFriends: [UserProfile] = []

    private var searchPan: UIPanGestureRecognizer?
    weak var delegate: FriendsListDelegate?

    init(allowsSelection: Bool, showsSearchBar: Bool, friendIDs: [String], friendsList: [UserProfile], confirmedIDs: [String]) {
        self.allowsSelection = allowsSelection
        self.showsSearchBar = showsSearchBar
        self.friendIDs = friendIDs
        self.friendsList = friendsList
        self.queriedFriends = friendsList
        self.confirmedIDs = confirmedIDs
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if showsSearchBar { addSearchBar() }
        addTableView()
        if friendsList.isEmpty {
            DispatchQueue.main.async { self.activityIndicator.startAnimating() }
            DispatchQueue.global(qos: .userInitiated).async {
                self.getFriends()
            }
        }
        presentationController?.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "FriendsListOpen")
    }

    func addTableView() {
        view.backgroundColor = .white

        if allowsSelection {
            view.addSubview(doneButton)
            doneButton.addTarget(self, action: #selector(doneTap(_:)), for: .touchUpInside)
            doneButton.snp.makeConstraints {
                $0.trailing.equalToSuperview().inset(7)
                $0.top.equalTo(12)
                $0.width.equalTo(60)
                $0.height.equalTo(30)
            }
        }

        view.addSubview(cancelButton)
        cancelButton.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
        cancelButton.snp.makeConstraints {
            $0.leading.top.equalTo(7)
            $0.width.height.equalTo(40)
        }

        titleLabel.text = allowsSelection ? "Select friends" : "Friends list"
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(15)
            $0.width.equalTo(200)
            $0.centerX.equalToSuperview()
        }

        tableView.register(ChooseFriendsCell.self, forCellReuseIdentifier: "FriendsCell")
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            let topConstraint = showsSearchBar ? 115 : 60
            let inset = showsSearchBar ? 50 : 10
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(topConstraint)
            $0.height.equalToSuperview().inset(inset)
        }

        view.addSubview(activityIndicator)
        activityIndicator.isHidden = true
        activityIndicator.snp.makeConstraints {
            $0.top.equalTo(tableView).offset(15)
            $0.centerX.equalToSuperview()
            $0.height.width.equalTo(30)
        }
    }

    func addSearchBar() {
        view.addSubview(searchBar)
        searchBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.top.equalTo(60)
            $0.height.equalTo(36)
        }

        searchPan = UIPanGestureRecognizer(target: self, action: #selector(searchPan(_:)))
        searchPan?.delegate = self
        searchPan?.isEnabled = false
        view.addGestureRecognizer(searchPan ?? UIPanGestureRecognizer())
    }

    func getFriends() {
        print("get friends")
        let db: Firestore = Firestore.firestore()
        Task {
            for id in friendIDs {
                guard let user = try await userService?.getUserInfo(userID: id) else { continue }
                if user.username == "" { continue }
                self.friendsList.append(user)
            }
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.tableView.reloadData()
            }
        }
    }

    @objc func doneTap(_ sender: UIButton) {
        var selectedUsers: [UserProfile] = []
        for friend in friendsList where friend.selected { selectedUsers.append(friend) }
        delegate?.finishPassing(selectedUsers: selectedUsers)
        DispatchQueue.main.async { self.dismiss(animated: true) }
    }

    @objc func cancelTap(_ sender: UIButton) {
        DispatchQueue.main.async { self.dismiss(animated: true) }
    }

    @objc func searchPan(_ sender: UIPanGestureRecognizer) {
        /// remove keyboard on down swipe + vertical swipe > horizontal
        if abs(sender.translation(in: view).y) > abs(sender.translation(in: view).x) {
            searchBar.resignFirstResponder()
        }
    }
}

extension FriendsListController: UIGestureRecognizerDelegate, UIAdaptivePresentationControllerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {

        if gestureRecognizer.view == view, let gesture = gestureRecognizer as? UIPanGestureRecognizer {
            return shouldRecognize(searchPan: gesture)

        } else if otherGestureRecognizer.view == view, let gesture = gestureRecognizer as? UIPanGestureRecognizer {
            return shouldRecognize(searchPan: gesture)
        }

        return true
    }

    func shouldRecognize(searchPan: UIPanGestureRecognizer) -> Bool {
        /// down swipe with table not offset return true
        return tableView.contentOffset.y < 5 && searchPan.translation(in: view).y > 0
    }

    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        /// dont want to recognize swipe to dismiss with keyboard active
        return readyToDismiss
    }
}

extension FriendsListController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        queried = searchText != ""
        queriedFriends.removeAll()
        queriedFriends = getQueriedUsers(userList: friendsList, searchText: searchText)
        DispatchQueue.main.async { self.tableView.reloadData() }
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchPan?.isEnabled = true
        readyToDismiss = false
        queried = true
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchPan?.isEnabled = false
        // lag on ready to dismiss to avoid double tap to dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.readyToDismiss = true
        }
    }
}

extension FriendsListController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return queried ? queriedFriends.count : friendsList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "FriendsCell", for: indexPath) as? ChooseFriendsCell {
            let friend = queried ? queriedFriends[indexPath.row] : friendsList[indexPath.row]
            let editable = !confirmedIDs.contains(friend.id ?? "")
            cell.setUp(user: friend, allowsSelection: allowsSelection, editable: editable)
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 63
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let user = queried ? queriedFriends[indexPath.row] : friendsList[indexPath.row]
        let id = user.id ?? ""

        if allowsSelection {
            if confirmedIDs.contains(id) { return } /// cannot unselect confirmed ID
            Mixpanel.mainInstance().track(event: "FriendsListSelectFriend")
            if queried { if let i = queriedFriends.firstIndex(where: { $0.id == id }) { queriedFriends[i].selected = !queriedFriends[i].selected } }
            if let i = friendsList.firstIndex(where: { $0.id == id }) { friendsList[i].selected = !friendsList[i].selected }
            DispatchQueue.main.async { self.tableView.reloadData() }
            
        } else {
            DispatchQueue.main.async {
                self.delegate?.finishPassing(openProfile: user)
                self.dismiss(animated: true)
            }
        }
    }
}

extension FriendsListController {
    
    func getQueriedUsers(userList: [UserProfile], searchText: String) -> [UserProfile] {
        var queriedUsers: [UserProfile] = []
        let usernameList = userList.map({ $0.username })
        let nameList = userList.map({ $0.name })

        let filteredUsernames = searchText.isEmpty ? usernameList : usernameList.filter({(dataString: String) -> Bool in
            // If dataItem matches the searchText, return true to include it
            return dataString.range(of: searchText, options: [.anchored, .caseInsensitive]) != nil
        })

        let filteredNames = searchText.isEmpty ? nameList : nameList.filter({(dataString: String) -> Bool in
            return dataString.range(of: searchText, options: [.anchored, .caseInsensitive]) != nil
        })

        for username in filteredUsernames {
            if let user = userList.first(where: { $0.username == username }) { queriedUsers.append(user) }
        }

        for name in filteredNames {
            if let user = userList.first(where: { $0.name == name }) {
                if !queriedUsers.contains(where: { $0.id == user.id }) { queriedUsers.append(user) }
            }
        }
        return queriedUsers
    }
}

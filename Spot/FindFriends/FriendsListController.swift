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

protocol FriendsListDelegate {
    func finishPassing(selectedUsers: [UserProfile])
}

final class FriendsListController: UIViewController {

    let allowsSelection: Bool
    let showsSearchBar: Bool
    var readyToDismiss = true
    var queried = true

    var doneButton: UIButton?
    var cancelButton: UIButton!
    var titleLabel: UILabel!
    var tableView: UITableView!
    
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

    var confirmedIDs: [String] /// users who cannot be unselected
    var friendIDs: [String]
    var friendsList: [UserProfile]
    var queriedFriends: [UserProfile] = []

    private lazy var searchPan: UIPanGestureRecognizer = {
        let searchPan = UIPanGestureRecognizer(target: self, action: #selector(searchPan(_:)))
        searchPan.delegate = self
        searchPan.isEnabled = false
        
        return searchPan
    }()
    
    var delegate: FriendsListDelegate?

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
            doneButton = UIButton {
                $0.setTitle("Done", for: .normal)
                $0.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
                $0.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 16)
                $0.addTarget(self, action: #selector(doneTap(_:)), for: .touchUpInside)
                view.addSubview($0)
            }
            doneButton!.snp.makeConstraints {
                $0.trailing.equalToSuperview().inset(7)
                $0.top.equalTo(12)
                $0.width.equalTo(60)
                $0.height.equalTo(30)
            }
        }

        cancelButton = UIButton {
            $0.setImage(UIImage(named: "CancelButtonDark"), for: .normal)
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        cancelButton.snp.makeConstraints {
            $0.leading.top.equalTo(7)
            $0.width.height.equalTo(40)
        }

        titleLabel = UILabel {
            $0.text = allowsSelection ? "Select friends" : "Friends list"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
            $0.textAlignment = .center
            view.addSubview($0)
        }
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(15)
            $0.width.equalTo(200)
            $0.centerX.equalToSuperview()
        }

        tableView = UITableView {
            $0.backgroundColor = nil
            $0.separatorStyle = .none
            $0.dataSource = self
            $0.delegate = self
            $0.showsVerticalScrollIndicator = false
            $0.separatorStyle = .none
            $0.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
            $0.register(ChooseFriendsCell.self, forCellReuseIdentifier: "FriendsCell")
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        tableView.snp.makeConstraints {
            let topConstraint = showsSearchBar ? 115 : 60
            let inset = showsSearchBar ? 50 : 10
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(topConstraint)
            $0.height.equalToSuperview().inset(inset)
        }
    }

    func addSearchBar() {
        view.addSubview(searchBar)
        searchBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.top.equalTo(60)
            $0.height.equalTo(36)
        }

        view.addGestureRecognizer(searchPan)
    }

    func getFriends() {
        let db: Firestore = Firestore.firestore()
        let dispatch = DispatchGroup()
        for id in friendIDs {
            dispatch.enter()
            db.collection("users").document(id).getDocument { [weak self] snap, _ in
                do {
                    guard let self = self else { return }
                    let unwrappedInfo = try snap?.data(as: UserProfile.self)
                    guard let userInfo = unwrappedInfo else { dispatch.leave(); return }
                    self.friendsList.append(userInfo)
                    dispatch.leave()
                } catch {
                    dispatch.leave()
                }
            }
        }

        dispatch.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.tableView.reloadData()
        }
    }

    @objc func doneTap(_ sender: UIButton) {
        var selectedUsers: [UserProfile] = []
        for friend in friendsList { if friend.selected { selectedUsers.append(friend) }}
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
        searchPan.isEnabled = true
        readyToDismiss = false
        queried = true
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchPan.isEnabled = false
        /// lag on ready to dismiss to avoid double tap to dismiss
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
            let editable = !confirmedIDs.contains(friend.id!)
            cell.setUp(user: friend, allowsSelection: allowsSelection, editable: editable)
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 63
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let id = queried ? queriedFriends[indexPath.row].id ?? "" : friendsList[indexPath.row].id ?? ""
        
        /// cannot unselect confirmed ID
        if id.isEmpty || confirmedIDs.contains(id) {
            return
        }

        Mixpanel.mainInstance().track(event: "FriendsListSelectFriend")
        if queried { if let i = queriedFriends.firstIndex(where: { $0.id == id }) { queriedFriends[i].selected = !queriedFriends[i].selected } }
        if let i = friendsList.firstIndex(where: { $0.id == id }) { friendsList[i].selected = !friendsList[i].selected }
        DispatchQueue.main.async { self.tableView.reloadData() }
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

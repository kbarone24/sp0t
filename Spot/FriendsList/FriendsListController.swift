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
    let allowsSelection: Bool
    let showsSearchBar: Bool
    var readyToDismiss = true
    var queried = false
    var canAddFriends = false

    lazy var activityIndicator = UIActivityIndicatorView()
    lazy var userService: UserServiceProtocol? = {
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
        button.setImage(UIImage(named: "CancelButtonWhite"), for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        return button
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "SFCompactText-Heavy", size: 19)
        label.textAlignment = .center
        return label
    }()

    lazy var tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = nil
        view.separatorStyle = .none
        view.showsVerticalScrollIndicator = false
        view.separatorStyle = .none
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private(set) lazy var searchBar: SpotSearchBar = {
        let searchBar = SpotSearchBar()
        searchBar.delegate = self
        searchBar.placeholder = " Search"
        return searchBar
    }()

    var confirmedIDs: [String] /// users who cannot be unselected
    var friendIDs: [String]
    var friendsList: [UserProfile]
    var queriedFriends: [UserProfile] = []

    var searchPan: UIPanGestureRecognizer?
    weak var delegate: FriendsListDelegate?
    var endUserPosition: Int = 0
    lazy var refresh: RefreshStatus = .refreshDisabled

    enum ParentVC: Int {
        case profile = 0
        case mapMembers = 1
        case mapAdd = 2
        case newMap = 3
    }
    var parentVC: ParentVC

    init(parentVC: ParentVC, allowsSelection: Bool, showsSearchBar: Bool, canAddFriends: Bool, friendIDs: [String], friendsList: [UserProfile], confirmedIDs: [String]) {
        self.parentVC = parentVC
        self.allowsSelection = allowsSelection
        self.showsSearchBar = showsSearchBar
        self.canAddFriends = canAddFriends
        self.friendIDs = friendIDs
        self.friendsList = friendsList
        self.queriedFriends = friendsList
        self.confirmedIDs = confirmedIDs
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        print("friends list deinit")
        NotificationCenter.default.removeObserver(self)
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
        NotificationCenter.default.addObserver(self, selector: #selector(notifyAddFriend), name: NSNotification.Name("SendFriendRequest"), object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "FriendsListOpen")
    }

    func addTableView() {
        view.backgroundColor = UIColor(named: "SpotBlack")

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

        switch parentVC {
        case .profile: titleLabel.text = "Friends"
        case .newMap: titleLabel.text = "Select friends"
        case .mapAdd: titleLabel.text = "Add friends"
        case .mapMembers: titleLabel.text = "Joined"
        }
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(15)
            $0.width.equalTo(200)
            $0.centerX.equalToSuperview()
        }

        tableView.register(ChooseFriendsCell.self, forCellReuseIdentifier: "FriendsCell")
        tableView.register(ActivityIndicatorCell.self, forCellReuseIdentifier: "IndicatorCell")
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
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
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

    @objc func notifyAddFriend(_ sender: NSNotification) {
        // user data model will automatically update
        if let receiverID = sender.userInfo?.first?.value as? String {
            UserDataModel.shared.userInfo.pendingFriendRequests.append(receiverID)
            DispatchQueue.main.async { self.tableView.reloadData() }
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

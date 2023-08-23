//
//  ProfileViewController.swift
//  Spot
//
//  Created by Kenny Barone on 8/10/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Combine
import Mixpanel

class ProfileViewController: UIViewController {
    typealias Input = ProfileViewModel.Input
    typealias Output = ProfileViewModel.Output
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UITableViewDiffableDataSource<Section, Item>

    enum Section: Hashable {
        case overview
        case timeline
    }

    enum Item: Hashable {
        case profileHeader(profile: UserProfile)
        case post(post: MapPost)
    }

    let viewModel: ProfileViewModel
    private var subscriptions = Set<AnyCancellable>()

    let refresh = PassthroughSubject<Bool, Never>()
    let commentPaginationForced = PassthroughSubject<((MapPost?, DocumentSnapshot?)), Never>()


    // TODO: configure
    private(set) lazy var datasource: DataSource = {
        let dataSource = DataSource(tableView: tableView) { [weak self] tableView, indexPath, item in
            switch item {
            case .profileHeader(profile: let profile):
                let cell = tableView.dequeueReusableCell(withIdentifier: ProfileOverviewCell.reuseID, for: indexPath) as? ProfileOverviewCell
                cell?.configure(userInfo: profile)
                cell?.delegate = self
                return cell ?? UITableViewCell()

            case .post(post: let post):
                let cell = tableView.dequeueReusableCell(withIdentifier: SpotPostCell.reuseID, for: indexPath) as? SpotPostCell
                cell?.configure(post: post, parent: .Profile)
                cell?.delegate = self
                return cell
            }
        }
        return dataSource
    }()

    private(set) lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = UIScreen.main.bounds.height / 2
        tableView.backgroundColor = SpotColors.HeaderGray.color
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        tableView.clipsToBounds = true
        tableView.register(ProfileOverviewCell.self, forCellReuseIdentifier: ProfileOverviewCell.reuseID)
        tableView.register(SpotPostCell.self, forCellReuseIdentifier: SpotPostCell.reuseID)
        return tableView
    }()

    private lazy var activityIndicator = UIActivityIndicatorView()

    var isRefreshingPagination = false {
        didSet {
            DispatchQueue.main.async {
                if self.isRefreshingPagination, !self.datasource.snapshot().itemIdentifiers.isEmpty {
                    self.tableView.layoutIfNeeded()
                    let tableBottom = self.tableView.contentSize.height
                    self.activityIndicator.snp.removeConstraints()
                    self.activityIndicator.snp.makeConstraints {
                        $0.centerX.equalToSuperview()
                        $0.width.height.equalTo(30)
                        $0.top.equalTo(tableBottom + 15)
                    }
                    self.activityIndicator.startAnimating()
                }
            }
        }
    }

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        edgesForExtendedLayout = []
    }

    deinit {
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "ProfileAppeared")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SpotColors.HeaderGray.color

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        tableView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(100)
        }
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        activityIndicator.color = .white
        activityIndicator.startAnimating()

        let input = Input(refresh: refresh, commentPaginationForced: commentPaginationForced)

        let output = viewModel.bind(to: input)
        output.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.datasource.apply(snapshot, animatingDifferences: false)
                self?.activityIndicator.stopAnimating()
                self?.isRefreshingPagination = false
                self?.setRightBarButton()
            }
            .store(in: &subscriptions)

        refresh.send(true)
        commentPaginationForced.send((nil, nil))

        NotificationCenter.default.addObserver(self, selector: #selector(userProfileLoad), name: NSNotification.Name("FriendsListLoad"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(postDelete(_:)), name: NSNotification.Name("PostDelete"), object: nil)
    }

    @objc func userProfileLoad() {
        guard viewModel.cachedProfile.id ?? "" == UserDataModel.shared.uid else { return }
        if !UserDataModel.shared.friendsFetched {
            viewModel.cachedProfile = UserDataModel.shared.userInfo
            refresh.send(true)
        }
    }

    @objc func postDelete(_ notification: Notification) {
        // called on passback from spot + this is the main delete function for profile delete
        if let postID = notification.userInfo?["postID"] as? String, let parentPostID = notification.userInfo?["parentPostID"] as? String {
            viewModel.deletePostLocally(postID: postID, parentPostID: parentPostID)
            refresh.send(false)
        }
    }

    private func setUpNavBar() {
        navigationController?.setUpOpaqueNav(backgroundColor: SpotColors.HeaderGray.color)
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: SpotFonts.UniversCE.fontWith(size: 20)
        ]
        navigationItem.title = ""
    }

    private func setRightBarButton() {
        if viewModel.cachedProfile.friendStatus != .activeUser {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "WhiteMoreButton"), style: .plain, target: self, action: #selector(moreTap))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func moreTap() {
        addOptionsActionSheet()
    }
}

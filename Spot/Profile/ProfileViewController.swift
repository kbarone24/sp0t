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
        tableView.backgroundColor = UIColor(red: 0.106, green: 0.106, blue: 0.106, alpha: 1)
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
        view.backgroundColor = UIColor(red: 0.106, green: 0.106, blue: 0.106, alpha: 1)

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
    }

    @objc func userProfileLoad() {
        guard viewModel.cachedProfile.id ?? "" == UserDataModel.shared.uid else { return }
        if !UserDataModel.shared.friendsFetched {
            viewModel.cachedProfile = UserDataModel.shared.userInfo
            refresh.send(true)
        }
    }

    private func setUpNavBar() {
        navigationController?.setUpOpaqueNav(backgroundColor: UIColor(red: 0.106, green: 0.106, blue: 0.106, alpha: 1))
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: SpotFonts.UniversCE.fontWith(size: 20)
        ]
        navigationItem.title = ""
    }

    private func setRightBarButton() {
        if viewModel.cachedProfile.friendStatus != .activeUser {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "HorizontalMoreButton"), style: .plain, target: self, action: #selector(moreTap))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func moreTap() {
        addOptionsActionSheet()
    }
}

extension ProfileViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let snapshot = datasource.snapshot()
        if (indexPath.row >= snapshot.numberOfItems - 2) && !isRefreshingPagination, !viewModel.disablePagination {
            Mixpanel.mainInstance().track(event: "ProfilePaginationTriggered")
            isRefreshingPagination = true
            refresh.send(true)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        DispatchQueue.main.async {
            self.navigationItem.title = scrollView.contentOffset.y > 60 ? self.viewModel.cachedProfile.username : ""
        }
    }
}

extension ProfileViewController: PostCellDelegate {
    //TODO: spot name tap opens spot
    func likePost(post: MapPost) {
        viewModel.likePost(post: post)
        refresh.send(false)
    }

    func unlikePost(post: MapPost) {
        viewModel.unlikePost(post: post)
        refresh.send(false)
    }

    func dislikePost(post: MapPost) {
        viewModel.dislikePost(post: post)
        refresh.send(false)
    }

    func undislikePost(post: MapPost) {
        viewModel.undislikePost(post: post)
        refresh.send(false)
    }

    func viewMoreTap(parentPostID: String) {
        if let post = viewModel.presentedPosts.first(where: { $0.id == parentPostID }) {
            refresh.send(true)
            commentPaginationForced.send((post, post.lastCommentDocument))
        }
    }

    func moreButtonTap(post: MapPost) {
       // more button action removed on profile
    }

    func replyTap(parentPostID: String, parentPosterID: String, replyToID: String, replyToUsername: String?) {
        // reply action removed on profile
    }

    func profileTap(userInfo: UserProfile) {
        guard userInfo.id ?? "" != viewModel.cachedProfile.id ?? "" else { return }
        let vc = ProfileViewController(viewModel: ProfileViewModel(serviceContainer: ServiceContainer.shared, profile: userInfo))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    func spotTap(post: MapPost) {
        let spot = MapSpot(id: post.spotID ?? "", spotName: post.spotName ?? "")
        let vc = SpotController(viewModel: SpotViewModel(serviceContainer: ServiceContainer.shared, spot: spot))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension ProfileViewController: ProfileOverviewDelegate {
    func addFriend() {
        viewModel.addFriend()
        refresh.send(false)
    }

    func showPendingActionSheet() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Remove friend request", style: .destructive) { (_) in
            self.viewModel.removeFriendRequest()
            self.refresh.send(false)
        })
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        present(alert, animated: true)

    }

    func showRemoveActionSheet() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Remove friend", style: .destructive) { (_) in
            self.showRemoveFriendAlert()
        })
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        present(alert, animated: true)
    }

    func showUnblockActionSheet() {
        showUnblockUserAlert()
    }

    func openEditProfile() {
        let editVC = EditProfileViewController(userProfile: UserDataModel.shared.userInfo)
        editVC.delegate = self
        let nav = UINavigationController(rootViewController: editVC)
        nav.modalPresentationStyle = .fullScreen
        DispatchQueue.main.async {
            self.present(nav, animated: true)
        }
    }

    func inviteFriends() {
        guard let url = URL(string: "https://apps.apple.com/app/id1477764252") else { return }
        let items = [url, "Add me on sp0t 🌎🦦"] as [Any]

        let activityView = UIActivityViewController(activityItems: items, applicationActivities: nil)
            present(activityView, animated: true)
            activityView.completionWithItemsHandler = { activityType, completed, _, _ in
                if completed {
                    Mixpanel.mainInstance().track(event: "ProfileInviteSent", properties: ["type": activityType?.rawValue ?? ""])
                } else {
                    Mixpanel.mainInstance().track(event: "ProfileInviteCancelled")
                }
            }
        }

    func acceptFriendRequest() {
        viewModel.acceptFriendRequest()
        refresh.send(false)
    }

    func avatarTap() {
        guard viewModel.cachedProfile.friendStatus == .activeUser else { return }
        let vc = SpotscoreController(spotscore: UserDataModel.shared.userInfo.spotScore ?? 0)
        vc.delegate = self
        DispatchQueue.main.async {
            self.present(vc, animated: true)
        }

        viewModel.setNewAvatarSeen()
        refresh.send(false)
    }

    private func openAvatarSelection() {
        let vc = AvatarSelectionController(sentFrom: .spotscore, family: AvatarFamily(rawValue: viewModel.cachedProfile.avatarFamily ?? ""))
        vc.delegate = self
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension ProfileViewController: EditProfileDelegate {
    func finishPassing(userInfo: UserProfile, passedAvatarProfile: AvatarProfile?) {
        viewModel.cachedProfile = userInfo
        if let passedAvatarProfile {
            // update avatar if user changed it
            viewModel.updateUserAvatar(avatar: passedAvatarProfile)
        }

        refresh.send(false)
    }
}

extension ProfileViewController: AvatarSelectionDelegate {
    func finishPassing(avatar: AvatarProfile) {
        viewModel.updateUserAvatar(avatar: avatar)
        refresh.send(false)
    }
}

extension ProfileViewController: SpotscoreDelegate {
    func openEditAvatar(family: AvatarFamily?) {
        let vc = AvatarSelectionController(sentFrom: .edit, family: nil)
        vc.delegate = self
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: false)
        }
    }
}

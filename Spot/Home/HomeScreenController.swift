//
//  HomeScreenController.swift
//  Spot
//
//  Created by Kenny Barone on 7/6/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Combine
import Mixpanel
import CoreLocation
import GeoFireUtils

class HomeScreenController: UIViewController {
    enum SectionType {
        case Hot
        case Nearby
    }

    enum Section: Hashable {
        case pops
        case top
        case nearby
    }

    enum Item: Hashable {
        case item(spot: Spot)
        case group(pops: [Spot])
    }

    typealias Input = HomeScreenViewModel.Input
    typealias Output = HomeScreenViewModel.Output
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UITableViewDiffableDataSource<Section, Item>

    let viewModel: HomeScreenViewModel
    var subscriptions = Set<AnyCancellable>()

    let refresh = PassthroughSubject<Bool, Never>()

    private lazy var popSwipeGesture: UISwipeGestureRecognizer = {
        let gesture = UISwipeGestureRecognizer(target: self, action: #selector(swipeRight))
        gesture.direction = .right
        gesture.isEnabled = false
        return gesture
    }()

    private(set) lazy var datasource: DataSource = {
        let dataSource = DataSource(tableView: tableView) { [weak self] tableView, indexPath, item in
            guard let section = self?.datasource.snapshot().sectionIdentifiers[indexPath.section] else { return UITableViewCell() }
            switch item {
            case .item(spot: let spot):
                switch section {
                case .nearby, .top:
                    let cell = tableView.dequeueReusableCell(withIdentifier: HomeScreenSpotCell.reuseID, for: indexPath) as? HomeScreenSpotCell
                    cell?.configure(spot: spot)
                    return cell
                default:
                    return nil
                }
            case .group(pops: let pops):
                switch section {
                case .pops:
                    let cell = tableView.dequeueReusableCell(withIdentifier: HomeScreenPopCollectionCell.reuseID, for: indexPath) as? HomeScreenPopCollectionCell
                    cell?.configure(pops: pops, offset: self?.popsCollectionOffset ?? .zero)
                    cell?.delegate = self
                    return cell
                default:
                    return nil
                }
            }
        }
        return dataSource
    }()

    private lazy var popsCollectionOffset: CGPoint = .zero

    private lazy var backgroundImage: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "HomeScreenBackground"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private(set) lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.estimatedRowHeight = 130
        tableView.backgroundColor = nil
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 50, right: 0)
        tableView.clipsToBounds = true
        tableView.automaticallyAdjustsScrollIndicatorInsets = true
        tableView.register(HomeScreenSpotCell.self, forCellReuseIdentifier: HomeScreenSpotCell.reuseID)
        tableView.register(HomeScreenPopCollectionCell.self, forCellReuseIdentifier: HomeScreenPopCollectionCell.reuseID)
        tableView.register(HomeScreenTableHeader.self, forHeaderFooterViewReuseIdentifier: HomeScreenTableHeader.reuseID)
        return tableView
    }()

    private lazy var footerView: HomeScreenTableFooter = {
        let view = HomeScreenTableFooter()
        view.isHidden = true
        view.shareButton.addTarget(self, action: #selector(shareTap), for: .touchUpInside)
        view.refreshButton.addTarget(self, action: #selector(refreshTap), for: .touchUpInside)
        view.inboxButton.addTarget(self, action: #selector(inboxTap), for: .touchUpInside)
        return view
    }()

    private lazy var popCoverPage = HomeScreenPopCoverPage()
    private lazy var emptyState = HomeScreenEmptyState()
    private lazy var flaggedState = HomeScreenFlaggedUserState()

    private lazy var missedItPopUp = HomeMissedItPopUp()

    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .white
        refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)
        return refreshControl
    }()

    private lazy var activityIndicator = UIActivityIndicatorView()

    private var isRefreshing = false {
        didSet {
            DispatchQueue.main.async {
                if self.isRefreshing {
                    guard self.activityIndicator.superview != nil else { return }
                    self.activityIndicator.snp.removeConstraints()
                    self.view.bringSubviewToFront(self.activityIndicator)
                    self.activityIndicator.snp.makeConstraints {
                        $0.centerX.equalToSuperview()

                        if self.tapToRefresh {
                            $0.bottom.equalTo(self.footerView.snp.top).offset(30)
                        } else {
                            $0.top.equalTo(60)
                        }
                    }

                    self.activityIndicator.startAnimating()

                } else {
                    self.activityIndicator.stopAnimating()
                }
            }
        }
    }

    private var tapToRefresh = false

    private lazy var titleView: HomeScreenTitleView = {
        let view = HomeScreenTitleView()
        view.searchButton.addTarget(self, action: #selector(searchTap), for: .touchUpInside)
        view.profileButton.shadowButton.addTarget(self, action: #selector(profileTap), for: .touchUpInside)
        view.notificationsButton.addTarget(self, action: #selector(notificationsTap), for: .touchUpInside)
        return view
    }()


    init(viewModel: HomeScreenViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        addNotifications()

        view.backgroundColor = .white
        edgesForExtendedLayout = []
    }

    deinit {
        print("home screen deinit")
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // fetch user data
        checkLocationAuth()
        UserDataModel.shared.addListeners()
        subscribeToNotiListener()
        subscribeToChatListener()
        subscribeToPopListener()

        view.addSubview(backgroundImage)
        backgroundImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        // setup view
        tableView.refreshControl = refreshControl
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.leading.bottom.trailing.top.equalToSuperview()
        }

        view.addSubview(emptyState)
        emptyState.isHidden = true
        emptyState.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        view.addSubview(flaggedState)
        flaggedState.isHidden = true
        flaggedState.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        view.addSubview(footerView)
        footerView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(150)
        }

        tableView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(60)
        }
        activityIndicator.color = .white
        activityIndicator.transform = CGAffineTransform(scaleX: 1.75, y: 1.75)
        activityIndicator.startAnimating()

        view.addGestureRecognizer(popSwipeGesture)

        let input = Input(
            refresh: refresh
        )

        let output = viewModel.bind(to: input)
        output.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                var snapshot = snapshot
                self?.tableView.invalidateIntrinsicContentSize()
                self?.refreshControl.endRefreshing()
                self?.activityIndicator.stopAnimating()
                self?.isRefreshing = false
                self?.footerView.isHidden = false

                if snapshot.sectionIdentifiers.contains(.pops) {
                    // manually reload so pops collection updates on non-comparable changes
                    let pops = snapshot.itemIdentifiers(inSection: .pops)
                    snapshot.reloadItems(pops)

                    if let pop = pops.first {
                        // show pop cover page if there's an upcoming pop
                        switch pop {
                        case .group(pops: let pops):
                            if let pop = pops.first, !pop.popIsExpired {
                                self?.addPopCoverPage(pop: pop)
                            }
                        default:
                            break
                        }
                    }
                } else {
                    self?.popSwipeGesture.isEnabled = false
                    self?.popCoverPage.removeFromSuperview()
                }

                self?.datasource.apply(snapshot, animatingDifferences: false)

                if UserDataModel.shared.userInfo.flagged {
                    self?.addFlaggedState()
                }

                if snapshot.itemIdentifiers.isEmpty {
                    self?.addEmptyState()
                } else {
                    self?.emptyState.isHidden = true
                }

                // scroll to first row on forced refresh
                if self?.tapToRefresh ?? false {
                    self?.tapToRefresh = false
                    if !snapshot.itemIdentifiers.isEmpty {
                        self?.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
                    }
                }
            }
            .store(in: &subscriptions)

        if viewModel.locationService.gotInitialLocation {
            // otherwise refresh sent by internal noti
            refresh.send(true)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "HomeScreenAppeared")

        if !datasource.snapshot().itemIdentifiers.isEmpty {
            refreshLocation()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layoutIfNeeded()
      //  addGradient()
    }

    private func addNotifications() {
        // deep link notis sent from SceneDelegate
        NotificationCenter.default.addObserver(self, selector: #selector(gotUserLocation), name: NSNotification.Name("UpdatedLocationAuth"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(gotNotification(_:)), name: NSNotification.Name("IncomingNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyLogout), name: NSNotification.Name("Logout"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(popTimesUp), name: NSNotification.Name("PopTimesUp"), object: nil)
    }

    private func setUpNavBar() {
        navigationController?.setUpOpaqueNav(backgroundColor: UIColor(hexString: "70B7FF"))
        navigationItem.titleView = titleView
    }

    private func addPopCoverPage(pop: Spot) {
        guard popCoverPage.superview == nil, !popCoverPage.wasDismissed else {
            // update visitor count only
            popCoverPage.setVisitors(pop: pop)
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return
        }

        // set frame in case window hasnt laid out subviews
        window.addSubview(popCoverPage)
        popCoverPage.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        popCoverPage.isHidden = false
        popCoverPage.configure(pop: pop, delegate: self)

        // user is considered a visitor once they enter the cover page
        viewModel.addUserToPopVisitors(pop: pop)
    }

    private func addEmptyState() {
        guard let locationService = try? ServiceContainer.shared.service(for: \.locationService) else { return }
        guard locationService.currentLocationStatus() != .notDetermined else {
            // actively asking user for location
            return
        }

        emptyState.isHidden = false
        if locationService.currentLocationStatus() != .authorizedWhenInUse {
            emptyState.configureNoAccess()
        } else {
            emptyState.configureNoPosts()
        }
    }

    private func addFlaggedState() {
        titleView.isUserInteractionEnabled = false
        flaggedState.isHidden = false
    }

    private func subscribeToNotiListener() {
        let request = Firestore.firestore()
            .collection(FirebaseCollectionNames.users.rawValue)
            .document(UserDataModel.shared.uid)
            .collection(FirebaseCollectionNames.notifications.rawValue)
            .whereField(FirebaseCollectionFields.seen.rawValue, isEqualTo: false)

        request.snapshotPublisher(includeMetadataChanges: true)
            .removeDuplicates()
            .receive(on: DispatchQueue.global(qos: .background))
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] completion in
                    guard let self,
                          !completion.metadata.isFromCache
                    else { return }

                    var docCount = 0
                    //TODO: remove temporary function: check that notification is friend request or has a spot attached to it, remove noti from old version if not
                    for doc in completion.documents {
                        guard let noti = try? doc.data(as: UserNotification.self) else { continue }
                        if noti.spotID ?? "" != "" || noti.type == NotificationType.friendRequest.rawValue || noti.type == NotificationType.contactJoin.rawValue {
                            docCount += 1
                        } else {
                            self.viewModel.removeDeprecatedNotification(notiID: noti.id ?? "")
                        }
                    }
                    DispatchQueue.main.async {
                        self.titleView.notificationsButton.pendingCount = docCount
                        self.navigationItem.titleView = self.titleView
                    }
                })
            .store(in: &subscriptions)
    }

    private func subscribeToChatListener() {
        let request = Firestore.firestore()
            .collection(FirebaseCollectionNames.botChat.rawValue)
            .whereField(BotChatCollectionFields.userID.rawValue, isEqualTo: UserDataModel.shared.uid)
            .whereField(BotChatCollectionFields.seenByUser.rawValue, isEqualTo: false)

        request.snapshotPublisher(includeMetadataChanges: true)
            .removeDuplicates()
            .receive(on: DispatchQueue.global(qos: .background))
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] completion in
                    guard let self,
                          !completion.metadata.isFromCache
                    else { return }

                    var docCount = 0
                    for doc in completion.documents {
                        guard (try? doc.data(as: BotChatMessage.self)) != nil else { continue }
                        docCount += 1
                    }
                    DispatchQueue.main.async {
                        self.footerView.inboxButton.hasUnseenNoti = docCount > 0
                    }

                })
            .store(in: &subscriptions)
    }

    private func subscribeToPopListener() {
        // dynamically update visitor list as users join
        let request = Firestore.firestore().collection(FirebaseCollectionNames.pops.rawValue)
            .order(by: PopCollectionFields.endTimestamp.rawValue, descending: true)
            .whereField(PopCollectionFields.endTimestamp.rawValue, isGreaterThanOrEqualTo: Timestamp())
        request.snapshotPublisher(includeMetadataChanges: true)
            .removeDuplicates()
            .receive(on: DispatchQueue.global(qos: .background))
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] completion in
                    print("receive value")
                    guard let self,
                          !completion.metadata.isFromCache,
                          !completion.documentChanges.isEmpty,
                          !viewModel.cachedPops.isEmpty
                    else { return }
                    print("send refresh")
                    refresh.send(true)
                })
            .store(in: &subscriptions)
    }

    @objc func searchTap() {
        Mixpanel.mainInstance().track(event: "HomeScreenSearchTap")
        let vc = SearchController(viewModel: SearchViewModel(serviceContainer: ServiceContainer.shared))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc func profileTap() {
        Mixpanel.mainInstance().track(event: "HomeScreenProfileTap")
        let vc = ProfileViewController(viewModel: ProfileViewModel(serviceContainer: ServiceContainer.shared, profile: UserDataModel.shared.userInfo))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc func notificationsTap() {
        Mixpanel.mainInstance().track(event: "HomeScreenNotificationsTap")
        openNotifications()
    }

    func openNotifications() {
        let vc = NotificationsViewController(viewModel: NotificationsViewModel(serviceContainer: ServiceContainer.shared))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension HomeScreenController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !datasource.snapshot().sectionIdentifiers.isEmpty else { return UIView() }
        let section = datasource.snapshot().sectionIdentifiers[section]
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: HomeScreenTableHeader.reuseID) as? HomeScreenTableHeader
        header?.configure(headerType: section)
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard !datasource.snapshot().sectionIdentifiers.isEmpty else { return 0 }
        return 34
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard !datasource.snapshot().sectionIdentifiers.isEmpty else { return 0 }
        let section = datasource.snapshot().sectionIdentifiers[indexPath.section]
        switch section {
        case .top, .nearby:
            return 130
        case .pops:
            return 220
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = datasource.snapshot().sectionIdentifiers[indexPath.section]
        let item = datasource.snapshot().itemIdentifiers(inSection: section)[indexPath.item]
        switch item {
        case .item(spot: let spot):
            switch section {
            case .top:
                Mixpanel.mainInstance().track(event: "HomeScreenHotSpotTap")
                openSpot(spot: spot, postID: nil, commentID: nil)
                viewModel.setSeenLocally(spot: spot)
                refresh.send(false)

            case .nearby:
                Mixpanel.mainInstance().track(event: "HomeScreenNearbySpotTap")
                openSpot(spot: spot, postID: nil, commentID: nil)
                viewModel.setSeenLocally(spot: spot)
                refresh.send(false)

            default:
                return
            }
        default:
            return
        }
    }

    func openSpot(spot: Spot, postID: String?, commentID: String?) {
        let vc = SpotController(viewModel: SpotViewModel(serviceContainer: ServiceContainer.shared, spot: spot, passedPostID: postID, passedCommentID: commentID))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    func openPop(pop: Spot, postID: String?, commentID: String?) {
        let sortMethod: PopViewModel.SortMethod = pop.popIsActive ? .New : .Hot
        let vc = PopController(viewModel: PopViewModel(serviceContainer: ServiceContainer.shared, pop: pop, passedPostID: nil, passedCommentID: nil, sortMethod: sortMethod))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc func forceRefresh() {
        Mixpanel.mainInstance().track(event: "HomeScreenPullToRefresh")
        HapticGenerator.shared.play(.soft)
        refresh.send(true)
        // using refresh indicator rather than activity so dont set isRefreshing here

        DispatchQueue.main.async {
            self.refreshControl.beginRefreshing()
        }
    }

    @objc func shareTap() {
        openInviteActivityView()
    }

    @objc func refreshTap() {
        Mixpanel.mainInstance().track(event: "HomeScreenRefreshTap")
        HapticGenerator.shared.play(.soft)
        tapToRefresh = true
        isRefreshing = true
        refresh.send(true)
    }

    @objc func inboxTap() {
        Mixpanel.mainInstance().track(event: "HomeScreenInboxTap")
        let vc = BotChatController(viewModel: BotChatViewModel(serviceContainer: ServiceContainer.shared))
        DispatchQueue.main.async {
            self.present(vc, animated: true)
        }
    }

    @objc func swipeRight() {
        guard popCoverPage.superview != nil, popCoverPage.wasDismissed else {
            return
        }
        UIView.animate(withDuration: 0.35, animations: {
            self.popCoverPage.transform = CGAffineTransform(translationX: 0, y: 0)
        }) { [weak self] _ in
            self?.popCoverPage.wasDismissed = false
        }
    }

    // called on view appear / when user updates location auth
    func refreshLocation() {
        isRefreshing = true
        refresh.send(true)
    }

    private func openInviteActivityView() {
        guard let url = URL(string: "https://apps.apple.com/app/id1477764252") else { return }
        let items = [url, "download sp0t 🫵‼️🔥"] as [Any]

        let activityView = UIActivityViewController(activityItems: items, applicationActivities: nil)
        self.present(activityView, animated: true)
        activityView.completionWithItemsHandler = { activityType, completed, _, _ in
            if completed {
                Mixpanel.mainInstance().track(event: "HomeScreenInviteSent", properties: ["type": activityType?.rawValue ?? ""])
            } else {
                Mixpanel.mainInstance().track(event: "HomeScreenInviteCancelled")
            }
        }
    }
}

extension HomeScreenController: PopCoverDelegate {
    func inviteTap() {
        openInviteActivityView()
    }

    func joinTap(pop: Spot) {
        openPop(pop: pop, postID: "", commentID: "")
    }

    func swipeGesture() {
        // popCoverPage.removeFromSuperview()
        popSwipeGesture.isEnabled = true
    }
}

extension HomeScreenController: PopCollectionCellDelegate {
    func open(pop: Spot) {
        Mixpanel.mainInstance().track(event: "HomeScreenPopTap")
        if pop.popIsActive || (pop.userHasPopAccess && pop.popHasStarted) {
            openPop(pop: pop, postID: nil, commentID: nil)
        }
    }

    func cacheContentOffset(offset: CGPoint) {
        self.popsCollectionOffset = offset
    }

    private func showMissedItPopUp() {
        // currently not used
        guard missedItPopUp.isHidden else { return }
        missedItPopUp.isHidden = false
        missedItPopUp.alpha = 1.0
        UIView.animate(withDuration: 0.3, delay: 2.0, animations: {
            self.missedItPopUp.alpha = 0.0
        }) { [weak self] _ in
            self?.missedItPopUp.isHidden = true
        }
    }
}

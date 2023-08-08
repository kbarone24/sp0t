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

class HomeScreenController: UIViewController {
    enum SectionType {
        case Hot
        case Nearby
    }

    enum Section: Hashable {
        case top(title: String)
        case nearby(title: String)
    }

    enum Item: Hashable {
        case item(spot: MapSpot)
    }

    typealias Input = HomeScreenViewModel.Input
    typealias Output = HomeScreenViewModel.Output
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UITableViewDiffableDataSource<Section, Item>

    let viewModel: HomeScreenViewModel
    var subscriptions = Set<AnyCancellable>()

    let refresh = PassthroughSubject<Bool, Never>()

    private(set) lazy var datasource: DataSource = {
        let dataSource = DataSource(tableView: tableView) { tableView, indexPath, item in
            switch item {
            case .item(spot: let spot):
                let cell = tableView.dequeueReusableCell(withIdentifier: HomeScreenSpotCell.reuseID, for: indexPath) as? HomeScreenSpotCell
                cell?.configure(spot: spot)
                return cell
            }
        }
        return dataSource
    }()

    private(set) lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.rowHeight = 139
        tableView.backgroundColor = SpotColors.SpotBlack.color
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        tableView.clipsToBounds = true
        tableView.register(HomeScreenSpotCell.self, forCellReuseIdentifier: HomeScreenSpotCell.reuseID)
        tableView.register(HomeScreenTableHeader.self, forHeaderFooterViewReuseIdentifier: HomeScreenTableHeader.reuseID)
        return tableView
    }()

    private lazy var footerView: HomeScreenTableFooter = {
        let view = HomeScreenTableFooter()
        view.button.addTarget(self, action: #selector(refreshTap), for: .touchUpInside)
        return view
    }()

    private lazy var activityIndicator = UIActivityIndicatorView()

    private var isRefreshing = false {
        didSet {
            DispatchQueue.main.async {
                if self.isRefreshing {
                 //   self.tableView.layoutIfNeeded()
                //    let tableBottom = self.tableView.contentSize.height
                    self.activityIndicator.snp.removeConstraints()
                    self.activityIndicator.snp.makeConstraints {
                        $0.centerX.equalToSuperview()
                        $0.width.height.equalTo(30)
                        $0.bottom.equalTo(self.footerView.snp.top)
                    }

                    self.activityIndicator.startAnimating()

                } else {
                    self.activityIndicator.stopAnimating()
                }
            }
        }
    }

    private var forcedRefresh = false

    private lazy var titleView: HomeScreenTitleView = {
        let view = HomeScreenTitleView()
        view.searchButton.addTarget(self, action: #selector(searchTap), for: .touchUpInside)
        view.profileButton.addTarget(self, action: #selector(profileTap), for: .touchUpInside)
        view.notificationsButton.addTarget(self, action: #selector(notificationsTap), for: .touchUpInside)
        return view
    }()


    init(viewModel: HomeScreenViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        addNotifications()

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

        // setup view
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.leading.bottom.trailing.top.equalToSuperview()
         //   $0.bottom.equalTo(footerView.snp.top)
        }

        view.addSubview(footerView)
        footerView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(130)
        }

        tableView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(100)
            $0.width.height.equalTo(30)
        }
        activityIndicator.color = .white
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        activityIndicator.startAnimating()

        let input = Input(
            refresh: refresh
        )

        let output = viewModel.bind(to: input)
        output.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.datasource.apply(snapshot, animatingDifferences: false)
                self?.activityIndicator.stopAnimating()
                self?.isRefreshing = false
                //TODO: toggle empty state

                // scroll to first row on forced refresh
                if self?.forcedRefresh ?? false {
                    self?.forcedRefresh = false
                    if !snapshot.itemIdentifiers.isEmpty {
                        self?.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
                    }
                }
            }
            .store(in: &subscriptions)

        refresh.send(true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    private func addNotifications() {
        // deep link notis sent from SceneDelegate
        //TODO: add notis for updated user location 
        NotificationCenter.default.addObserver(self, selector: #selector(gotPost(_:)), name: NSNotification.Name("IncomingPost"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(gotNotification(_:)), name: NSNotification.Name("IncomingNotification"), object: nil)
    }

    private func setUpNavBar() {
        navigationController?.setUpDarkNav(translucent: false)
        navigationItem.titleView = titleView
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
                    guard !completion.documents.isEmpty else { return }
                    DispatchQueue.main.async {
                        self?.titleView.notificationsButton.pendingCount = completion.documents.count
                        self?.navigationItem.titleView = self?.titleView ?? UIView()
                    }
                })
            .store(in: &subscriptions)
    }

    @objc func searchTap() {
        let vc = SearchController(viewModel: SearchViewModel(serviceContainer: ServiceContainer.shared))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc func profileTap() {

    }

    @objc func notificationsTap() {
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

        switch section {
        case .top(title: let title):
            header?.configure(title: title)

        case .nearby(title: let title):
            header?.configure(title: title)
        }

        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 42.5
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = datasource.snapshot().sectionIdentifiers[indexPath.section]
        let item = datasource.snapshot().itemIdentifiers(inSection: section)[indexPath.item]
        switch item {
        case .item(spot: let spot):
            viewModel.setSeenLocally(spot: spot)
            refresh.send(false)
            
            let vc = SpotController(viewModel: SpotViewModel(serviceContainer: ServiceContainer.shared, spot: spot))
            DispatchQueue.main.async {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    @objc func refreshTap() {
        refresh.send(true)
        HapticGenerator.shared.play(.soft)
        isRefreshing = true
        forcedRefresh = true
    }
}

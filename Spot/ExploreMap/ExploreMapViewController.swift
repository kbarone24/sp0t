//
//  ExploreMapViewController.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Combine
import Firebase
import UIKit
import Mixpanel

protocol ExploreMapDelegate: AnyObject {
    func finishPassing()
}

final class ExploreMapViewController: UIViewController {
    typealias Input = ExploreMapViewModel.Input
    typealias DataSource = UITableViewDiffableDataSource<Section, Item>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias Title = ExploreMapViewModel.TitleData
    weak var delegate: ExploreMapDelegate?

    enum Section: Hashable {
        case body(title: Title)
    }

    enum Item: Hashable {
        case item(customMap: CustomMap, data: [MapPost], isSelected: Bool, offsetBy: CGPoint)
    }

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.contentInset = .zero
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120.0
        tableView.backgroundView?.backgroundColor = UIColor(named: "SpotBlack")
        tableView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 30, right: 0)
        tableView.sectionHeaderTopPadding = 0.0
        tableView.clipsToBounds = true
        tableView.register(ExploreMapPreviewCell.self, forCellReuseIdentifier: ExploreMapPreviewCell.reuseID)
        return tableView
    }()
    
    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)
        return refreshControl
    }()
    private lazy var footer = ExploreMapFooter(frame: CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.width, height: 120)))
    
    private lazy var activityIndicator: CustomActivityIndicator = {
        let activityIndictor = CustomActivityIndicator()
        activityIndictor.startAnimating()
        return activityIndictor
    }()

    private lazy var addMapConfirmationView = AddMapConfirmationView()

    private var snapshot = Snapshot() {
        didSet {
            tableView.reloadData()
        }
    }
    
    private lazy var dataSource: DataSource = {
        let dataSource = DataSource(tableView: tableView) { tableView, indexPath, item in

            switch item {
            case .item(let customMap, let data, let isSelected, let position):
                let cell = tableView.dequeueReusableCell(withIdentifier: ExploreMapPreviewCell.reuseID, for: indexPath) as? ExploreMapPreviewCell
                
                cell?.configure(customMap: customMap, data: data, rank: indexPath.row + 1, isSelected: isSelected, delegate: self, position: position)
                return cell
            }
        }

        return dataSource
    }()

    private let viewModel: ExploreMapViewModel
    private let refresh = PassthroughSubject<Bool, Never>()
    private let loading = PassthroughSubject<Bool, Never>()
    private let selectMap = PassthroughSubject<CustomMap?, Never>()
    private var subscriptions = Set<AnyCancellable>()

    init(viewModel: ExploreMapViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpNavBar()

        view.addSubview(tableView)
        view.addSubview(activityIndicator)

        tableView.refreshControl = refreshControl
        footer.isHidden = true
        footer.delegate = self
        tableView.tableFooterView = footer
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        activityIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(100)
            make.width.height.equalTo(30)
        }
        activityIndicator.startAnimating()

        addMapConfirmationView.isHidden = true
        view.addSubview(addMapConfirmationView)
        addMapConfirmationView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(34)
            $0.height.equalTo(57)
            $0.bottom.equalTo(-23)
        }

        let input = Input(refresh: refresh, loading: loading, selectMap: selectMap)
        let output = viewModel.bind(to: input)

        output.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                // self?.dataSource.apply(snapshot, animatingDifferences: false)
                self?.snapshot = snapshot
                if !snapshot.sectionIdentifiers.isEmpty {
                    self?.loading.send(false)
                }
            }
            .store(in: &subscriptions)
        
        output.isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.activityIndicator.startAnimating()
                    self?.refreshControl.beginRefreshing()
                    self?.footer.isHidden = true
                } else {
                    self?.activityIndicator.stopAnimating()
                    self?.refreshControl.endRefreshing()
                    self?.footer.isHidden = false
                }
            }
            .store(in: &subscriptions)

        refresh.send(true)
        loading.send(true)
        selectMap.send(nil)

        NotificationCenter.default.addObserver(self, selector: #selector(notifyEditMap(_:)), name: NSNotification.Name(("EditMap")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostChanged(_:)), name: NSNotification.Name(("PostChanged")), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Mixpanel.mainInstance().track(event: "ExploreMapsOpen")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async { self.resumeActivityAnimation() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        DispatchQueue.main.async { self.endRefreshAnimation() }
    }

    deinit {
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }

    private func setUpNavBar() {
        view.backgroundColor = UIColor(named: "SpotBlack")
        navigationController?.setUpDarkNav(translucent: true)
        navigationItem.title = "❤️‍🔥Hot maps❤️‍🔥"
    }

    @objc private func forceRefresh() {
        refreshControl.beginRefreshing()
        refresh.send(true)
    }

    private func endRefreshAnimation() {
        // end refresh control animation on view disappear
        if refreshControl.isRefreshing {
            refreshControl.endRefreshing()
        }
    }

    private func resumeActivityAnimation() {
        // resume frozen activity indicator animation
        if viewModel.cachedMaps.isEmpty && !activityIndicator.isHidden {
            refreshControl.endRefreshing()
            activityIndicator.startAnimating()
        }
    }
    
    @objc private func close() {
        navigationController?.popViewController(animated: true)
    }

    func scrollToTop() {
        if !snapshot.itemIdentifiers.isEmpty {
            DispatchQueue.main.async { self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true) }
        }
    }
}

extension ExploreMapViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return snapshot.sectionIdentifiers.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = snapshot.sectionIdentifiers[section]
        return snapshot.numberOfItems(inSection: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.row]
        
        switch item {
        case .item(let customMap, let data, let isSelected, let position):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ExploreMapPreviewCell.reuseID, for: indexPath) as? ExploreMapPreviewCell else {
                return UITableViewCell()
            }
            
            cell.configure(customMap: customMap, data: data, rank: indexPath.row + 1, isSelected: isSelected, delegate: self, position: position)
            return cell
        }
    }
}

extension ExploreMapViewController: ExploreMapPreviewCellDelegate {
    func mapTapped(map: CustomMap, posts: [MapPost]) {
        let updatedMap = viewModel.cachedMaps.first(where: { $0.key == map })?.key ?? map
        let customMapVC = CustomMapController(userProfile: nil, mapData: updatedMap, postsList: posts)
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(customMapVC, animated: true)
        }
    }

    func postTapped(map: CustomMap, post: MapPost) {
        if navigationController?.viewControllers.last is GridPostViewController { return } // double stack happening here
        if var posts = viewModel.cachedMaps[map], let postIndex = posts.firstIndex(where: { $0.id == post.id ?? "" }) {
            // remove everything before the index and append at end of the array
            posts.sortPostsOnOpen(index: postIndex)
            var subtitle = String(map.likers.count)
            subtitle += (map.communityMap ?? false) ? " joined" : " followers"
            let vc = GridPostViewController(parentVC: .Map, postsList: posts, delegate: nil, title: map.mapName, subtitle: subtitle)
            vc.mapData = map
            DispatchQueue.main.async { self.navigationController?.pushViewController(vc, animated: true) }
        }
    }

    func joinMap(map: CustomMap) {
        Mixpanel.mainInstance().track(event: "ExploreMapsJoinTap")
        toggleAddMapView()
        viewModel.joinMap(map: map, writeToFirebase: true) { [weak self] successful in
            // If there's an error that get returned after the UI is updated...
            // Then synchronize again the the database.
            // Or else, continue with the client's version
            if successful {
                self?.refresh.send(false)
            } else {
                self?.refresh.send(true)
            }
        }
    }

    func moreTapped(map: CustomMap) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(
            UIAlertAction(title: "Share map", style: .default) { [weak self] _ in
                self?.shareMap(map: map)
            })
        alert.addAction(
            UIAlertAction(title: "Report map", style: .destructive) { [weak self] _ in
                self?.reportMap(map: map)
            })
        alert.addAction(
            UIAlertAction(title: "Dismiss", style: .cancel) { _ in
            })
        present(alert, animated: true)
    }

    private func toggleAddMapView() {
        addMapConfirmationView.isHidden = false
        addMapConfirmationView.alpha = 1.0
        UIView.animate(withDuration: 0.3, delay: 2.0, animations: { [weak self] in
            self?.addMapConfirmationView.alpha = 0.0
        }, completion: { [weak self] _ in
            self?.addMapConfirmationView.isHidden = true
            self?.addMapConfirmationView.alpha = 1.0
        })
    }
    
    func cacheScrollPosition(map: CustomMap, position: CGPoint) {
        viewModel.cacheScrollPosition(map: map, position: position)
    }

    @objc func notifyEditMap(_ notification: Notification) {
        Mixpanel.mainInstance().track(event: "ExploreMapsMoreTap")
        guard let map = notification.userInfo?["map"] as? CustomMap else { return }
        viewModel.editMap(map: map)
        refresh.send(false)
    }

    @objc func notifyPostChanged(_ notification: Notification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        if let map = viewModel.cachedMaps.first(where: { $0.key.id == post.mapID }) {
            if let i = viewModel.cachedMaps[map.key]?.firstIndex(where: { $0.id == post.id }) {
                viewModel.cachedMaps[map.key]?[i].likers = post.likers
                viewModel.cachedMaps[map.key]?[i].commentCount = post.commentCount
                viewModel.cachedMaps[map.key]?[i].commentList = post.commentList
                refresh.send(false)
            }
        }

    }

    private func shareMap(map: CustomMap) {
        print("share map")
    }

    private func reportMap(map: CustomMap) {
        let alertController = UIAlertController(title: "Report map", message: nil, preferredStyle: .alert)

        alertController.addAction(
            UIAlertAction(title: "Report", style: .destructive) { [weak self] _ in
                if let txtField = alertController.textFields?.first, let text = txtField.text {
                    Mixpanel.mainInstance().track(event: "ReportMapTap")
                    self?.viewModel.mapService.reportMap(mapID: map.id ?? "", feedbackText: text, userID: UserDataModel.shared.uid)
                    self?.showConfirmationAction()
                    Mixpanel.mainInstance().track(event: "ExploreMapsReportTap")
                }
            }
        )

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
            Mixpanel.mainInstance().track(event: "ExploreMapsReportCancelTap")
        }))
        alertController.addTextField { (textField) in
            textField.autocorrectionType = .default
            textField.placeholder = "Why are you reporting this map?"
        }

        present(alertController, animated: true, completion: nil)
    }

    private func showConfirmationAction() {
        let text = "Thank you for the feedback. We will review your report ASAP."
        let alert = UIAlertController(title: "Success!", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default))
        present(alert, animated: true, completion: nil)
    }
}

extension ExploreMapViewController: ExploreMapFooterDelegate {
    func buttonAction() {
        let mapVC = NewMapController(mapObject: nil, newMapMode: true)
        let vc = UINavigationController(rootViewController: mapVC)
        vc.modalPresentationStyle = .fullScreen
        DispatchQueue.main.async { self.present(vc, animated: true) }
    }
}

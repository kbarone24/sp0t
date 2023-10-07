//
//  CustomMapController.swift
//  Spot
//
//  Created by Kenny Barone on 10/6/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Combine
import Firebase
import Mixpanel
import PhotosUI

final class CustomMapController: UIViewController {
    typealias Input = CustomMapViewModel.Input
    typealias Output = CustomMapViewModel.Output
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UITableViewDiffableDataSource<Section, Item>

    enum Section: Hashable {
        case main(map: CustomMap, sortMethod: CustomMapViewModel.SortMethod)
    }

    enum Item: Hashable {
        case item(post: Post)
    }

    let viewModel: CustomMapViewModel
    var subscriptions = Set<AnyCancellable>()

    let refresh = PassthroughSubject<Bool, Never>()
    let postListener = PassthroughSubject<(forced: Bool, commentInfo: (post: Post?, endDocument: DocumentSnapshot?)), Never>()
    let sort = PassthroughSubject<(sort: CustomMapViewModel.SortMethod, useEndDoc: Bool), Never>()

    var disablePagination: Bool {
        switch viewModel.activeSortMethod {
        case .New: return viewModel.disableRecentPagination
        case .Hot: return viewModel.disableTopPagination
        }
    }

    var scrollToPostID: String?
    var isScrollingToTop = false

    weak var cameraPicker: UIImagePickerController?
    weak var galleryPicker: PHPickerViewController?

    private(set) lazy var datasource: DataSource = {
        let dataSource = DataSource(tableView: tableView) { [weak self] tableView, indexPath, item in
            switch item {
            case .item(post: let post):
                let cell = tableView.dequeueReusableCell(withIdentifier: SpotPostCell.reuseID, for: indexPath) as? SpotPostCell
                cell?.configure(post: post, parent: .CustomMap)
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
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)
        tableView.clipsToBounds = true
        tableView.register(SpotPostCell.self, forCellReuseIdentifier: SpotPostCell.reuseID)
        tableView.register(MapOverviewHeader.self, forHeaderFooterViewReuseIdentifier: MapOverviewHeader.reuseID)
        return tableView
    }()

    private lazy var activityFooterView = ActivityFooterView()

    private lazy var activityIndicator = UIActivityIndicatorView()

    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .white
        refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)
        return refreshControl
    }()

    private lazy var textFieldFooter = SpotTextFieldFooter(parent: .CustomMap)

    var isRefreshingPagination = false {
        didSet {
            DispatchQueue.main.async {
                if self.isRefreshingPagination, !self.datasource.snapshot().itemIdentifiers.isEmpty {
                    self.activityFooterView.isHidden = false
                } else {
                    self.activityFooterView.isHidden = true
                }
            }
        }
    }

    var isLoadingNewPosts = false {
        didSet {
            DispatchQueue.main.async {
                if self.isLoadingNewPosts {
                    self.tableView.bringSubviewToFront(self.activityIndicator)
                    self.activityIndicator.startAnimating()
                }
            }
        }
    }

    init(viewModel: CustomMapViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        edgesForExtendedLayout = []
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        Mixpanel.mainInstance().track(event: "MapPageAppeared")
    }

    override func viewDidLoad() {
        view.backgroundColor = SpotColors.HeaderGray.color

        tableView.refreshControl = refreshControl
        activityFooterView.isHidden = true
        tableView.tableFooterView = activityFooterView
        view.addSubview(tableView)

        tableView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(100)
            $0.width.height.equalTo(30)
        }
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        activityIndicator.color = .white
        activityIndicator.startAnimating()

        view.addSubview(textFieldFooter)
        textFieldFooter.delegate = self
        textFieldFooter.isHidden = true
        // TODO: hide/show footer based on if user is member of map
        textFieldFooter.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(113)
        }

        tableView.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.bottom.equalTo(textFieldFooter.snp.top)
        }

        let input = Input(
            refresh: refresh,
            postListener: postListener,
            sort: sort
        )

        let cachedOutput = viewModel.bindForCachedPosts(to: input)
        cachedOutput.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.datasource.apply(snapshot, animatingDifferences: false)
                self?.addFooter()

                if let postID = self?.scrollToPostID, let selectedRow = self?.viewModel.getSelectedIndexFor(postID: postID) {
                    // scroll to selected row on post upload
                    let path = IndexPath(row: selectedRow, section: 0)
                    self?.tableView.scrollToRow(at: path, at: .middle, animated: true)
                    self?.scrollToPostID = nil
                }
            }
            .store(in: &subscriptions)

        let output = viewModel.bindForFetchedPosts(to: input)
        output.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.datasource.apply(snapshot, animatingDifferences: false)

                self?.isRefreshingPagination = false
                self?.isLoadingNewPosts = false
                self?.refreshControl.endRefreshing()

                // end activity animation on empty state or if returning a post
                if self?.viewModel.postsAreEmpty() ?? false || !snapshot.itemIdentifiers.isEmpty {
                    self?.activityIndicator.stopAnimating()
                }

                // call in case map name wasn't passed through
                self?.setUpNavBar()
                self?.addFooter()
            }
            .store(in: &subscriptions)


        postListener.send((forced: false, commentInfo: (post: nil, endDocument: nil)))
        sort.send((sort: viewModel.activeSortMethod, useEndDoc: true))
    }

    private func setUpNavBar() {
        navigationController?.setUpOpaqueNav(backgroundColor: SpotColors.HeaderGray.color)
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont(name: "UniversCE-Black", size: 20) as Any
        ]
        navigationItem.title = viewModel.cachedMap.mapName
    }

    private func addFooter() {
        textFieldFooter.isHidden = !viewModel.cachedMap.memberIDs.contains(UserDataModel.shared.uid)
        tableView.snp.removeConstraints()
        tableView.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            if textFieldFooter.isHidden {
                $0.bottom.equalToSuperview()
            } else {
                $0.bottom.equalTo(textFieldFooter)
            }
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if isScrollingToTop {
            postListener.send((
                forced: false,
                commentInfo: (
                    post: nil,
                    endDocument: nil
                )
            ))
            sort.send((sort: .New, useEndDoc: false))

            isScrollingToTop = false
        }
    }

    @objc func forceRefresh() {
        Mixpanel.mainInstance().track(event: "MapPagePullToRefresh")
        postListener.send((
            forced: false,
            commentInfo: (
                post: nil,
                endDocument: nil
            )))
        sort.send((sort: viewModel.activeSortMethod, useEndDoc: false))

        DispatchQueue.main.async {
            self.refreshControl.beginRefreshing()
        }
    }
}


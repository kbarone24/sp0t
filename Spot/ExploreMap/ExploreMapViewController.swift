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

final class ExploreMapViewController: UIViewController {
    typealias Input = ExploreMapViewModel.Input
    typealias DataSource = UITableViewDiffableDataSource<Section, Item>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias JoinButton = ExploreMapViewModel.JoinButtonType
    typealias Title = ExploreMapViewModel.TitleData

    enum Section: Hashable {
        case body(title: Title)
    }

    enum Item: Hashable {
        case item(customMap: CustomMap, data: [MapPost], isSelected: Bool, buttonType: JoinButton, offSetBy: CGPoint)
    }

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.contentInset = .zero
        tableView.backgroundColor = .white
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120.0
        tableView.backgroundView?.backgroundColor = .white
        tableView.backgroundColor = .white
        tableView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 80, right: 0)

        tableView.register(ExploreMapPreviewCell.self, forCellReuseIdentifier: ExploreMapPreviewCell.reuseID)

        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        }

        return tableView
    }()
    
    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)
        return refreshControl
    }()
    
    private lazy var activityIndicator: CustomActivityIndicator = {
        let activityIndictor = CustomActivityIndicator()
        activityIndictor.startAnimating()
        return activityIndictor
    }()

    private lazy var bottomMask: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }()
    var maskLayer: CAGradientLayer?
    
    private lazy var joinButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor(hexString: "39F3FF")
        button.layer.cornerRadius = 10.0
        button.clipsToBounds = true
        button.titleLabel?.font = UIFont(name: "SFCompactText-Heavy", size: 16.0)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.textAlignment = .center
        button.setTitle("Join 0 maps", for: .normal)
        button.addTarget(self, action: #selector(joinButtonTapped), for: .touchUpInside)
        
        return button
    }()

    private lazy var descriptionView = ExploreMapTitleView()
    
    private var snapshot = Snapshot() {
        didSet {
            tableView.reloadData()
        }
    }
    
    private lazy var dataSource: DataSource = {
        let dataSource = DataSource(tableView: tableView) { tableView, indexPath, item in

            switch item {
            case .item(let customMap, let data, let isSelected, let buttonType, let position):
                let cell = tableView.dequeueReusableCell(withIdentifier: ExploreMapPreviewCell.reuseID, for: indexPath) as? ExploreMapPreviewCell
                
                cell?.configure(customMap: customMap, data: data, isSelected: isSelected, buttonType: buttonType, delegate: self, position: position)
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
      //  if viewModel.openedFrom == .onBoarding {
      //      addBottomMask()
      //  }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpNavBar()

        view.addSubview(descriptionView)
        view.addSubview(tableView)
        view.addSubview(joinButton)
        view.addSubview(activityIndicator)

        descriptionView.configure(title: "", description: "Maps created by fellow Tar Heels")
        descriptionView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(26.0)
        }
        
        tableView.refreshControl = refreshControl

        tableView.snp.makeConstraints { make in
            make.top.equalTo(descriptionView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(20.0)
        }
        
        joinButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(22.0)
            make.bottom.equalToSuperview().inset(42.0)
            make.height.equalTo(50.0)
        }
        
        activityIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(80)
            make.width.height.equalTo(30)
        }
        
        activityIndicator.startAnimating()

        if viewModel.openedFrom == .onBoarding {
            view.insertSubview(bottomMask, belowSubview: joinButton)
            bottomMask.backgroundColor = .white
            bottomMask.snp.makeConstraints {
                $0.leading.trailing.bottom.equalToSuperview()
                $0.top.equalTo(joinButton.snp.top).offset(-16)
            }
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
                } else {
                    self?.activityIndicator.stopAnimating()
                    self?.refreshControl.endRefreshing()
                }
            }
            .store(in: &subscriptions)
        
        output.selectedMaps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selectedMaps in
                let count = selectedMaps.count
                let title = count == 1 ? "Join 1 map" : "Join \(count) maps"
                let isEnabled = !selectedMaps.isEmpty
                self?.joinButton.isEnabled = isEnabled
                self?.joinButton.setTitle(title, for: .normal)
                if isEnabled {
                    self?.joinButton.backgroundColor = UIColor(hexString: "39F3FF")
                } else {
                    self?.joinButton.backgroundColor = UIColor(hexString: "39F3FF").withAlphaComponent(0.6)
                }
            }
            .store(in: &subscriptions)
        
        output.joinButtonIsHidden
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isHidden in
                self?.joinButton.isHidden = isHidden
            }
            .store(in: &subscriptions)
        
        refresh.send(true)
        loading.send(true)
        selectMap.send(nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        Mixpanel.mainInstance().track(event: "ExploreMapsOpen")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }

    private func setUpNavBar() {
        view.backgroundColor = .white
        navigationItem.backButtonTitle = ""

        navigationController?.navigationBar.barTintColor = UIColor.white
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.tintColor = UIColor.black
        navigationController?.view.backgroundColor = .white

        if viewModel.openedFrom == .mapController {
            let backButton = UIBarButtonItem(image: UIImage(named: "BackArrow"), style: .plain, target: self, action: #selector(close))
            navigationItem.setLeftBarButton(backButton, animated: false)
            self.navigationItem.leftBarButtonItem?.tintColor = nil
        } else {
            navigationItem.leftBarButtonItem = UIBarButtonItem()
        }

        title = "UNC Maps"
        let appearance = navigationController?.navigationBar.standardAppearance
        appearance?.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.black,
            NSAttributedString.Key.font: UIFont(name: "SFCompactText-Heavy", size: 22) as Any
        ]
    }

    private func addBottomMask() {
        if maskLayer != nil { return }
        maskLayer = CAGradientLayer {
            $0.frame = bottomMask.bounds
            $0.colors = [
                UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0).cgColor,
                UIColor.white.cgColor,
                UIColor.white.cgColor
            ]
            $0.startPoint = CGPoint(x: 0.5, y: 0.0)
            $0.endPoint = CGPoint(x: 0.5, y: 1.0)
            $0.locations = [0, 0.4, 1]
            bottomMask.layer.addSublayer($0)
        }
    }
    
    @objc private func forceRefresh() {
        refreshControl.beginRefreshing()
        refresh.send(true)
    }
    
    @objc private func joinButtonTapped() {
        loading.send(true)
        viewModel.joinAllSelectedMaps { [weak self] in
            self?.close()
        }
    }
    
    @objc private func close() {
        navigationController?.popViewController(animated: true)
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
        case .item(let customMap, let data, let isSelected, let buttonType, let position):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ExploreMapPreviewCell.reuseID, for: indexPath) as? ExploreMapPreviewCell else {
                return UITableViewCell()
            }
            
            cell.configure(customMap: customMap, data: data, isSelected: isSelected, buttonType: buttonType, delegate: self, position: position)
            return cell
        }
    }
}

extension ExploreMapViewController: ExploreMapPreviewCellDelegate {
    func cellTapped(data: CustomMap) {
        selectMap.send(data)
        refresh.send(false)
    }
    
    func joinMap(map: CustomMap) {
        loading.send(true)
        viewModel.joinMap(map: map) { [weak self] successful in
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
    
    func cacheScrollPosition(map: CustomMap, position: CGPoint) {
        viewModel.cacheScrollPosition(map: map, position: position)
    }
}

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

final class ExploreMapViewController: UIViewController {
    typealias Input = ExploreMapViewModel.Input
    typealias DataSource = UITableViewDiffableDataSource<Section, Item>

    enum Section: Hashable {
        case body
    }

    enum Item: Hashable {
        case item(data: CustomMap)
    }

    private lazy var tableView: UITableView = {
        let tableView = UITableView()

        tableView.contentInset = .zero
        tableView.backgroundColor = .white
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.delegate = self

        tableView.register(ExploreMapPreviewCell.self, forCellReuseIdentifier: ExploreMapPreviewCell.reuseID)

        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        }

        return tableView
    }()

    private lazy var titleView: ExploreMapTitleView = {
        let view = ExploreMapTitleView()
        return view
    }()
    
    private lazy var activityIndicator: CustomActivityIndicator = {
        let activityIndictor = CustomActivityIndicator()
        activityIndictor.startAnimating()
        return activityIndictor
    }()

    private lazy var dataSource: DataSource = {
        let dataSource = DataSource(tableView: tableView) { tableView, indexPath, item in

            switch item {
            case .item(let data):
                let cell = tableView.dequeueReusableCell(withIdentifier: ExploreMapPreviewCell.reuseID, for: indexPath) as? ExploreMapPreviewCell
                cell?.configure(data: data)
                return cell
            }
        }

        return dataSource
    }()

    private let viewModel: ExploreMapViewModel
    private let refresh = PassthroughSubject<Void, Never>()
    private var subscriptions = Set<AnyCancellable>()

    init(viewModel: ExploreMapViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        navigationItem.backButtonTitle = ""

        navigationController?.navigationBar.barTintColor = UIColor.white
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.tintColor = UIColor.black
        navigationController?.view.backgroundColor = .white

        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0, green: 0, blue: 0, alpha: 1),
            .font: UIFont(name: "SFCompactText-Heavy", size: 20) as Any
        ]

        let backButton = UIBarButtonItem(image: UIImage(named: "BackArrow"), style: .plain, target: self, action: #selector(close))
        navigationItem.setLeftBarButton(backButton, animated: false)
        self.navigationItem.leftBarButtonItem?.tintColor = nil

        view.addSubview(tableView)
        view.addSubview(activityIndicator)

        tableView.snp.makeConstraints { make in
            make.top.bottom.leading.trailing.equalToSuperview()
        }
        
        activityIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(60)
        }
        
        navigationItem.titleView = titleView
        
        activityIndicator.startAnimating()
        let input = Input(refresh: refresh)
        viewModel.bind(to: input)

        viewModel.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.dataSource.apply(snapshot, animatingDifferences: false)
            }
            .store(in: &subscriptions)
        
        viewModel.$titleData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] titleData in
                self?.titleView.configure(title: titleData.title, description: titleData.description)
            }
            .store(in: &subscriptions)
        
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.activityIndicator.startAnimating()
                } else {
                    self?.activityIndicator.stopAnimating()
                }
            }
            .store(in: &subscriptions)
        
        refresh.send()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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

    @objc private func close() {
        navigationController?.popViewController(animated: true)
    }
}

extension ExploreMapViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return titleView
    }
}

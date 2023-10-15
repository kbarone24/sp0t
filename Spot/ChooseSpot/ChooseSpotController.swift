//
//  ChooseSpotController.swift
//  Spot
//
//  Created by Kenny Barone on 10/2/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Combine

protocol ChooseSpotDelegate: AnyObject {
    func selectedSpot(spot: Spot)
}

class ChooseSpotController: UIViewController {
    typealias Input = ChooseSpotViewModel.Input
    typealias Output = ChooseSpotViewModel.Output
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UITableViewDiffableDataSource<Section, Item>

    enum Section: Hashable {
        case main
    }

    enum Item: Hashable {
        case item(spot: Spot)
    }

    weak var delegate: ChooseSpotDelegate?
    let viewModel: ChooseSpotViewModel
    var subscriptions = Set<AnyCancellable>()
    var selectedSpot: Spot?

    let refresh = PassthroughSubject<Bool, Never>()
    private var emptyStateHidden = true

    private(set) lazy var datasource: DataSource = {
        let dataSource = DataSource(tableView: tableView) { [weak self] tableView, indexPath, item in
            switch item {
            case .item(spot: let spot):
                let cell = tableView.dequeueReusableCell(withIdentifier: ChooseSpotCell.reuseID, for: indexPath) as? ChooseSpotCell
                let isSelectedSpot = spot.id == self?.selectedSpot?.id ?? "empty"
                cell?.configure(spot: spot, isSelectedSpot: isSelectedSpot)
                return cell
            }
        }
        return dataSource
    }()

    private(set) lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.rowHeight = 58
        tableView.estimatedRowHeight = 58
        tableView.backgroundColor = SpotColors.HeaderGray.color
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)
        tableView.clipsToBounds = true
        tableView.register(ChooseSpotCell.self, forCellReuseIdentifier: ChooseSpotCell.reuseID)
        return tableView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose spot"
        label.textColor = .white
        label.font = SpotFonts.UniversCE.fontWith(size: 20)
        return label
    }()

    private lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No spots nearby"
        label.textColor = SpotColors.SublabelGray.color
        label.isHidden = true
        return label
    }()

    private lazy var activityIndicator = UIActivityIndicatorView()

    init(viewModel: ChooseSpotViewModel, delegate: ChooseSpotDelegate?, selectedSpot: Spot?) {
        self.viewModel = viewModel
        self.delegate = delegate
        self.selectedSpot = selectedSpot
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SpotColors.HeaderGray.color

        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(20)
        }

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.top.equalTo(titleLabel.snp.bottom).offset(8)
        }

        tableView.addSubview(emptyStateLabel)
        emptyStateLabel.snp.makeConstraints {
            $0.top.leading.equalTo(16)
        }

        tableView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(60)
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
                self?.activityIndicator.stopAnimating()
                self?.emptyStateLabel.isHidden = !snapshot.itemIdentifiers.isEmpty
                self?.datasource.apply(snapshot, animatingDifferences: false)
            }
            .store(in: &subscriptions)

        refresh.send(true)
    }
}

extension ChooseSpotController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = datasource.snapshot().sectionIdentifiers[indexPath.section]
        let item = datasource.snapshot().itemIdentifiers(inSection: section)[indexPath.item]
        switch item {
        case .item(spot: let spot):
            DispatchQueue.main.async {
                self.delegate?.selectedSpot(spot: spot)
                HapticGenerator.shared.play(.light)
                self.dismiss(animated: true)
            }
        }
    }
}

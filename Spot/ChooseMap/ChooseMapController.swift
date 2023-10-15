//
//  ChooseMapController.swift
//  Spot
//
//  Created by Kenny Barone on 10/3/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Combine

protocol ChooseMapDelegate: AnyObject {
    func selectedMap(map: CustomMap)
}

class ChooseMapController: UIViewController {
    typealias Input = ChooseMapViewModel.Input
    typealias Output = ChooseMapViewModel.Output
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UITableViewDiffableDataSource<Section, Item>

    enum Section: Hashable {
        case main
    }

    enum Item: Hashable {
        case new
        case custom(map: CustomMap)
    }

    let viewModel: ChooseMapViewModel
    var subscriptions = Set<AnyCancellable>()
    weak var delegate: ChooseMapDelegate?
    var selectedMap: CustomMap?

    let refresh = PassthroughSubject<Bool, Never>()
    private var emptyStateHidden = true

    private(set) lazy var datasource: DataSource = {
        let dataSource = DataSource(tableView: tableView) { [weak self] tableView, indexPath, item in
            switch item {
            case .new:
                let cell = tableView.dequeueReusableCell(withIdentifier: NewMapCell.reuseID, for: indexPath) as? NewMapCell
                return cell ?? UITableViewCell()
            case .custom(map: let map):
                let cell = tableView.dequeueReusableCell(withIdentifier: ChooseMapCell.reuseID, for: indexPath) as? ChooseMapCell
                let isSelectedMap = map.id == self?.selectedMap?.id ?? "empty"
                cell?.configure(map: map, isSelectedMap: isSelectedMap)
                return cell
            }
        }
        return dataSource
    }()

    private(set) lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.rowHeight = 70
        tableView.estimatedRowHeight = 70
        tableView.backgroundColor = SpotColors.HeaderGray.color
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 40, right: 0)
        tableView.clipsToBounds = true
        tableView.register(ChooseMapCell.self, forCellReuseIdentifier: ChooseMapCell.reuseID)
        tableView.register(NewMapCell.self, forCellReuseIdentifier: NewMapCell.reuseID)
        return tableView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose Map"
        label.textColor = .white
        label.font = SpotFonts.UniversCE.fontWith(size: 20)
        return label
    }()

    private lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No maps nearby"
        label.textColor = SpotColors.SublabelGray.color
        label.isHidden = true
        return label
    }()

    private lazy var activityIndicator = UIActivityIndicatorView()

    init(viewModel: ChooseMapViewModel, delegate: ChooseMapDelegate?, selectedMap: CustomMap?) {
        self.viewModel = viewModel
        self.delegate = delegate
        self.selectedMap = selectedMap
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

extension ChooseMapController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = datasource.snapshot().sectionIdentifiers[indexPath.section]
        let item = datasource.snapshot().itemIdentifiers(inSection: section)[indexPath.item]
        switch item {
        case .new:
            DispatchQueue.main.async {
                let vc = NewMapController(mapObject: nil, delegate: self)
                self.present(vc, animated: true)
            }
        case .custom(map: let map):
            selectMapAndDismiss(map: map, animated: true)
        }
    }

    private func selectMapAndDismiss(map: CustomMap, animated: Bool) {
        DispatchQueue.main.async {
            self.delegate?.selectedMap(map: map)
            HapticGenerator.shared.play(.light)
            self.dismiss(animated: true)
        }
    }
}

extension ChooseMapController: NewMapDelegate {
    func finishPassing(map: CustomMap) {
        selectMapAndDismiss(map: map, animated: false)
    }
}

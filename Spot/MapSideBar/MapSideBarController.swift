//
//  MapSideBarController.swift
//  Spot
//
//  Created by Kenny Barone on 12/29/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class MapSideBarController: UIViewController {
    var mapsLoaded = false
    weak var homeScreenDelegate: HomeScreenDelegate?

    private lazy var headerView = UIView()
    private lazy var headerLabel: UILabel = {
        var label = UILabel()
        label.text = "My maps"
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Heavy", size: 19)
        return label
    }()
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .white
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 70, right: 0)
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        return tableView
    }()
    
    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
        view.backgroundColor = .white
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(loadMaps), name: NSNotification.Name("UserMapsLoad"), object: nil)
        setUpView()
    }

    func setUpView() {
        view.addSubview(headerView)
        headerView.backgroundColor = .white
        headerView.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.height.equalTo(95)
        }

        headerView.addSubview(headerLabel)
        headerLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(15)
            $0.bottom.equalToSuperview().inset(10)
        }

        tableView.register(TableViewLoadingCell.self, forCellReuseIdentifier: "LoadingCell")
        tableView.register(SideBarNewMapCell.self, forCellReuseIdentifier: "NewCell")
        tableView.register(SideBarCustomMapCell.self, forCellReuseIdentifier: "MapCell")
        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(headerView.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    @objc func loadMaps() {
        mapsLoaded = true
        reloadTable()
    }

    func reloadTable() {
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
}

extension MapSideBarController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return mapsLoaded ? UserDataModel.shared.userInfo.mapsList.count + 1 : 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let emptyCell = UITableViewCell()
        switch indexPath.row {
        case 0:
            if mapsLoaded {
                return tableView.dequeueReusableCell(withIdentifier: "NewCell", for: indexPath) as? SideBarNewMapCell ?? emptyCell
            } else {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LoadingCell", for: indexPath) as? TableViewLoadingCell else { return emptyCell }
                cell.activityIndicator.startAnimating()
                return cell
            }
        default:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "MapCell", for: indexPath) as? SideBarCustomMapCell else { return emptyCell }
            cell.setUp(map: UserDataModel.shared.userInfo.mapsList[indexPath.row - 1])
            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 73
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            if !mapsLoaded { return }
            homeScreenDelegate?.openNewMap()
        default:
            homeScreenDelegate?.openMap(map: UserDataModel.shared.userInfo.mapsList[indexPath.row - 1])
        }
    }
}

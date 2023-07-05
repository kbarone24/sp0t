//
//  ChooseMapController.swift
//  Spot
//
//  Created by Kenny Barone on 5/25/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFirestore
import FirebaseAuth
import Mixpanel
import SnapKit
import UIKit

protocol ChooseMapDelegate: AnyObject {
    func finishPassing(map: CustomMap?)
    func toggle(cancel: Bool)
}

final class ChooseMapController: UIViewController {
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore = Firestore.firestore()
    weak var delegate: ChooseMapDelegate?

    lazy var customMaps: [CustomMap] = []

    private lazy var searchBarContainer = UIView()
    private lazy var searchBar: UISearchBar = {
        let searchBar = SpotSearchBar()
        searchBar.searchTextField.attributedPlaceholder = NSAttributedString(
            string: "Search Maps",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)]
        )
        searchBar.keyboardDistanceFromTextField = 250
        return searchBar
    }()

    lazy var tableView: UITableView = {
        let table = UITableView()
        table.backgroundColor = UIColor(named: "SpotBlack")
        table.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = false
        table.register(ChooseMapCustomCell.self, forCellReuseIdentifier: "MapCell")
        table.register(ChooseMapNewCell.self, forCellReuseIdentifier: "NewMap")
        table.register(CustomMapsHeader.self, forHeaderFooterViewReuseIdentifier: "MapsHeader")
        table.register(TableViewLoadingCell.self, forCellReuseIdentifier: "LoadingCell")
        return table
    }()

    lazy var queryMaps = [CustomMap]()
    lazy var mapSearching = false
    lazy var queried = false
    lazy var searchTextGlobal = ""
    lazy var cancelOnDismiss = false

    lazy var mapService: MapServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.mapsService)
        return service
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
        DispatchQueue.global(qos: .userInitiated).async { self.getCustomMaps() }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        delegate?.toggle(cancel: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "ChooseMapOpen")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        delegate?.toggle(cancel: false)
    }
    
    func setUpView() {
        view.backgroundColor = UIColor(named: "SpotBlack")

        searchBarContainer.backgroundColor = nil
        view.addSubview(searchBarContainer)
        searchBarContainer.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalToSuperview().offset(20)
            $0.height.equalTo(50)
        }

        searchBar.delegate = self
        searchBarContainer.addSubview(searchBar)
        searchBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(14)
            $0.top.equalTo(6)
            $0.height.equalTo(36)
        }

        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(searchBarContainer.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    func getCustomMaps() {
        customMaps = UserDataModel.shared.userInfo.mapsList.filter({ $0.memberIDs.contains(UserDataModel.shared.uid) }).sorted(by: { $0.userTimestamp.seconds > $1.userTimestamp.seconds })
        if let map = UploadPostModel.shared.mapObject, !customMaps.contains(where: { $0.id == map.id ?? "" }) {
            customMaps.insert(map, at: 0)
        }
        DispatchQueue.main.async { self.tableView.reloadData() }
    }

    func selectMap(map: CustomMap?) {
        let animated = map == nil ? false : true
        Mixpanel.mainInstance().track(event: "ChooseMapSelectMap")

        DispatchQueue.main.async {
            if map != nil { HapticGenerator.shared.play(.light) }
            self.delegate?.finishPassing(map: map)
            self.dismiss(animated: animated)
        }
    }
}

extension ChooseMapController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if mapSearching {
            // show loading cell
            return queryMaps.count + 1

        } else if queried {
            return queryMaps.count

        } else {
            // show new map cell
            return customMaps.count + 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if !mapSearching && !queried, indexPath.row == 0, let cell = tableView.dequeueReusableCell(withIdentifier: "NewMap", for: indexPath) as? ChooseMapNewCell {
            // show new map cell first if not in a fetched state
            return cell

        } else if mapSearching, indexPath.row == queryMaps.count, let cell = tableView.dequeueReusableCell(withIdentifier: "LoadingCell", for: indexPath) as? TableViewLoadingCell {
            // show loading cell last if actively fetching
            cell.activityIndicator.startAnimating()
            return cell

        } else if let cell = tableView.dequeueReusableCell(withIdentifier: "MapCell", for: indexPath) as? ChooseMapCustomCell {
            let map = queried ? queryMaps[safe: indexPath.row] : customMaps[safe: indexPath.row - 1]
            guard let map else { return UITableViewCell() }
            cell.setUp(map: map)
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let map = queried ? queryMaps[safe: indexPath.row] : customMaps[safe: indexPath.row - 1]
        selectMap(map: map)
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return queried ? 0 : 40
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "MapsHeader") as? CustomMapsHeader else { return UIView() }
        return header
    }
}

//
//  ChooseMapController.swift
//  Spot
//
//  Created by Kenny Barone on 5/25/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
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

    private lazy var customMaps: [CustomMap] = []

    private lazy var tableView: UITableView = {
        let table = UITableView()
        table.backgroundColor = UIColor(named: "SpotBlack")
        table.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = false
        table.register(ChooseMapCustomCell.self, forCellReuseIdentifier: "MapCell")
        table.register(ChooseMapNewCell.self, forCellReuseIdentifier: "NewMap")
        table.register(CustomMapsHeader.self, forHeaderFooterViewReuseIdentifier: "MapsHeader")
        return table
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

        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.leading.trailing.bottom.equalToSuperview()
        }
    }

    func getCustomMaps() {
        customMaps = UserDataModel.shared.userInfo.mapsList.filter({ $0.memberIDs.contains(UserDataModel.shared.uid) }).sorted(by: { $0.userTimestamp.seconds > $1.userTimestamp.seconds })
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
        return customMaps.count + 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0, let cell = tableView.dequeueReusableCell(withIdentifier: "NewMap", for: indexPath) as? ChooseMapNewCell {
            return cell
        }
        if let cell = tableView.dequeueReusableCell(withIdentifier: "MapCell", for: indexPath) as? ChooseMapCustomCell {
            cell.setUp(map: customMaps[indexPath.row - 1])
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let index = indexPath.row - 1
        let map = customMaps[safe: index]
        selectMap(map: map)
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "MapsHeader") as? CustomMapsHeader else { return UIView() }
        return header
    }
}

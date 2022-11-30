//
//  ChooseSpotController.swift
//  Spot
//
//  Created by Kenny Barone on 7/12/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation
import Geofirestore
import MapKit
import Mixpanel
import UIKit

protocol ChooseSpotDelegate: AnyObject {
    func finishPassing(spot: MapSpot?)
}

class ChooseSpotController: UIViewController {
    private lazy var searchBarContainer = UIView()
    private lazy var searchBar: UISearchBar = {
        let searchBar = SpotSearchBar()
        searchBar.searchTextField.attributedPlaceholder = NSAttributedString(
            string: "Search spots",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)]
        )
        searchBar.keyboardDistanceFromTextField = 250
        return searchBar
    }()
    lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        tableView.backgroundColor = .white
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.register(ChooseSpotCell.self, forCellReuseIdentifier: "ChooseSpot")
        tableView.register(ChooseSpotLoadingCell.self, forCellReuseIdentifier: "ChooseSpotLoading")
        return tableView
    }()
    private lazy var createSpotButton = CreateSpotButton()
    
    lazy var spotObjects: [MapSpot] = []
    lazy var querySpots: [MapSpot] = []
    
    lazy var spotService: SpotServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.spotService)
        return service
    }()
    
    lazy var searchRefreshCount = 0
    lazy var spotSearching = false
    lazy var queried = false
    lazy var searchTextGlobal = ""
    lazy var cancelOnDismiss = false
    lazy var queryReady = true
    
    /// nearby spot fetch variables
    let db = Firestore.firestore()
    let geoFirestore = GeoFirestore(collectionRef: Firestore.firestore().collection("spots"))
    
    var circleQuery: GFSCircleQuery?
    var search: MKLocalSearch?
    let searchFilters: [MKPointOfInterestCategory] = [
        .airport,
        .amusementPark,
        .aquarium,
        .bakery,
        .beach,
        .brewery,
        .cafe,
        .campground,
        .foodMarket,
        .library,
        .marina,
        .museum,
        .movieTheater,
        .nightlife,
        .nationalPark,
        .park,
        .restaurant,
        .store,
        .school,
        .stadium,
        .theater,
        .university,
        .winery,
        .zoo
    ]
    lazy var nearbyEnteredCount = 0
    lazy var noAccessCount = 0
    lazy var nearbyRefreshCount = 0
    lazy var appendCount = 0
    
    lazy var postLocation = CLLocation()
    var delegate: ChooseSpotDelegate?
    unowned var previewVC: ImagePreviewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
        setInitialValues()
        runChooseSpotFetch()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        previewVC?.cancelOnDismiss = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "ChooseSpotOpen")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        /// added to will disappear due to lag when dismissing and quick tapping on ImagePreviewController
        super.viewWillDisappear(animated)
        previewVC?.cancelOnDismiss = false
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    func setUpView() {
        view.backgroundColor = .white
        searchBarContainer = UIView {
            $0.backgroundColor = .white
            view.addSubview($0)
        }
        searchBarContainer.backgroundColor = .white
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
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(searchBarContainer.snp.bottom)
            $0.bottom.equalToSuperview()
        }

        createSpotButton.addTarget(self, action: #selector(createSpotTap(_:)), for: .touchUpInside)
        view.addSubview(createSpotButton)
        createSpotButton.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(60)
            $0.height.equalTo(54)
            $0.width.equalTo(180)
            $0.centerX.equalToSuperview()
        }
    }
    
    func setInitialValues() {
        postLocation = CLLocation(latitude: UploadPostModel.shared.postObject?.postLat ?? 0, longitude: UploadPostModel.shared.postObject?.postLong ?? 0)
        if let spot = UploadPostModel.shared.spotObject { spotObjects.append(spot) }
    }
    
    @objc func createSpotTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "ChooseSpotCreateTap")
        DispatchQueue.main.async {
            self.delegate?.finishPassing(spot: nil)
            self.dismiss(animated: true)
        }
    }
}

extension ChooseSpotController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return spotSearching ? 1 : queried ? querySpots.count : spotObjects.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let current = queried ? querySpots : spotObjects
        
        if indexPath.row < current.count {
            if let cell = tableView.dequeueReusableCell(withIdentifier: "ChooseSpot", for: indexPath) as? ChooseSpotCell {
                cell.setUp(spot: current[indexPath.row])
                return cell
            }
            
        } else {
            /// loading indicator for spot search
            if let cell = tableView.dequeueReusableCell(withIdentifier: "ChooseSpotLoading", for: indexPath) as? ChooseSpotLoadingCell {
                cell.activityIndicator.startAnimating()
                return cell
            }
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 58
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Mixpanel.mainInstance().track(event: "ChooseSpotSelect")
        let current = queried ? querySpots : spotObjects
        let spot = current[indexPath.row]
        DispatchQueue.main.async {
            self.searchBar.resignFirstResponder()
            self.delegate?.finishPassing(spot: spot)
            self.dismiss(animated: true)
        }
    }
}

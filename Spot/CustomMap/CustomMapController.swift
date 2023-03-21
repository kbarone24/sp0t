//
//  CustomMapController.swift
//  Spot
//
//  Created by Kenny Barone on 3/16/23.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Contacts
import Firebase
import MapKit
import Mixpanel
import SDWebImage
import SnapKit
import UIKit
import FirebaseAuth
import FirebaseFirestore

enum MapType {
    case myMap
    case friendsMap
    case customMap
}

class CustomMapController: UIViewController {
    let db = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var endDocument: DocumentSnapshot?
    var refreshStatus: RefreshStatus = .activelyRefreshing
    lazy var activityIndicator = UIActivityIndicatorView()

    var userProfile: UserProfile?
    public var mapData: CustomMap?

    var firstMaxFourMapMemberList: [UserProfile] = []
    lazy var postsList: [MapPost] = []

    var centeredMap = false
    var cancelOnDismiss = false

    let itemWidth: CGFloat = UIScreen.main.bounds.width / 2 - 1
    let itemHeight: CGFloat = (UIScreen.main.bounds.width / 2 - 1) * 1.495
    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.delegate = self
        view.dataSource = self
        view.backgroundColor = .clear
        view.register(CustomMapHeaderCell.self, forCellWithReuseIdentifier: "CustomMapHeaderCell")
        view.register(CustomMapBodyCell.self, forCellWithReuseIdentifier: "CustomMapBodyCell")
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        return view
    }()
    
    lazy var userService: UserServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.userService)
        return service
    }()
    
    lazy var mapPostService: MapPostServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.mapPostService)
        return service
    }()

    lazy var mapService: MapServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.mapsService)
        return service
    }()

    init(userProfile: UserProfile? = nil, mapData: CustomMap?, postsList: [MapPost]) {
        super.init(nibName: nil, bundle: nil)
        self.userProfile = userProfile
        self.postsList = postsList.sorted(by: { $0.timestamp.seconds > $1.timestamp.seconds })
        self.mapData = mapData
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        print("CustomMapController(\(self) deinit")
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewSetup()
        runInitialFetches()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "CustomMapOpen")
        collectionView.isScrollEnabled = true
    }

    private func runInitialFetches() {
        if postsList.isEmpty {
            DispatchQueue.main.async { self.activityIndicator.startAnimating() }
        }
        DispatchQueue.global().async {
            self.getMapInfo()
            self.getPosts()
        }
    }

    private func getMapInfo() {
        // map passed through
        if mapData?.founderID ?? "" != "" {
            getMapMembers()
            return
        }
        
        Task { [weak self] in
            do {
                guard let mapID = self?.mapData?.id else {
                    return
                }
                
                let mapsService = try ServiceContainer.shared.service(for: \.mapsService)
                let map = try await mapsService.getMap(mapID: mapID)
                self?.mapData = map
                self?.getMapMembers()
            } catch {
                return
            }
        }
    }

    private func setUpNavBar() {
        navigationController?.setUpDarkNav(translucent: true)
        navigationItem.title = collectionView.contentOffset.y > 75 ? self.mapData?.mapName : ""

        let barButtonItem = UIBarButtonItem(image: UIImage(named: "SimpleMoreButton"), style: .plain, target: self, action: #selector(moreTap))
        navigationItem.rightBarButtonItem = barButtonItem
    }

    private func viewSetup() {
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostDelete(_:)), name: NSNotification.Name(("DeletePost")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyEditMap(_:)), name: NSNotification.Name(("EditMap")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostOpen(_:)), name: NSNotification.Name(("PostOpen")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostChanged(_:)), name: NSNotification.Name(("PostChanged")), object: nil)

        view.backgroundColor = UIColor(named: "SpotBlack")
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        activityIndicator.isHidden = true
        collectionView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.width.height.equalTo(30)
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-100)
        }
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
    }

    @objc func notifyPostOpen(_ notification: NSNotification) {
        guard let post = notification.userInfo?.first?.value as? MapPost else { return }
        self.mapData?.updateSeen(postID: post.id ?? "")
    }

    @objc func notifyPostDelete(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        guard let spotDelete = notification.userInfo?["spotDelete"] as? Bool else { return }

        postsList.removeAll(where: { $0.id == post.id })
        mapData?.removePost(postID: post.id ?? "", spotID: spotDelete ? post.spotID ?? "" : "")
        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadData()
        }
    }

    @objc func notifyEditMap(_ notification: NSNotification) {
        guard let map = notification.userInfo?["map"] as? CustomMap else { return }
        if map.id == mapData?.id ?? "" {
            mapData = map
            DispatchQueue.main.async { self.collectionView.reloadData() }
            DispatchQueue.global().async { self.getMapMembers() }
        }
    }

    @objc func notifyPostChanged(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        if let i = postsList.firstIndex(where: { $0.id == post.id }) {
            postsList[i].likers = post.likers
            postsList[i].commentList = post.commentList
            postsList[i].commentCount = post.commentCount
        }
    }

    @objc func moreTap() {
        addDetailsActionSheet()
    }
}

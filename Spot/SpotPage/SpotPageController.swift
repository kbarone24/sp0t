//
//  SpotPageController.swift
//  Spot
//
//  Created by Arnold on 8/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFirestore
import Mixpanel
import SDWebImage
import SnapKit
import UIKit

class SpotPageController: UIViewController {
    let itemWidth: CGFloat = UIScreen.main.bounds.width / 2 - 1
    let itemHeight: CGFloat = (UIScreen.main.bounds.width / 2 - 1) * 1.495
    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.showsVerticalScrollIndicator = false
        view.register(SpotPageHeaderCell.self, forCellWithReuseIdentifier: "SpotPageHeaderCell")
        view.register(SpotPageBodyCell.self, forCellWithReuseIdentifier: "SpotPageBodyCell")
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        return view
    }()
    lazy var mapPostService: MapPostServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.mapPostService)
        return service
    }()

    lazy var imageManager = SDWebImageManager()
    lazy var activityIndicator = CustomActivityIndicator()

    var mapID: String?
    var mapName: String?
    var spotName = ""
    var spotID = ""
    var spot: MapSpot? {
        didSet {
            if spot == nil { return }
            DispatchQueue.main.async {
                self.collectionView.reloadSections(IndexSet(integer: 0))
            }
        }
    }
    lazy var postsList: [MapPost] = []
    var endDocument: DocumentSnapshot?
    lazy var refreshStatus: RefreshStatus = .activelyRefreshing

    init(mapPost: MapPost) {
        super.init(nibName: nil, bundle: nil)
        self.mapID = mapPost.mapID
        self.mapName = mapPost.mapName
        self.spotName = mapPost.spotName ?? ""
        self.spotID = mapPost.spotID ?? ""
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        print("SpotPageController(\(self) deinit")
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewSetup()
        DispatchQueue.global(qos: .userInitiated).async {
            self.fetchSpot()
            self.getPosts()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "SpotPageOpen")
    }
}

extension SpotPageController {
    private func setUpNavBar() {
        navigationController?.setUpDarkNav(translucent: true)
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont(name: "SFCompactText-Heavy", size: 19) as Any
        ]

        navigationItem.title = collectionView.contentOffset.y > 40 ? self.spotName : ""
    }

    private func viewSetup() {
        view.backgroundColor = UIColor(named: "SpotBlack")
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostDelete(_:)), name: NSNotification.Name(("DeletePost")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyDrawerViewOffset), name: NSNotification.Name(("DrawerViewOffset")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyDrawerViewReset), name: NSNotification.Name(("DrawerViewReset")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostChanged(_:)), name: NSNotification.Name(rawValue: "PostChanged"), object: nil)


        collectionView.delegate = self
        collectionView.dataSource = self
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.top.equalTo(200)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(30)
        }
    }

    @objc func notifyPostDelete(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        postsList.removeAll(where: { $0.id == post.id })
        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadData()
        }
    }

    @objc func notifyDrawerViewReset() {
        collectionView.isScrollEnabled = true
    }

    @objc func notifyDrawerViewOffset() {
        collectionView.isScrollEnabled = false
    }

    @objc func notifyPostChanged(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        if let i = postsList.firstIndex(where: { $0.id == post.id }) {
            postsList[i].likers = post.likers
            postsList[i].commentList = post.commentList
            postsList[i].commentCount = post.commentCount
        }
    }
}

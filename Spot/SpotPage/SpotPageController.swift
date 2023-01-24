//
//  SpotPageController.swift
//  Spot
//
//  Created by Arnold on 8/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import Mixpanel
import SDWebImage
import SnapKit
import UIKit

class SpotPageController: UIViewController {
    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.register(SpotPageHeaderCell.self, forCellWithReuseIdentifier: "SpotPageHeaderCell")
        view.register(SpotPageBodyCell.self, forCellWithReuseIdentifier: "SpotPageBodyCell")
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        return view
    }()
    lazy var barView = UIView()
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
        label.text = ""
        label.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.sizeToFit()
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    lazy var mapPostService: MapPostServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.mapPostService)
        return service
    }()
    
    lazy var barBackButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "BackArrowDark"), for: .normal)
        return button
    }()

    lazy var mapPostLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = UIFont(name: "SFCompactText-Bold", size: 14)
        label.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
        label.textColor = UIColor(red: 0.587, green: 0.587, blue: 0.587, alpha: 1)
        label.clipsToBounds = true
        label.layer.cornerRadius = 8
        label.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        return label
    }()
    lazy var communityPostLabel: UILabel = {
        let label = UILabel()
        let frontPadding = "    "
        let bottomPadding = "   "
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(named: "CommunityGlobe")
        imageAttachment.bounds = CGRect(x: 0, y: -2.5, width: imageAttachment.image?.size.width ?? 0, height: imageAttachment.image?.size.height ?? 0)
        let attachmentString = NSAttributedString(attachment: imageAttachment)
        let completeText = NSMutableAttributedString(string: frontPadding)
        completeText.append(attachmentString)
        completeText.append(NSAttributedString(string: " "))
        completeText.append(NSAttributedString(string: "Community Posts" + bottomPadding))
        label.attributedText = completeText
        label.font = UIFont(name: "SFCompactText-Bold", size: 14)
        label.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
        label.textColor = UIColor(red: 0.587, green: 0.587, blue: 0.587, alpha: 1)
        label.clipsToBounds = true
        label.layer.cornerRadius = 8
        label.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        return label
    }()
    lazy var imageManager = SDWebImageManager()
    public unowned var containerDrawerView: DrawerView?
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
    var relatedEndDocument: DocumentSnapshot?
    var communityEndDocument: DocumentSnapshot?
    var fetchRelatedPostsComplete = false
    var fetchCommunityPostsComplete = false
    lazy var fetching: RefreshStatus = .activelyRefreshing
    lazy var relatedPosts: [MapPost] = []
    lazy var communityPosts: [MapPost] = []

    init(mapPost: MapPost, presentedDrawerView: DrawerView? = nil) {
        super.init(nibName: nil, bundle: nil)
        self.mapID = mapPost.mapID
        self.mapName = mapPost.mapName
        self.spotName = mapPost.spotName ?? ""
        self.spotID = mapPost.spotID ?? ""
        self.containerDrawerView = presentedDrawerView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        print("SpotPageController(\(self) deinit")
        barView.removeFromSuperview()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewSetup()
        DispatchQueue.global(qos: .userInitiated).async {
            self.fetchSpot()
            self.fetchRelatedPosts()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
        containerDrawerView?.configure(canDrag: false, swipeDownToDismiss: false, startingPosition: .top)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "SpotPageOpen")
    }
}

extension SpotPageController {
    private func setUpNavBar() {
        navigationController?.setNavigationBarHidden(true, animated: true)
        barView.isHidden = false
        collectionView.isScrollEnabled = true
    }

    private func viewSetup() {
        view.backgroundColor = .white
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostDelete(_:)), name: NSNotification.Name(("DeletePost")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyDrawerViewOffset), name: NSNotification.Name(("DrawerViewOffset")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyDrawerViewReset), name: NSNotification.Name(("DrawerViewReset")), object: nil)

        collectionView.delegate = self
        collectionView.dataSource = self
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        containerDrawerView?.slideView.addSubview(barView)
        let height: CGFloat = UserDataModel.shared.screenSize == 0 ? 65 : 90
        barView.snp.makeConstraints {
            $0.leading.top.width.equalToSuperview()
            $0.height.equalTo(height)
        }

        barBackButton.addTarget(self, action: #selector(backButtonAction), for: .touchUpInside)
        barView.addSubview(barBackButton)
        barBackButton.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.bottom.equalTo(-8)
            $0.height.equalTo(21.5)
            $0.width.equalTo(30)
        }

        barView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(60)
            $0.bottom.equalTo(barBackButton)
            $0.height.equalTo(22)
        }

        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.top.equalTo(200)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(30)
        }
    }

    @objc func backButtonAction() {
        Mixpanel.mainInstance().track(event: "SpotPageBackTap")
        containerDrawerView?.closeAction()
    }

    @objc func notifyPostDelete(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        //  guard let spotDelete = notification.userInfo?["spotDelete"] as? Bool else { return }
        //  guard let mapDelete = notification.userInfo?["mapDelete"] as? Bool else { return }

        // check if post being deleted from map controllers child and update map if necessary
        relatedPosts.removeAll(where: { $0.id == post.id })
        communityPosts.removeAll(where: { $0.id == post.id })

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
}

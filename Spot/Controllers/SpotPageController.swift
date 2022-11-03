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

    private var collectionView: UICollectionView!
  ///  private var addButton: UIButton!
    private var barView: UIView!
    private var titleLabel: UILabel!
    private var barBackButton: UIButton!
    private var mapPostLabel: UILabel!
    private var communityPostLabel: UILabel!
    private lazy var imageManager = SDWebImageManager()
    public var containerDrawerView: DrawerView?
    private var activityIndicator: CustomActivityIndicator!

    private var mapID: String?
    private var mapName: String?
    private var spotName: String!
    private var spotID: String!
    private var spot: MapSpot? {
        didSet {
            if spot == nil { return }
            DispatchQueue.main.async {
                self.collectionView.reloadSections(IndexSet(integer: 0))
            }
        }
    }

    private var relatedEndDocument: DocumentSnapshot?
    private var communityEndDocument: DocumentSnapshot?
    private var fetchRelatedPostsComplete = false
    private var fetchCommunityPostsComplete = false
    private var fetching: RefreshStatus = .activelyRefreshing
    private var relatedPosts: [MapPost] = []
    private var communityPosts: [MapPost] = []

    init(mapPost: MapPost, presentedDrawerView: DrawerView? = nil) {
        super.init(nibName: nil, bundle: nil)
        self.mapID = mapPost.mapID
        self.mapName = mapPost.mapName
        self.spotName = mapPost.spotName
        self.spotID = mapPost.spotID
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
        setUpNavBar()
        configureDrawerView()
    }

    override func viewDidAppear(_ animated: Bool) {
        Mixpanel.mainInstance().track(event: "SpotPageOpen")
    }
}

extension SpotPageController {
    private func setUpNavBar() {
        navigationController?.setNavigationBarHidden(true, animated: true)
        barView.isHidden = false
    }

    private func configureDrawerView() {
        containerDrawerView?.canInteract = false
        containerDrawerView?.swipeDownToDismiss = false
        containerDrawerView?.showCloseButton = false
        containerDrawerView?.present(to: .top)
    }

    private func viewSetup() {
        view.backgroundColor = .white
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostDelete(_:)), name: NSNotification.Name(("DeletePost")), object: nil)

        collectionView = {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .vertical
            let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
            view.delegate = self
            view.dataSource = self
            view.backgroundColor = .clear
            view.register(SpotPageHeaderCell.self, forCellWithReuseIdentifier: "SpotPageHeaderCell")
            view.register(SpotPageBodyCell.self, forCellWithReuseIdentifier: "SpotPageBodyCell")
            view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
            return view
        }()
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

      /* addButton = AddButton {
            $0.addTarget(self, action: #selector(addAction), for: .touchUpInside)
            $0.isHidden = true
            view.addSubview($0)
        }
        addButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(24)
            $0.bottom.equalToSuperview().inset(35)
            $0.width.height.equalTo(73)
        } */

        barView = UIView {
            $0.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 91)
            containerDrawerView?.slideView.addSubview($0)
        }
        let height: CGFloat = UserDataModel.shared.screenSize == 0 ? 65 : 90
        barView.snp.makeConstraints {
            $0.leading.top.width.equalToSuperview()
            $0.height.equalTo(height)
        }

        barBackButton = UIButton {
            $0.setImage(UIImage(named: "BackArrowDark"), for: .normal)
            $0.addTarget(self, action: #selector(backButtonAction), for: .touchUpInside)
            barView.addSubview($0)
        }
        barBackButton.snp.makeConstraints {
            $0.leading.equalTo(22)
            $0.bottom.equalTo(-12)
            $0.height.equalTo(21.5)
            $0.width.equalTo(30)
        }

        titleLabel = UILabel {
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
            $0.text = ""
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            $0.textAlignment = .center
            $0.numberOfLines = 0
            $0.sizeToFit()
            $0.adjustsFontSizeToFitWidth = true
            barView.addSubview($0)
        }
        titleLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(60)
            $0.bottom.equalTo(barBackButton)
            $0.height.equalTo(22)
        }

        mapPostLabel = UILabel {
            $0.text = ""
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            $0.textColor = UIColor(red: 0.587, green: 0.587, blue: 0.587, alpha: 1)
            $0.clipsToBounds = true
            $0.layer.cornerRadius = 8
            $0.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        }

        communityPostLabel = UILabel {
            let frontPadding = "    "
            let bottomPadding = "   "
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = UIImage(named: "CommunityGlobe")
            imageAttachment.bounds = CGRect(x: 0, y: -2.5, width: imageAttachment.image!.size.width, height: imageAttachment.image!.size.height)
            let attachmentString = NSAttributedString(attachment: imageAttachment)
            let completeText = NSMutableAttributedString(string: frontPadding)
            completeText.append(attachmentString)
            completeText.append(NSAttributedString(string: " "))
            completeText.append(NSAttributedString(string: "Community Posts" + bottomPadding))
            $0.attributedText = completeText
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            $0.textColor = UIColor(red: 0.587, green: 0.587, blue: 0.587, alpha: 1)
            $0.clipsToBounds = true
            $0.layer.cornerRadius = 8
            $0.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        }

        activityIndicator = CustomActivityIndicator {
            $0.startAnimating()
            view.addSubview($0)
        }
        activityIndicator.snp.makeConstraints {
            $0.top.equalTo(200)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(30)
        }
    }

    private func fetchSpot() {
        let db: Firestore = Firestore.firestore()
        db.collection("spots").document(spotID).getDocument { [weak self] snap, _ in
            do {
                guard let self = self else { return }
                let unwrappedInfo = try snap?.data(as: MapSpot.self)
                guard let userInfo = unwrappedInfo else { return }
                self.spot = userInfo
            } catch let parseError {
                print("JSON Error \(parseError.localizedDescription)")
            }
        }
    }

    private func fetchRelatedPosts() {
        let db: Firestore = Firestore.firestore()
        let baseQuery = db.collection("posts").whereField("spotID", isEqualTo: spotID!)
        let conditionedQuery = (mapID == nil || mapID == "") ? baseQuery.whereField("friendsList", arrayContains: UserDataModel.shared.uid) : baseQuery.whereField("mapID", isEqualTo: mapID!)
        var finalQuery = conditionedQuery.limit(to: 13).order(by: "timestamp", descending: true)
        if relatedEndDocument != nil { finalQuery = finalQuery.start(atDocument: relatedEndDocument!)  }

        fetching = .activelyRefreshing
        finalQuery.getDocuments { [weak self ](snap, _) in
            guard let self = self else { return }
            guard let allDocs = snap?.documents else { return }

            let docs = allDocs.count == 13 ? allDocs.dropLast() : allDocs
            let postGroup = DispatchGroup()
            for doc in docs {
                do {
                    let unwrappedInfo = try doc.data(as: MapPost.self)
                    guard let postInfo = unwrappedInfo else { continue }
                    if self.relatedPosts.contains(where: { $0.id == postInfo.id }) { continue }
                    postGroup.enter()
                    self.setPostDetails(post: postInfo) { [weak self] post in
                        guard let self = self else { return }
                        self.addRelatedPost(postInfo: post)
                        postGroup.leave()
                    }
                } catch let parseError {
                    print("JSON Error \(parseError.localizedDescription)")
                }
            }

            postGroup.notify(queue: .main) {
                self.activityIndicator.stopAnimating()
                self.relatedEndDocument = allDocs.last
                self.fetchRelatedPostsComplete = docs.count < 12
                self.fetching = .refreshEnabled
                if docs.count < 12 { self.fetchCommunityPost() }

                self.relatedPosts.sort(by: { $0.seconds > $1.seconds })
                self.collectionView.reloadData()
            }
        }
    }

    private func fetchCommunityPost() {
        let db: Firestore = Firestore.firestore()
        let baseQuery = db.collection("posts").whereField("spotID", isEqualTo: spotID!)
        var finalQuery = baseQuery.limit(to: 13).order(by: "timestamp", descending: true)
        if communityEndDocument != nil { finalQuery = finalQuery.start(atDocument: communityEndDocument!) }

        fetching = .activelyRefreshing
        finalQuery.getDocuments { [weak self] (snap, _) in
            guard let self = self else { return }
            guard let allDocs = snap?.documents else { return }
            if allDocs.count == 0 { self.fetching = .refreshDisabled }
            let docs = allDocs.count == 13 ? allDocs.dropLast() : allDocs
            if docs.count < 12 { self.fetching = .refreshDisabled }

            let postGroup = DispatchGroup()
            for doc in snap!.documents {
                do {
                    let unwrappedInfo = try doc.data(as: MapPost.self)
                    guard let postInfo = unwrappedInfo else { continue }
                    if self.relatedPosts.contains(where: { $0.id == postInfo.id }) { continue }

                    postGroup.enter()
                    self.setPostDetails(post: postInfo) { [weak self] post in
                        guard let self = self else { return }
                        self.addCommunityPost(postInfo: post)
                        postGroup.leave()
                    }
                } catch let parseError {
                    print("JSON Error \(parseError.localizedDescription)")
                }
            }

            postGroup.notify(queue: .main) {
                self.activityIndicator.stopAnimating()
                if self.fetching == .refreshDisabled {
                    self.fetchCommunityPostsComplete = true
                } else {
                    self.fetching = .refreshEnabled
                }

                self.communityEndDocument = allDocs.last
                self.relatedPosts.sort(by: { $0.seconds > $1.seconds })
                self.communityPosts.sort(by: { $0.seconds > $1.seconds })
                self.collectionView.reloadData()
            }
        }
    }

    func addRelatedPost(postInfo: MapPost) {
        if !hasPostAccess(post: postInfo) { return }
        if !relatedPosts.contains(where: { $0.id == postInfo.id }) { relatedPosts.append(postInfo) }
    }

    func addCommunityPost(postInfo: MapPost) {
        if !hasPostAccess(post: postInfo) { return }
        // (Map Posts) Check if mapID exist and append MapPost that belongs to different maps into community posts
        // (Friend Posts) Check if related posts doesn't contain MapPost ID and append MapPost to community posts
        if mapID != "" && postInfo.mapID == mapID {
            if !relatedPosts.contains(where: { $0.id == postInfo.id }) { relatedPosts.append(postInfo) }
        } else if mapID == "" {
            if !relatedPosts.contains(where: { $0.id == postInfo.id }) { relatedPosts.append(postInfo) }
        } else {
            if !communityPosts.contains(where: { $0.id == postInfo.id }) { communityPosts.append(postInfo) }
        }
    }

    func hasPostAccess(post: MapPost) -> Bool {
        /// show all posts except secret map posts from secret maps. Allow friends level access for posts posted to friends feed, invite level access for posts hidden from friends feed / myMap
        if post.privacyLevel == "invite" {
            if post.hideFromFeed ?? false {
                return (post.inviteList?.contains(UserDataModel.shared.uid)) ?? false
            } else {
                return UserDataModel.shared.userInfo.friendIDs.contains(post.posterID) || UserDataModel.shared.uid == post.posterID
            }
        }
        return true
    }

    @objc func backButtonAction() {
        Mixpanel.mainInstance().track(event: "SpotPageBackTap")
        containerDrawerView?.closeAction()
    }

    @objc func notifyPostDelete(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
    //    guard let spotDelete = notification.userInfo?["spotDelete"] as? Bool else { return }
      //  guard let mapDelete = notification.userInfo?["mapDelete"] as? Bool else { return }

        /// check if post being deleted from map controllers child and update map if necessary
        relatedPosts.removeAll(where: { $0.id == post.id })
        communityPosts.removeAll(where: { $0.id == post.id })

        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadData()
        }
    }
}

extension SpotPageController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 3
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return relatedPosts.count
        case 2:
            return communityPosts.count
        default:
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: indexPath.section == 0 ? "SpotPageHeaderCell" : "SpotPageBodyCell", for: indexPath)
        if let headerCell = cell as? SpotPageHeaderCell {
            headerCell.cellSetup(spotName: spotName, spot: spot)
            return headerCell
        } else if let bodyCell = cell as? SpotPageBodyCell {
            // Setup map post label
            if indexPath == IndexPath(row: 0, section: 1) {
                let frontPadding = "    "
                let bottomPadding = "   "
                mapPostLabel.text = frontPadding + ((mapName == nil || mapName == "") ? "Friends posts" : "\(mapName!)") + bottomPadding
                addHeaderView(label: mapPostLabel, cell: cell, communityEmpty: false)
            }
            /// set up community post label
            if communityPosts.count != 0 {
                if indexPath == IndexPath(row: 0, section: 2) {
                    addHeaderView(label: communityPostLabel, cell: cell, communityEmpty: false)
                }
            } else if fetchCommunityPostsComplete {
                if indexPath == IndexPath(row: relatedPosts.count - 1, section: 1) {
                    addHeaderView(label: communityPostLabel, cell: cell, communityEmpty: true)
                }
            }

            bodyCell.cellSetup(mapPost: indexPath.section == 1 ? relatedPosts[indexPath.row] : communityPosts[indexPath.row])

            return bodyCell
        }
        return cell
    }

    func addHeaderView(label: UILabel, cell: UICollectionViewCell, communityEmpty: Bool) {
        if !collectionView.subviews.contains(label) { collectionView.addSubview(label) }
        label.snp.removeConstraints()
        label.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.height.equalTo(31)
            if !communityEmpty {
                $0.top.equalToSuperview().offset(cell.frame.minY - 15.5)
            } else {
                $0.bottom.equalToSuperview().offset(cell.frame.maxY + 15.5)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return indexPath.section == 0 ? CGSize(width: view.frame.width, height: 130) : CGSize(width: view.frame.width / 2 - 0.5, height: (view.frame.width / 2 - 0.5) * 267 / 194.5)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section != 0 {
            Mixpanel.mainInstance().track(event: "SpotPageGalleryPostTap")
            let collectionCell = collectionView.cellForItem(at: indexPath)
            UIView.animate(withDuration: 0.15) {
                collectionCell?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            } completion: { (_) in
                UIView.animate(withDuration: 0.15) {
                    collectionCell?.transform = .identity
                }
            }
            guard let postVC = UIStoryboard(name: "Feed", bundle: nil).instantiateViewController(identifier: "Post") as? PostController else { return }
            postVC.postsList = indexPath.section == 1 ? relatedPosts : communityPosts
            postVC.selectedPostIndex = indexPath.item
            postVC.containerDrawerView = containerDrawerView
            barView.isHidden = true
            self.navigationController!.pushViewController(postVC, animated: true)
        }
    }
}

extension SpotPageController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y > -91 {
            barView.backgroundColor = scrollView.contentOffset.y > 0 ? .white : .clear
            titleLabel.text = scrollView.contentOffset.y > 0 ? spotName : ""
        }

        if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height - 500)) && fetching == .refreshEnabled {
            DispatchQueue.global(qos: .userInitiated).async {
                print("fetch")
                self.fetchRelatedPostsComplete ? self.fetchCommunityPost() : self.fetchRelatedPosts()
            }
        }
    }
}

//
//  SpotPageController.swift
//  Spot
//
//  Created by Arnold on 8/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SnapKit
import Mixpanel
import Firebase
import SDWebImage

class SpotPageController: UIViewController {

    private var spotPageCollectionView: UICollectionView!
    private var addSpotButton: UIButton!
    private var barView: UIView!
    private var titleLabel: UILabel!
    private var barBackButton: UIButton!
    private var mapPostLabel: UILabel!
    private var communityPostLabel: UILabel!
    private lazy var imageManager = SDWebImageManager()
    private var drawerView: DrawerView?
    
    private var mapID: String?
    private var mapName: String?
    private var spotName: String!
    private var spotID: String!
    private var spot: MapSpot? {
        didSet {
            DispatchQueue.main.async {
                self.spotPageCollectionView.reloadSections(IndexSet(integer: 0))
            }
        }
    }
        
    private var endDocument: DocumentSnapshot?
    private var fetchRelatedPostComplete = false
    private var fetchCommunityPostComplete = false
    private var fetching: RefreshStatus = .refreshEnabled
    private var relatedPost: [MapPost] = []
    private var communityPost: [MapPost] = []
    
    
    init(mapPost: MapPost, presentedDrawerView: DrawerView? = nil) {
        super.init(nibName: nil, bundle: nil)
        self.mapID = mapPost.mapID
        self.mapName = mapPost.mapName
        self.spotName = mapPost.spotName
        self.spotID = mapPost.spotID
        self.drawerView = presentedDrawerView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("SpotPageController(\(self) deinit")
        barView.removeFromSuperview()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewSetup()
        DispatchQueue.global(qos: .userInitiated).async {
            self.fetchSpot()
            self.fetchRelatedPost()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        barView.isHidden = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        Mixpanel.mainInstance().track(event: "SpotPageOpen")
    }
}

extension SpotPageController {
    private func viewSetup() {
        view.backgroundColor = .white
        navigationController?.setNavigationBarHidden(true, animated: true)

        spotPageCollectionView = {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .vertical
            let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
            view.delegate = self
            view.dataSource = self
            view.backgroundColor = .clear
            view.register(SpotPageHeaderCell.self, forCellWithReuseIdentifier: "SpotPageHeaderCell")
            view.register(SpotPageBodyCell.self, forCellWithReuseIdentifier: "SpotPageBodyCell")
            return view
        }()
        view.addSubview(spotPageCollectionView)
        spotPageCollectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        addSpotButton = UIButton {
            $0.layer.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.25).cgColor
            $0.layer.shadowOpacity = 1
            $0.layer.shadowRadius = 8
            $0.layer.shadowOffset = CGSize(width: 0, height: 0.5)
            $0.setImage(UIImage(named: "AddToSpotButton"), for: .normal)
            $0.setTitle("", for: .normal)
            $0.addTarget(self, action: #selector(addSpotAction), for: .touchUpInside)
            view.addSubview($0)
        }
        addSpotButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(24)
            $0.bottom.equalToSuperview().inset(35)
            $0.width.height.equalTo(73)
        }
        
        barView = UIView {
            $0.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 91)
            $0.backgroundColor = .gray
            drawerView?.slideView.addSubview($0)
        }
        titleLabel = UILabel {
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
            $0.text = ""
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            $0.textAlignment = .center
            $0.numberOfLines = 0
            $0.sizeToFit()
            $0.frame = CGRect(origin: CGPoint(x: 0, y: 55), size: CGSize(width: view.frame.width, height: 18))
            barView.addSubview($0)
        }
        barBackButton = UIButton {
            $0.setImage(UIImage(named: "BackArrow-1"), for: .normal)
            $0.setTitle("", for: .normal)
            $0.addTarget(self, action: #selector(backButtonAction), for: .touchUpInside)
            barView.addSubview($0)
        }
        barBackButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(22)
            $0.centerY.equalTo(titleLabel)
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
            completeText.append(NSAttributedString(string: "Community Post" + bottomPadding))
            $0.attributedText = completeText
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            $0.textColor = UIColor(red: 0.587, green: 0.587, blue: 0.587, alpha: 1)
            $0.clipsToBounds = true
            $0.layer.cornerRadius = 8
            $0.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        }
    }
    
    private func fetchSpot() {
        let db: Firestore = Firestore.firestore()
        db.collection("spots").document(spotID).getDocument { [weak self] snap, err in
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
    
    private func fetchRelatedPost() {
        guard fetching == .refreshEnabled else { return }
        let db: Firestore = Firestore.firestore()
        let baseQuery = db.collection("posts").whereField("spotID", isEqualTo: spotID!)
        let conditionedQuery = (mapID == nil || mapID == "") ? baseQuery.whereField("friendsList", arrayContains: UserDataModel.shared.uid) : baseQuery.whereField("mapID", isEqualTo: mapID!)
        var finalQuery = conditionedQuery.limit(to: 12).order(by: "timestamp", descending: true)
        if endDocument != nil {
            finalQuery = finalQuery.start(atDocument: endDocument!)
        }
        fetching = .activelyRefreshing
        finalQuery.getDocuments { (snap, err) in
            guard err == nil else { self.fetching = .refreshEnabled; return }
            for doc in snap!.documents {
                do {
                    let unwrappedInfo = try doc.data(as: MapPost.self)
                    guard let postInfo = unwrappedInfo else { self.fetching = .refreshEnabled; return }
                    self.relatedPost.append(postInfo)
                } catch let parseError {
                    print("JSON Error \(parseError.localizedDescription)")
                }
            }
            if snap!.documents.count < 12 {
                self.endDocument = nil
                self.fetchRelatedPostComplete = true
                self.fetching = .refreshDisabled
                self.fetchCommunityPost(12 - snap!.documents.count)
                print("Related post fetch completed")
            } else {
                self.endDocument = snap?.documents.last
                self.fetching = .refreshEnabled
            }
            DispatchQueue.main.async {
                self.spotPageCollectionView.reloadSections(IndexSet(integer: 1))
            }
        }
    }
    
    private func fetchCommunityPost(_ number: Int = 12) {
        guard fetching != .activelyRefreshing else { return }
        let db: Firestore = Firestore.firestore()
        var mustFilter = false
        var baseQuery = db.collection("posts").whereField("spotID", isEqualTo: spotID!)
        if (mapID == nil || mapID == "") == false {
            baseQuery = baseQuery.whereField("mapID", isNotEqualTo: mapID!)
        } else {
            mustFilter = true
        }
        var finalQuery = baseQuery.limit(to: number).order(by: "timestamp", descending: true)
        if endDocument != nil {
            finalQuery = finalQuery.start(atDocument: endDocument!)
        }
        fetching = .activelyRefreshing
        finalQuery.getDocuments { (snap, err) in
            guard err == nil else { self.fetching = .refreshEnabled; return }
            for doc in snap!.documents {
                do {
                    let unwrappedInfo = try doc.data(as: MapPost.self)
                    guard let postInfo = unwrappedInfo else { self.fetching = .refreshEnabled; return }
                    if mustFilter {
                        if self.relatedPost.contains(where: { mapPost in
                            mapPost.id == postInfo.id
                        }) == false {
                            self.communityPost.append(postInfo)
                        }
                    } else {
                        self.communityPost.append(postInfo)
                    }

                } catch let parseError {
                    print("JSON Error \(parseError.localizedDescription)")
                }
            }
            self.endDocument = snap!.documents.count < 12 ? nil : snap?.documents.last
            if snap!.documents.count < 12 {
                self.fetchCommunityPostComplete = true
                print("Community post fetch completed")
            }
            self.fetching = .refreshEnabled
            DispatchQueue.main.async {
                self.spotPageCollectionView.reloadSections(IndexSet(integer: 2))
            }
        }
    }
    
    @objc func addSpotAction() {
        if navigationController!.viewControllers.contains(where: {$0 is AVCameraController}) { return } /// crash on double stack was happening here
        DispatchQueue.main.async {
            if let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(identifier: "AVCameraController") as? AVCameraController {
                let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.rootViewController ?? UIViewController()
                if let mainNav = window as? UINavigationController {
                    if let mapVC = mainNav.viewControllers[0] as? MapController {
                        vc.mapVC = mapVC
                    } else {
                        return
                    }
                } else {
                    return
                }
                self.barView.isHidden = true
                let transition = CATransition()
                transition.duration = 0.3
                transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                transition.type = CATransitionType.push
                transition.subtype = CATransitionSubtype.fromTop
                self.navigationController?.view.layer.add(transition, forKey: kCATransition)
                self.navigationController?.pushViewController(vc, animated: false)
            }
        }
    }
    
    @objc func backButtonAction() {
        navigationController?.popViewController(animated: true)
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
            return relatedPost.count
        case 2:
            return communityPost.count
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
            if indexPath == IndexPath(row: 0, section: 1) && view.subviews.contains(mapPostLabel) == false {
                collectionView.addSubview(mapPostLabel)
                let frontPadding = "    "
                let bottomPadding = "   "
                mapPostLabel.text = frontPadding + ((mapName == nil || mapName == "") ? "Friends posts" : "\(mapName!)") + bottomPadding
                mapPostLabel.snp.makeConstraints {
                    $0.leading.equalToSuperview()
                    $0.top.equalToSuperview().offset(cell.frame.minY - 15.5)
                    $0.height.equalTo(31)
                }
            }
            // Setup community post label
            if communityPost.count != 0 {
                if indexPath == IndexPath(row: 0, section: 2) && view.subviews.contains(communityPostLabel) == false {
                    collectionView.addSubview(communityPostLabel)
                    communityPostLabel.snp.makeConstraints {
                        $0.leading.equalToSuperview()
                        $0.top.equalToSuperview().offset(cell.frame.minY - 15.5)
                        $0.height.equalTo(31)
                    }
                }
            } else {
                if indexPath == IndexPath(row: relatedPost.count - 1, section: 1) && view.subviews.contains(communityPostLabel) == false {
                    collectionView.addSubview(communityPostLabel)
                    communityPostLabel.snp.makeConstraints {
                        $0.leading.equalToSuperview()
                        $0.top.equalToSuperview().offset(cell.frame.maxY - 15.5)
                        $0.height.equalTo(31)
                    }
                }
            }
            
            bodyCell.cellSetup(mapPost: indexPath.section == 1 ? relatedPost[indexPath.row] : communityPost[indexPath.row])
                        
            return bodyCell
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return indexPath.section == 0 ? CGSize(width: view.frame.width, height: 130) : CGSize(width: view.frame.width/2 - 0.5, height: (view.frame.width/2 - 0.5) * 267 / 194.5)
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
            let collectionCell = collectionView.cellForItem(at: indexPath)
            UIView.animate(withDuration: 0.15) {
                collectionCell?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            } completion: { (Bool) in
                UIView.animate(withDuration: 0.15) {
                    collectionCell?.transform = .identity
                }
            }
        }
    }
}

extension SpotPageController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y > -91 {
            barView.backgroundColor = scrollView.contentOffset.y > 0 ? .white : .clear
            titleLabel.text = scrollView.contentOffset.y > 0 ? spotName : ""
        }
        
        if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height - 500)) && fetching == .refreshEnabled && fetchCommunityPostComplete == false {
            DispatchQueue.global(qos: .userInitiated).async {
                self.fetchRelatedPostComplete ? self.fetchCommunityPost() : self.fetchRelatedPost()
            }
        }
    }
}

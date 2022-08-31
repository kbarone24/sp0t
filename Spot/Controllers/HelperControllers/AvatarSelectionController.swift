//
//  FriendRequestCollectionCell.swift
//  Spot
//
//  Created by Shay Gyawali on 6/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel


class AvatarSelectionController: UIViewController {
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var avatars: [String] = ["Bear", "Bunny", "Cow", "Deer", "Dog", "Elephant", "Giraffe", "Lion", "Monkey", "Panda", "Pig", "Tiger"].shuffled()
    var friendRequests: [UserNotification] = []

    private let myCollectionViewFlowLayout = MyCollectionViewFlowLayout()
    var collectionView: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewLayout.init())
    var centerCell: AvatarCell!
    
    var centerAvi = CGPoint(x: 0.0, y: 0.0)
    var sentFrom: SentFrom!

    enum SentFrom {
        case create
        case map
        case edit
    }

    var onDoneBlock : ((String, String) -> Void)?

    init(sentFrom: SentFrom) {
        super.init(nibName: nil, bundle: nil)
        self.sentFrom = sentFrom
        if sentFrom == .edit {
            navigationItem.hidesBackButton = false
            for i in 0..<(avatars.count) {
                let userAvatarURL = UserDataModel.shared.userInfo.avatarURL ?? ""
                let url = AvatarURLs.shared.getURL(name: avatars[i])
                if userAvatarURL == url {
                    avatars.swapAt(i, 5)
                }
            }
        } else {
            navigationItem.hidesBackButton = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setUp()
        DispatchQueue.main.async { self.collectionView.scrollToItem(at:IndexPath(item: 5, section: 0), at: .centeredHorizontally, animated: false) }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async {
            if (self.centerCell != (self.collectionView.cellForItem(at: IndexPath(item: 5, section: 0)) as! AvatarCell)){
                    self.centerCell = (self.collectionView.cellForItem(at: IndexPath(item: 5, section: 0)) as! AvatarCell)
                self.centerCell?.transformToLarge()
            }
        }
        
        
        let layoutMargins: CGFloat = self.collectionView.layoutMargins.left + self.collectionView.layoutMargins.left
        let sideInset = (self.view.frame.width / 2) - layoutMargins
        self.collectionView.contentInset = UIEdgeInsets(top: 0, left: sideInset, bottom: 0, right: sideInset)
    }
    
    func setUpFriendRequests(friendRequests: [UserNotification]){
        self.friendRequests = friendRequests
    }
    
    func setUp() {
        ///hardcode cell height in case its laid out before view fully appears -> hard code body height so mask stays with cell change
        resetCell()
        
        let title = UILabel {
            $0.text = "Choose your avatar"
            $0.font = UIFont(name: "SFCompactText-Bold", size: 18)
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            view.addSubview($0)
        }
        title.snp.makeConstraints{
          $0.top.equalToSuperview().offset(138)
          $0.centerX.equalToSuperview()
        }
        
        let subTitle = UILabel {
            $0.text = "This is how you'll be displayed on the map"
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 14)
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            view.addSubview($0)
        }
        subTitle.snp.makeConstraints{
            $0.top.equalTo(title.snp.bottom).offset(9.05)
            $0.centerX.equalToSuperview()
        }
        
        //acts up if I set up the view using the other style
        collectionView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 189)
        collectionView.backgroundColor = .white
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = true
        collectionView.allowsSelection = true
        collectionView.collectionViewLayout = self.myCollectionViewFlowLayout
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(AvatarCell.self, forCellWithReuseIdentifier: "AvatarCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = true
        view.addSubview(collectionView)
        
        collectionView.snp.makeConstraints{
            $0.top.equalTo(subTitle.snp.bottom).offset(16)
            $0.width.equalToSuperview()
            $0.height.equalTo(95)
        }
        
        let selectButton = UIButton {
            $0.layer.cornerRadius = 15
            $0.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            var customButtonTitle = NSMutableAttributedString()
            if sentFrom == .create {
                customButtonTitle = NSMutableAttributedString(string: "Create account", attributes: [
                    NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15)!,
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ])
            } else {
                customButtonTitle = NSMutableAttributedString(string: "Select", attributes: [
                    NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15)!,
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ])
            }
            $0.setAttributedTitle(customButtonTitle, for: .normal)
            $0.setImage(nil, for: .normal)
            $0.addTarget(self, action: #selector(selectedTap(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        selectButton.snp.makeConstraints{
            $0.leading.trailing.equalToSuperview().inset(78)
            $0.height.equalTo(52)
            $0.top.equalTo(collectionView.snp.bottom).offset(50)
        }
        
        if sentFrom == .edit {
            let backButton = UIButton {
                $0.setTitle("Cancel", for: .normal)
                $0.setTitleColor(UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1), for: .normal)
                $0.titleLabel?.font = UIFont(name: "SFCompactText-Medium", size: 14)
                $0.addTarget(self, action: #selector(dismissAction), for: .touchUpInside)
                view.addSubview($0)
            }
            backButton.snp.makeConstraints {
                $0.leading.equalToSuperview().offset(22)
                $0.top.equalToSuperview().offset(60)
            }
        }
    }
    
    @objc func dismissAction(_ sender: UIButton){
        Mixpanel.mainInstance().track(event: "AvatarSelectionDismiss")
        self.presentingViewController?.dismiss(animated: false, completion:nil)
    }
    
    func resetCell() {
        collectionView.removeFromSuperview()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView){
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.collectionView.layoutSubviews()
        }

        guard scrollView is UICollectionView else {
            return}
        ///finding cell at the center
        //let center = self.view.convert(self.collectionView.center, to: self.collectionView)

        DispatchQueue.main.async { [self] in
            let center = self.view.convert(self.collectionView.center, to: self.collectionView)
            if let indexPath = self.collectionView.indexPathForItem(at: center){
                Mixpanel.mainInstance().track(event: "AvatarSelectionScrollNewAvatar")
                self.centerCell = (self.collectionView.cellForItem(at: indexPath) as! AvatarCell)
                self.centerCell?.transformToLarge()
            }
        }

    }
    
    
    func transformToStandard(){
        self.centerCell.avatarImage?.alpha = 1.0
        self.centerCell.avatarImage?.snp.updateConstraints{
            $0.height.equalTo(72.8)
            $0.width.equalTo(50)
        }
    }
    
    @objc func selectedTap(_ sender: UIButton){
        Mixpanel.mainInstance().track(event: "AvatarSelectionSelectTap")
        let avatarURL = AvatarURLs().getURL(name: centerCell.avatar!)
        if sentFrom != .edit {
            UserDataModel.shared.userInfo.avatarURL = avatarURL
            UserDataModel.shared.userInfo.avatarPic = UIImage(named: centerCell.avatar!)!
            let db = Firestore.firestore()
            db.collection("users").document(uid).updateData(["avatarURL": avatarURL])
        }
                
        if sentFrom == .map {
            self.navigationController!.popViewController(animated: true)
        } else if sentFrom == .create {
            let storyboard = UIStoryboard(name: "Map", bundle: nil)
             let vc = storyboard.instantiateViewController(withIdentifier: "MapVC") as! MapController
             let navController = UINavigationController(rootViewController: vc)
             navController.modalPresentationStyle = .fullScreen
             
             let keyWindow = UIApplication.shared.connectedScenes
                 .filter({$0.activationState == .foregroundActive})
                 .map({$0 as? UIWindowScene})
                 .compactMap({$0})
                 .first?.windows
                 .filter({$0.isKeyWindow}).first
             keyWindow?.rootViewController = navController
        } else {
            onDoneBlock!(avatarURL, centerCell.avatar!)
            self.presentingViewController?.dismiss(animated: false, completion:nil)
        }
    }
}



// MARK: delegate and data source protocol
extension AvatarSelectionController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 12
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AvatarCell", for: indexPath) as? AvatarCell else { return UICollectionViewCell() }
        cell.setUp(avatar: avatars[indexPath.row])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        Mixpanel.mainInstance().track(event: "AvatarSelectionTapNewAvatar")
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .left)
    }
}


final class MyCollectionViewFlowLayout: UICollectionViewFlowLayout {
    
    override func prepare() {
        super.prepare()
        scrollDirection = .horizontal
        minimumInteritemSpacing = 15
        itemSize = CGSize(width: 64, height: 91.4)
        //sectionInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        //snap to center
        var offsetAdjustment = CGFloat.greatestFiniteMagnitude
        let horizontalOffset = proposedContentOffset.x + collectionView!.contentInset.left
        let targetRect = CGRect(x: proposedContentOffset.x, y: 0, width: collectionView!.bounds.size.width, height: collectionView!.bounds.size.height)
        let layoutAttributesArray = super.layoutAttributesForElements(in: targetRect)
        layoutAttributesArray?.forEach({ (layoutAttributes) in
            let itemOffset = layoutAttributes.frame.origin.x
            if fabsf(Float(itemOffset - horizontalOffset)) < fabsf(Float(offsetAdjustment)) {
                offsetAdjustment = itemOffset - horizontalOffset
            }
        })
        return CGPoint(x: proposedContentOffset.x + offsetAdjustment + 10, y: proposedContentOffset.y)
    }
}

// MARK: avatar cell
class AvatarCell: UICollectionViewCell {
    var avatar: String?
    var avatarImage: UIImageView!
    var scaled = false
        
    // variables for activity indicator that will be used later
    lazy var activityIndicator = UIActivityIndicatorView()
    var globalRow = 0
    
    var directionUp = true
    var animationIndex = 0
        
    override init(frame: CGRect) {
        super.init(frame: frame)
       // initialize what is needed
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    func setUp(avatar: String) {
        resetCell()
        self.avatar = avatar
                 
        avatarImage = UIImageView {
            $0.alpha = 0.5
            $0.contentMode = .scaleToFill
            $0.image = UIImage(named: avatar)
            contentView.addSubview($0)
        }
        avatarImage?.snp.makeConstraints{
            $0.centerY.equalToSuperview()
            //bunny is small so need to make a little bigger
            if(avatar == "bunny"){
                $0.width.equalTo(55)
                $0.height.equalTo(77.08)
            } else {
                $0.width.equalTo(50)
                $0.height.equalTo(72.08)
            }
            $0.centerX.equalToSuperview()
        }
    }
    
    func transformToLarge(){
        self.scaled = true
        UIView.animate(withDuration: 0.1){
            self.avatarImage?.snp.updateConstraints{
                $0.height.equalTo(89.4)
                $0.width.equalTo(62)
            }
        }
        self.avatarImage?.alpha = 1.0
     }
        
    func resetCell() {
        if self.contentView.subviews.isEmpty == false {
            for subview in self.contentView.subviews {
                subview.removeFromSuperview()
            }
        }
    }
}
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


class AvatarSelectionController: UIViewController {
    
    weak var notificationControllerDelegate: notificationDelegateProtocol?
    
    private let myCollectionViewFlowLayout = MyCollectionViewFlowLayout()
    
    var itemHeight, itemWidth: CGFloat!

    var friendRequests: [UserNotification] = []
    
    var collectionView: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewLayout.init())
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    
    var centerCell: AvatarCell!
    
    var avatars: [String] = ["Bear", "Bunny", "Cow", "Deer", "Dog", "Elephant", "Giraffe", "Lion", "Monkey", "Panda", "Pig", "Tiger"].shuffled()
    
    var centerAvi = CGPoint(x: 0.0, y: 0.0)
    
    var from: String!

    init(sentFrom: String){
        super.init(nibName: nil, bundle: nil)
        from = sentFrom
        print("SENT FROM : ", from)
        print("URL 🔗 2: ", UserDataModel.shared.userInfo.avatarURL)
        if(from == "map"){
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
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        collectionView.scrollToItem(at:IndexPath(item: 5, section: 0), at: .centeredHorizontally, animated: false)
        centerAvi = self.view.convert(self.collectionView.center, to: self.collectionView)
        /*let cell = collectionView.cellForItem(at: IndexPath(item: 5, section: 0))
        cell?.isSelected = true*/
        
        /*let centerPoint = CGPoint(x: self.collectionView.frame.size.width / 2 + scrollView.contentOffset.x + 30,
                                  y: self.collectionView.frame.size.height / 2 + scrollView.contentOffset.y)*/
        collectionView.reloadData()
        
        transformToLarge()
        
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
        
        
        // same as with tableView, it acts up if I set up the view using the other style
        collectionView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 189)
        collectionView.backgroundColor = .white
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = true
        collectionView.collectionViewLayout = self.myCollectionViewFlowLayout
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(AvatarCell.self, forCellWithReuseIdentifier: "AvatarCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = true
        view.addSubview(collectionView)
        
        collectionView.snp.makeConstraints{
            $0.top.equalTo(subTitle.snp.bottom).offset(16)
            $0.width.equalToSuperview()
            $0.height.equalTo(89.4)
        }
        
        if let indexPath = self.collectionView.indexPathForItem(at: CGPoint(x: 183.3333282470703, y: 143.66665649414062)){
            print("IN")
            //self.centerCell = (self.collectionView.cellForItem(at: indexPath) as! AvatarCell)
            print(" 📍CENTER CELL yeooo: ", indexPath)
        } else {print("indexPath not found")}
        
        let selectButton = UIButton {
            $0.layer.cornerRadius = 15
            $0.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            var customButtonTitle = NSMutableAttributedString()
            if(from == "create"){
                customButtonTitle = NSMutableAttributedString(string: "Create account", attributes: [
                    NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ])
            } else {
                customButtonTitle = NSMutableAttributedString(string: "Select", attributes: [
                    NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
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

        
    }
    
    func resetCell() {
        collectionView.removeFromSuperview()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView){
        print("HELLO")
        collectionView.reloadData()
        collectionView.layoutSubviews()

        guard scrollView is UICollectionView else {
            print("noeee")
            return}
        
       // let centerPoint = CGPoint(x: self.collectionView.frame.size.width / 2 + scrollView.contentOffset.x - 30,
                                  //y: self.collectionView.frame.size.height / 2 + scrollView.contentOffset.y)
        
        
        
        //print("----", scrollView.contentOffset.x)
        
        /*if(CGFloat(scrollView.contentOffset.x) < ((centerAvi.x/2)-66)){
            //avatars = avatars.rotate(shift: -1)
            centerAvi = self.view.convert(self.collectionView.center, to: self.collectionView)
            print("🌺", centerAvi.x)
        } else if (CGFloat(scrollView.contentOffset.x) > ((centerAvi.x/2)+66)){
            print("👄", centerAvi.x)
        }*/
        
        print("COLLECTION VIEW: ", collectionView)
        
        //let indexPath = self.collectionView.indexPathForItem(at: self.collectionView.center)
        let center = self.view.convert(self.collectionView.center, to: self.collectionView)
        //let center2 = CGPoint(x: 185.3333282470703, y: 139.3333282470703)
        //print("👍🏽 centerPoint: ", centerPoint, "center: ",  center, "last center: ", center2)
        //self.collectionView.scrollToItem(at: indexPath!, at: .centeredHorizontally, animated: true)
        
        //let indexPath =  collectionView.indexPathForItem(at: centerPoint)
        //let indexPath2 = collectionView.indexPathForItem(at: center)
        //let indexPath3 = collectionView.indexPathForItem(at: center2)

        if let indexPath2 = collectionView.indexPathForItem(at: center) {
            print(" 📍CENTER CELL: ", indexPath2)
            if(self.centerCell != (self.collectionView.cellForItem(at: indexPath2) as! AvatarCell)){
                self.centerCell = (self.collectionView.cellForItem(at: indexPath2) as! AvatarCell)
                transformToLarge()
            }
            print(" 🐈 CENTER CELL: ", centerCell.avatar!)
        }
        //print("IN from ScrollView")
        //print(" 📍CENTER point CELL: ", indexPath)
        //print(" 📍CENTER 2 CELL: ", indexPath3)
    }
    
   func transformToLarge(){
       self.collectionView.isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.2) {
            self.centerCell.avatarImage?.alpha = 1.0
            self.centerCell.avatarImage?.snp.updateConstraints{
                $0.height.equalTo(89.4)
                $0.width.equalTo(62)
            }
            //self.view.layoutIfNeeded()

            //self.centerCell.transform = CGAffineTransform(scaleX: 1.24, y: 1.24)
            self.collectionView.isUserInteractionEnabled = true
        }
       
       //let generator = UIImpactFeedbackGenerator(style: .light)
       //generator.impactOccurred()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let position = touch.location(in: view)
            print("TOUCHEEEDDD", position)
            
            
            
        }
    }
    
    @objc func selectedTap(_ sender: UIButton){
        let avatarURL = AvatarURLs().getURL(name: centerCell.avatar!)
        
        UserDataModel.shared.userInfo.avatarURL = avatarURL
        UserDataModel.shared.userInfo.avatarPic = UIImage(named: centerCell.avatar!)!
        let db = Firestore.firestore()
        db.collection("users").document(uid).updateData(["avatarURL": avatarURL])
        
        print("URL 🔗 2: ", UserDataModel.shared.userInfo.avatarURL)
        
        if(from == "map"){
            self.navigationController!.popViewController(animated: true)
        } else {
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
        }
        
    }
}

extension Array {
    func rotate(shift:Int) -> Array {
        print("yoe")
        var array = Array()
        if (self.count > 0) {
            array = self
            if (shift > 0) {
                for i in 1...shift {
                    array.append(array.remove(at: 0))
                }
            }
            else if (shift < 0) {
                for i in 1...abs(shift) {
                    array.insert(array.remove(at: array.count-1), at:0)
                }
            }
        }
        return array
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
        //cell.globalRow = indexPath.row
        return cell
    }
}

func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
     collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .left)
    print("hey...")
     // update selected avatar
}

extension AvatarSelectionController: UICollectionViewDelegateFlowLayout {
    /*func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if(indexPath.row != 5){
            return CGSize(width: 50, height: 72.08)
        } else { return CGSize(width: 62, height: 89.4)}
    }*/
        
}

final class MyCollectionViewFlowLayout: UICollectionViewFlowLayout {
    
    override func prepare() {
        super.prepare()
        
        scrollDirection = .horizontal
        minimumInteritemSpacing = 15
        itemSize = CGSize(width: 62, height: 89.4)
        sectionInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
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
        return CGPoint(x: proposedContentOffset.x + offsetAdjustment, y: proposedContentOffset.y)
    }
}

// MARK: avatar cell
class AvatarCell: UICollectionViewCell {
    
    var avatar: String?
    var avatarImage: UIImageView!
        
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
            $0.contentMode = .scaleToFill
            $0.image = UIImage(named: avatar)
            contentView.addSubview($0)
            $0.alpha = 0.5
        }
        
        avatarImage?.snp.makeConstraints{
            $0.bottom.equalToSuperview()
            $0.width.equalTo(50)
            $0.height.equalTo(72.08)
            $0.centerX.equalToSuperview()
        }
            
    }
        
    func resetCell() {
        ///keeping this here in case not having it causes problems during QA
        ///
       /* if confirmed != nil {confirmed = UILabel()}
        if checkMark != nil {checkMark.image = UIImage()}
        if confirmedView != nil {confirmedView = UIView()}
        if profilePic != nil { profilePic.image = UIImage() }
        if userAvatar != nil { userAvatar.image = UIImage() }
        if closeButton != nil { closeButton.setImage(UIImage(), for: .normal) }
        if acceptButton != nil {acceptButton = UIButton()}
        if senderUsername != nil {senderUsername = UILabel()}
        if senderName != nil {senderName = UILabel()}
        if timestamp != nil {timestamp = UILabel()}*/
        
        if self.contentView.subviews.isEmpty == false {
            for subview in self.contentView.subviews {
                subview.removeFromSuperview()
            }
        }
    }
}


/*
// MARK: friendRequestCollectionCellDelegate
extension FriendRequestCollectionCell: friendRequestCollectionCellDelegate{
    
    func deleteFriendRequest(sender: AnyObject?) {
        self.friendRequestCollection.performBatchUpdates({
            let cell = sender as! FriendRequestCell
            let indexPath = friendRequestCollection.indexPath(for: cell)
            var indexPaths: [IndexPath] = []
            indexPaths.append(indexPath!)
            // match current data with that of the main view controller
            friendRequests = notificationControllerDelegate?.deleteFriendRequest(friendRequest: cell.friendRequest) ?? []
            friendRequestCollection.deleteItems(at: indexPaths)
            let friendID = cell.friendRequest.userInfo!.id
            let notifID = cell.friendRequest.id
            self.removeFriendRequest(friendID: friendID!, notificationID: notifID!)
        }) { (finished) in
            self.friendRequestCollection.reloadData()
            self.notificationControllerDelegate?.reloadTable()
        }
    }
    
    func getProfile(userProfile: UserProfile){
        notificationControllerDelegate?.getProfile(userProfile: userProfile)
    }
    
    func acceptFriend(sender: AnyObject?) {
        let cell = sender as! FriendRequestCell
        let friendID = cell.friendRequest.userInfo!.id
        let notifID = cell.friendRequest.id
        DispatchQueue.global(qos: .userInitiated).async { self.acceptFriendRequest(friendID: friendID!, notificationID: notifID!)}
    }
}
 */

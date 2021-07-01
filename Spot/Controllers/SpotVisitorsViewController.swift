//
//  SpotVisitorsViewController.swift
//  Spot
//
//  Created by Kenny Barone on 6/22/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import SDWebImage

class SpotVisitorsViewController: UIViewController {
    
    unowned var spotVC: SpotViewController!
    unowned var mapVC: MapViewController!
    
    var visitorsCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout.init()
    
    override func viewDidLoad() {
        view.backgroundColor = UIColor(named: "SpotBlack")
        
        layout.scrollDirection = .vertical
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width/2 - 5, height: 150)
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        
        visitorsCollection.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        visitorsCollection.setCollectionViewLayout(layout, animated: false)
        visitorsCollection.delegate = self
        visitorsCollection.dataSource = self
        visitorsCollection.showsVerticalScrollIndicator = false
        visitorsCollection.backgroundColor = nil
        visitorsCollection.register(SpotAddFriendsCell.self, forCellWithReuseIdentifier: "SpotAddFriends")
        visitorsCollection.register(SpotVisitorCell.self, forCellWithReuseIdentifier: "SpotVisitor")
        visitorsCollection.isScrollEnabled = false
        visitorsCollection.bounces = false
        view.addSubview(visitorsCollection)
        
        visitorsCollection.removeGestureRecognizer(visitorsCollection.panGestureRecognizer)
    }

    func resetView() {
        func resetView() {
            DispatchQueue.main.async { self.visitorsCollection.reloadData() }
        }
    }
    
    func cancelDownloads() {
        for cell in visitorsCollection.visibleCells {
            guard let visitorCell = cell as? SpotVisitorCell else { return }
            visitorCell.profilePic.sd_cancelCurrentImageLoad()
        }
    }
}

extension SpotVisitorsViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return canInviteFriends() ? spotVC.memberList.count + 1 : spotVC.memberList.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if indexPath.row == 0 && canInviteFriends() {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SpotAddFriends", for: indexPath) as? SpotAddFriendsCell else { return UICollectionViewCell() }
            cell.setUp()
            return cell
            
        } else {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SpotVisitor", for: indexPath) as? SpotVisitorCell else { return UICollectionViewCell() }
            let row = canInviteFriends() ? indexPath.row - 1 : indexPath.row
            guard let user = spotVC.memberList[safe: row] else { return cell }
            cell.setUp(user: user)
            return cell
        }
    }
    
    func canInviteFriends() -> Bool {
        return (spotVC.spotObject.visitorList.contains(spotVC.uid) && spotVC.spotObject.privacyLevel != "invite") || (spotVC.spotObject.founderID == spotVC.uid)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView.cellForItem(at: indexPath) is SpotAddFriendsCell {
            /// open add friends
            spotVC.launchFriendsPicker()
            
        } else if collectionView.cellForItem(at: indexPath) is SpotVisitorCell {
            /// open profile
            
            cancelDownloads()
            
            let row = canInviteFriends() ? indexPath.row - 1 : indexPath.row
            guard let user = spotVC.memberList[safe: row] else { return }
            spotVC.openProfile(user: user)
        }
    }
}

class SpotAddFriendsCell: UICollectionViewCell {
    
    var addFriendsImage: UIImageView!
    
    func setUp() {
    
        let cellSize = CGSize(width: UIScreen.main.bounds.width/2 - 5, height: 150)
        
        if addFriendsImage != nil { addFriendsImage.image = UIImage() }
        addFriendsImage = UIImageView(frame: CGRect(x: cellSize.width/2 - 46, y: 74, width: 92, height: 42))
        addFriendsImage.image = UIImage(named: "SpotVisitorsAddFriends")
        addSubview(addFriendsImage)
    }
}

class SpotVisitorCell: UICollectionViewCell {
    
    var profilePic: UIImageView!
    var nameLabel: UILabel!
    var usernameLabel: UILabel!
    
    func setUp(user: UserProfile) {
        
        let cellSize = CGSize(width: UIScreen.main.bounds.width/2 - 5, height: 150)
        backgroundColor = nil
        
        if profilePic != nil { profilePic.image = UIImage() }
        profilePic = UIImageView(frame: CGRect(x: cellSize.width/2 - 44, y: 30, width: 88, height: 88))
        profilePic.layer.cornerRadius = 44
        profilePic.clipsToBounds = true
        contentView.addSubview(profilePic)
        
        let url = user.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 200, height: 200), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }
        
        if nameLabel != nil { nameLabel.text = "" }
        nameLabel = UILabel(frame: CGRect(x: 10, y: profilePic.frame.maxY + 9, width: cellSize.width - 20, height: 16))
        nameLabel.text = user.name
        nameLabel.textColor = .white
        nameLabel.font = UIFont(name: "SFCamera-Semibold", size: 16)
        nameLabel.textAlignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        addSubview(nameLabel)
        
        if usernameLabel != nil { usernameLabel.text = "" }
        usernameLabel = UILabel(frame: CGRect(x: 10, y: nameLabel.frame.maxY + 3, width: cellSize.width - 20, height: 16))
        usernameLabel.text = user.username
        usernameLabel.textColor = UIColor(red: 0.60, green: 0.60, blue: 0.60, alpha: 1.00)
        usernameLabel.font = UIFont(name: "SFCamera-Regular", size: 14.5)
        usernameLabel.textAlignment = .center
        usernameLabel.lineBreakMode = .byTruncatingTail
        addSubview(usernameLabel)
    }
}

/*

class SpotFriendsCollectionCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    var usersCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    var friendVisitors: [UserProfile] = []
    var privacyLevel = ""
    var halfScreenUserCount = 0, fullScreenUserCount = 0
    var usersMoreNeeded = false
    var expandUsers = false
    var founder = false
    var member = false
    
    func setUp(friendVisitors: [UserProfile], privacyLevel: String, halfScreenUserCount: Int, fullScreenUserCount: Int, usersMoreNeeded: Bool, expandUsers: Bool, collectionHeight: CGFloat, founder: Bool, member: Bool) {
        
        self.selectionStyle = .none
        self.backgroundColor = UIColor(named: "SpotBlack")
        
        self.friendVisitors = friendVisitors
        self.privacyLevel = privacyLevel
        self.halfScreenUserCount = halfScreenUserCount
        self.fullScreenUserCount = fullScreenUserCount
        self.usersMoreNeeded = usersMoreNeeded
        self.expandUsers = expandUsers
        self.founder = founder
        self.member = member
        
        let usersLayout = LeftAlignedCollectionViewFlowLayout()
        usersLayout.headerReferenceSize = CGSize(width: UIScreen.main.bounds.width, height: 33)

        usersCollection.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: collectionHeight)
        usersCollection.contentInset = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        usersCollection.delegate = self
        usersCollection.dataSource = self
        usersCollection.backgroundColor = nil
        usersCollection.register(SpotFriendsHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "SpotFriendsHeader")
        usersCollection.register(SpotFriendsCell.self, forCellWithReuseIdentifier: "SpotFriendsCell")
        usersCollection.register(MoreCell.self, forCellWithReuseIdentifier: "MoreCell")
        usersCollection.isScrollEnabled = false
        usersCollection.bounces = false
        self.addSubview(usersCollection)
        
        usersCollection.reloadData()
        usersCollection.setCollectionViewLayout(usersLayout, animated: false)
        
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return expandUsers ? fullScreenUserCount : halfScreenUserCount
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        /// add more button for halfscreen view with user overflow
        if indexPath.row == halfScreenUserCount - 1 && usersMoreNeeded && !expandUsers {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MoreCell", for: indexPath) as? MoreCell else { return UICollectionViewCell() }
            let trueHalf = usersMoreNeeded ? halfScreenUserCount - 1 : halfScreenUserCount
            cell.setUp(count: fullScreenUserCount - trueHalf, spotPage:  true)
            return cell
        }
                
        /// regular user cell
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SpotFriendsCell", for: indexPath) as? SpotFriendsCell else { return UICollectionViewCell() }
        guard let user = friendVisitors[safe: indexPath.row] else { return cell }
        
        cell.setUp(user: user)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if indexPath.row == halfScreenUserCount - 1 && usersMoreNeeded && !expandUsers {
            /// add +more button if users aren't going to fit on 2 lines for this section, and hasn't already been expanded
            let moreWidth = getMoreWidth(extraCount: fullScreenUserCount - halfScreenUserCount)
            return CGSize(width: moreWidth, height: 28)
        }
        
        guard let user = friendVisitors[safe: indexPath.row] else { return CGSize(width: 0, height: 0) }
        let width = getWidth(name: user.username)
        
        return CGSize(width: width, height: 24)
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SpotFriendsHeader", for: indexPath) as? SpotFriendsHeader else { return UICollectionReusableView() }
        header.setUp(friendCount: friendVisitors.count, privacyLevel: privacyLevel, founder: founder, member: member)
        return header
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let spotVC = self.viewContainingController() as? SpotViewController else { return }
        if spotVC.mapVC.prePanY < 200 { spotVC.shadowScroll.setContentOffset(CGPoint(x: 0, y: 1), animated: false)}
        
        if collectionView.cellForItem(at: indexPath) is SpotFriendsCell {
            
            guard let user = friendVisitors[safe: indexPath.row] else { return }
            spotVC.openProfile(user: user)
            
        } else {

            guard let spotVC = self.viewContainingController() as? SpotViewController else { return }
            /// more button tap -> expand to full and resize section
            spotVC.expandUsers = true
            if spotVC.mapVC.prePanY != 0 {
                spotVC.mapVC.animateSpotToFull(forceRefresh: true)
            } else {
                spotVC.resizeTable(halfScreen: false, forceRefresh: true)
            }
        }
    }
    
    func getWidth(name: String) -> CGFloat {
            
        let username = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 16))
        username.text = name
        username.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        username.sizeToFit()
        return 30 + username.frame.width
    }
    
    func getMoreWidth(extraCount: Int) -> CGFloat {
        
        let moreLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 16))
        moreLabel.font = UIFont(name: "SFCamera-Regular", size: 11.5)
        moreLabel.text = "+ \(extraCount) more"
        moreLabel.sizeToFit()
        
        return moreLabel.frame.width + 15
    }
    
    override func prepareForReuse() {
        
        /// collection was getting readded and not removing cells
        for cell in usersCollection.visibleCells {
            guard let cell = cell as? SpotFriendsCell else { return }
            if cell.username != nil { cell.username.text = "" }
            if cell.profilePic != nil { cell.profilePic.image = UIImage() }
        }
        
        guard let header = usersCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 0)) as? SpotFriendsHeader else { return }
        if header.label != nil { header.label.text = "" }
        if header.privacyIcon != nil { header.privacyIcon.image = UIImage() }
        if header.addIcon != nil { header.addIcon.setImage(UIImage(), for: .normal) }

        usersCollection = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    }
}


class SpotFriendsHeader: UICollectionReusableView {
    
    var label: UILabel!
    var privacyIcon: UIImageView!
    var addIcon: UIButton!
    
    func setUp(friendCount: Int, privacyLevel: String, founder: Bool, member: Bool) {
        
        if label != nil { label.text = "" }
        label = UILabel(frame: CGRect(x: 0, y: 7, width: 200, height: 16))
        label.text = "\(friendCount) friend"
        if friendCount != 1 { label.text! += "s" }
        label.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        label.font = UIFont(name: "SFCamera-Regular", size: 12)
        label.sizeToFit()
        addSubview(label)
        
        if privacyIcon != nil { print("privacy = 0"); privacyIcon.image = UIImage() }

        switch privacyLevel {
        
        case "friends":
            privacyIcon = UIImageView(frame: CGRect(x: label.frame.maxX + 7, y: 4.5, width: 98, height: 19))
            privacyIcon.image = UIImage(named: "SpotPageFriends")
            addSubview(privacyIcon)
            
        case "invite":
            privacyIcon = UIImageView(frame: CGRect(x: label.frame.maxX + 7, y: 4.5, width: 68, height: 19))
            privacyIcon.image = UIImage(named: "SpotPagePrivate")
            addSubview(privacyIcon)
        default:
            print("public")
        }
        
        if (privacyLevel == "public" && !member) || (privacyLevel != "public" && !founder) { return }
        
        if addIcon != nil { addIcon.setImage(UIImage(), for: .normal) }
        let addX = privacyLevel == "public" ? label.frame.maxX : privacyIcon.frame.maxX
        addIcon = UIButton(frame: CGRect(x: addX, y: 2.5, width: 23, height: 23))
        addIcon.imageEdgeInsets = UIEdgeInsets(top: 7, left: 7, bottom: 7, right: 7)
        addIcon.setImage(UIImage(named: "AddIcon"), for: .normal)
        addIcon.addTarget(self, action: #selector(addFriendsTap(_:)), for: .touchUpInside)
        addSubview(addIcon)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func addFriendsTap(_ sender: UIButton) {
        guard let spotVC = viewContainingController() as? SpotViewController else { return }
        spotVC.launchFriendsPicker()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        
    }
}

class SpotFriendsCell: UICollectionViewCell {
    
    var profilePic: UIImageView!
    var username: UILabel!
    
    func setUp(user: UserProfile) {
        
        backgroundColor = nil
        
        if profilePic != nil { profilePic.image = UIImage() }
        profilePic = UIImageView(frame: CGRect(x: 0, y: 0, width: 22, height: 22))
        profilePic.layer.cornerRadius = 11
        profilePic.layer.masksToBounds = true
        profilePic.contentMode = .scaleAspectFill
        self.addSubview(profilePic)
        
        let url = user.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 50, height: 50), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }

        if username != nil { username.text = "" }
        username = UILabel(frame: CGRect(x: profilePic.frame.maxX + 6, y: 3, width: self.bounds.width - 28, height: 16))
        username.text = user.username
        username.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        username.textColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
        username.sizeToFit()
        self.addSubview(username)
    }
    
    override func prepareForReuse() {
        /// cancel image fetch when cell leaves screen
        super.prepareForReuse()
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
    }
}*/


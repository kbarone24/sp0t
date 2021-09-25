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
import Mixpanel

class SpotVisitorsViewController: UIViewController {
    
    unowned var spotVC: SpotViewController!
    
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "SpotVisitorsOpen")
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
            let transformer = SDImageResizingTransformer(size: CGSize(width: 150, height: 150), scaleMode: .aspectFill)
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

//
//  UploadAddFriendsCell.swift
//  Spot
//
//  Created by Kenny Barone on 9/17/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//
/*
import Foundation
import UIKit
import FirebaseUI

class UploadAddFriendsCell: UITableViewCell {
    
    var topLine: UIView!
    var titleLabel: UILabel!
    
    var addFriendsCollection: UploadPillCollectionView  = UploadPillCollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())

    func setUp(post: MapPost) {
        
        backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1.00)
        contentView.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1.00)

        resetView()
        
        topLine = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
        topLine.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        contentView.addSubview(topLine)
        
        titleLabel = UILabel(frame: CGRect(x: 16, y: 12, width: 150, height: 18))
        titleLabel.text = "Add friends"
        titleLabel.textColor = UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1)
        titleLabel.font = UIFont(name: "SFCamera-Regular", size: 13.5)
        contentView.addSubview(titleLabel)
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.sectionInset = UIEdgeInsets(top: 0, left: 13, bottom: 0, right: 13)
        
        /// all subsequent loads will be handled through reloading collection directly rather than the cell
        if addFriendsCollection.numberOfItems(inSection: 0) > 0 { return }
        addFriendsCollection.frame = CGRect(x: 0, y: 38, width: UIScreen.main.bounds.width, height: 32)
        addFriendsCollection.backgroundColor = nil
        addFriendsCollection.delegate = self
        addFriendsCollection.dataSource = self
        addFriendsCollection.register(UploadFriendCell.self, forCellWithReuseIdentifier: "FriendCell")
        addFriendsCollection.register(UploadSearchFriendsCell.self, forCellWithReuseIdentifier: "SearchCell")
        addFriendsCollection.showsHorizontalScrollIndicator = false
        addFriendsCollection.setCollectionViewLayout(layout, animated: false)
        contentView.addSubview(addFriendsCollection)
    }
    
    func resetView() {
        if topLine != nil { topLine.backgroundColor = nil }
        if titleLabel != nil { titleLabel.text = "" }
    }
}

extension UploadAddFriendsCell: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return UploadImageModel.shared.friendObjects.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if indexPath.row == UploadImageModel.shared.friendObjects.count {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SearchCell", for: indexPath) as? UploadSearchFriendsCell else { return UICollectionViewCell() }
            return cell
        }
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FriendCell", for: indexPath) as? UploadFriendCell else { return UICollectionViewCell() }
        cell.setUp(user: UploadImageModel.shared.friendObjects[indexPath.row], header: false)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return indexPath.row == UploadImageModel.shared.friendObjects.count ? CGSize(width: 74, height: 31) : CGSize(width: getCellWidth(user: UploadImageModel.shared.friendObjects[indexPath.row]), height: 31)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    
        guard let uploadVC = viewContainingController() as? UploadPostController  else { return }

        if indexPath.row == UploadImageModel.shared.friendObjects.count {
            uploadVC.pushInviteFriends()
            
        } else {
            uploadVC.selectUser(index: indexPath.row)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        /// push location picker once content offset pushes 50 pts past the natural boundary
        if scrollView.contentOffset.x > scrollView.contentSize.width - UIScreen.main.bounds.width + 60 {
            guard let uploadVC = viewContainingController() as? UploadPostController else { return }
            uploadVC.pushInviteFriends()
        }
    }

    
    func getCellWidth(user: UserProfile) -> CGFloat {
        
        let tempName = UILabel(frame: CGRect(x: 0, y: 0, width: 250, height: 18))
        tempName.font = UIFont(name: "SFCamera-Regular", size: 12.5)
    
        tempName.text = user.username
        tempName.sizeToFit()
        
        let nameWidth = tempName.frame.width
        
        return nameWidth + 40
    }
}

*/

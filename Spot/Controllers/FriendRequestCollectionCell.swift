//
//  FriendRequestCollectionCell.swift
//  Spot
//
//  Created by Shay Gyawali on 6/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class FriendRequestCollectionCell: UITableViewCell {
    
    
    var itemHeight, itemWidth: CGFloat!

    var friendRequests: [UserNotification] = []
    
    var friendRequestCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewLayout.init())
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?){
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        itemWidth = 157
        itemHeight = 187
        self.backgroundColor = .white
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUpFriendRequests(friendRequests: [UserNotification]){
        self.friendRequests = friendRequests
    }
    
    func setUp(notif: UserNotification) {
        
        ///hardcode cell height in case its laid out before view fully appears -> hard code body height so mask stays with cell change
        //resetCell()
        
        friendRequests.append(notif)
        
        let cameraLayout = UICollectionViewFlowLayout()
        cameraLayout.scrollDirection = .horizontal
        cameraLayout.itemSize = CGSize(width: 157, height: 187)
        cameraLayout.minimumInteritemSpacing = 8
        cameraLayout.sectionInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        
        friendRequestCollection.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: itemHeight + 1)
        friendRequestCollection.backgroundColor = nil
        friendRequestCollection.delegate = self
        friendRequestCollection.dataSource = self
        friendRequestCollection.isScrollEnabled = true
        friendRequestCollection.setCollectionViewLayout(cameraLayout, animated: false)
        friendRequestCollection.showsHorizontalScrollIndicator = false
        friendRequestCollection.register(FriendRequestCell.self, forCellWithReuseIdentifier: "FriendRequestCell")
        addSubview(friendRequestCollection)
        friendRequestCollection.topAnchor.constraint(equalTo: topAnchor, constant: 15).isActive = true
        friendRequestCollection.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 15).isActive = true
        
    }
}

extension FriendRequestCollectionCell: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return friendRequests.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FriendRequestCell", for: indexPath) as? FriendRequestCell else { return UICollectionViewCell() }
        cell.setUp(friendRequest: friendRequests[indexPath.row])
        cell.globalRow = indexPath.row
        return cell
    }
}

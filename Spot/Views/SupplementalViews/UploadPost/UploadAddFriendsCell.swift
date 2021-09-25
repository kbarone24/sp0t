//
//  UploadAddFriendsCell.swift
//  Spot
//
//  Created by Kenny Barone on 9/17/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import FirebaseUI

class UploadAddFriendsCell: UITableViewCell {
    
    var topLine: UIView!
    var titleLabel: UILabel!
    
    var addFriendsCollection: UploadPillCollectionView  = UploadPillCollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())

    func setUp(post: MapPost) {
        
        backgroundColor = .black
        contentView.backgroundColor = .black

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

class UploadFriendCell: UICollectionViewCell {
    
    var userView: UIView!
    var profilePic: UIImageView!
    var username: UILabel!
    var exitButton: UIButton!
    
    var user: UserProfile!
        
    func setUp(user: UserProfile, header: Bool) {
        
        resetView()
        backgroundColor = nil
        self.user = user
        
        /// allow room for x button on header cell
        let userBounds = !header ? self.bounds : CGRect(x: 0, y: 11, width: self.bounds.width - 9, height: 36)
        userView = UIView(frame: userBounds)
        userView.backgroundColor = header ? UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1) : user.selected ? UIColor(red: 0.00, green: 0.09, blue: 0.09, alpha: 1.00) : UIColor(red: 0.112, green: 0.112, blue: 0.112, alpha: 1)
        userView.layer.borderWidth = 1
        userView.layer.cornerRadius = 10
        userView.layer.cornerCurve = .continuous
        userView.layer.borderColor = user.selected && !header ? UIColor(named: "SpotGreen")!.cgColor : header ? UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1).cgColor : UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1).cgColor
        addSubview(userView)
        
        profilePic = UIImageView(frame: CGRect(x: 6, y: 5, width: 21, height: 21))
        profilePic.layer.cornerRadius = 12
        profilePic.layer.cornerCurve = .continuous
        profilePic.layer.masksToBounds = true
        profilePic.contentMode = .scaleAspectFill
        userView.addSubview(profilePic)

        let url = user.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 50, height: 50), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }

        username = UILabel(frame: CGRect(x: profilePic.frame.maxX + 4, y: 8, width: self.bounds.width - profilePic.frame.maxX - 10, height: 16))
        username.text = user.username
        username.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        username.textColor = UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1)
        username.sizeToFit()
        userView.addSubview(username)
        
        if header {
            exitButton = UIButton(frame: CGRect(x: self.bounds.width - 23, y: 0, width: 27, height: 27))
            exitButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            exitButton.setImage(UIImage(named: "CheckInX"), for: .normal)
            exitButton.addTarget(self, action: #selector(exitTap(_:)), for: .touchUpInside)
            addSubview(exitButton)
        }
    }
    
    @objc func exitTap(_ sender: UIButton) {
        guard let inviteVC = viewContainingController() as? InviteFriendsController else { return }
        inviteVC.selectedFriends.removeAll(where: {$0.id == user.id})
        inviteVC.friendsList.insert(user, at: 0)
        DispatchQueue.main.async { inviteVC.tableView.reloadData() }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
    }
    
    func resetView() {
        if profilePic != nil { profilePic.image = UIImage() }
        if username != nil { username.text = "" }
        if userView != nil { for sub in userView.subviews { sub.removeFromSuperview() }; userView.backgroundColor = nil; userView.layer.borderColor = nil }
        if exitButton != nil { exitButton.setImage(UIImage(), for: .normal)}
    }
}

class UploadSearchFriendsCell: UICollectionViewCell {
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        
        backgroundColor = UIColor(red: 0.098, green: 0.098, blue: 0.098, alpha: 1)
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1).cgColor
        
        let searchIcon = UIImageView(frame: CGRect(x: 8, y: 9.5, width: 12, height: 12.3))
        searchIcon.image = UIImage(named: "SearchIcon")
        addSubview(searchIcon)
        
        let titleLabel = UILabel(frame: CGRect(x: searchIcon.frame.maxX + 5, y: 7.5, width: 44, height: 16))
        titleLabel.text = "Search"
        titleLabel.textColor = UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1)
        titleLabel.font = UIFont(name: "SFCamera-Semibold", size: 12.5)
        addSubview(titleLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

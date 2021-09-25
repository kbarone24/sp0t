//
//  PostFriendsCell.swift
//  Spot
//
//  Created by Kenny Barone on 9/8/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class PostFriendsCell: UITableViewCell {
    
    var originalOffset: CGFloat!
    var postFriendsView: PostFriendsView!

    func setUp(cellHeight: CGFloat, tabBarHeight: CGFloat) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        tag = 16
        originalOffset = 0
        
        postFriendsView = PostFriendsView(frame: self.bounds)
        postFriendsView.backgroundColor = nil
        postFriendsView.setUp(cellHeight: cellHeight, tabBarHeight: tabBarHeight)
        postFriendsView.findFriendsButton.addTarget(self, action: #selector(findFriendsTap(_:)), for: .touchUpInside)
        addSubview(postFriendsView)
    }
    
    @objc func findFriendsTap(_ sender: UIButton) {
        guard let postVC = viewContainingController() as? PostViewController else { return }
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "FindFriends") as? FindFriendsController {
            postVC.present(vc, animated: true, completion: nil)
        }
    }
}

class PostFriendsView: UIView {
    
    var botImage: UIImageView!
    var label0: UILabel!
    var label1: UILabel!
    var findFriendsButton: UIButton!
    
    func setUp(cellHeight: CGFloat, tabBarHeight: CGFloat) {
        
        let minY = (cellHeight - tabBarHeight) * 0.38

        if botImage != nil { botImage.image = UIImage() }
        botImage = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 21.5, y: minY, width: 43, height: 50))
        botImage.image = UIImage(named: "OnboardB0t")
        addSubview(botImage)
        
        if label0 != nil { label0.text = "" }
        label0 = UILabel(frame: CGRect(x: 20, y: botImage.frame.maxY + 15, width: UIScreen.main.bounds.width - 40, height: 20))
        label0.text = "Your friends posts will show here"
        label0.textColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
        label0.font = UIFont(name: "SFCamera-Semibold", size: 15.5)
        label0.textAlignment = .center
        addSubview(label0)
        
        if label1 != nil { label1.text = "" }
        label1 = UILabel(frame: CGRect(x: 20, y: label0.frame.maxY + 3, width: UIScreen.main.bounds.width - 40, height: 16))
        label1.text = "Get started by adding some friends"
        label1.textColor = UIColor(red: 0.479, green: 0.479, blue: 0.479, alpha: 1)
        label1.font = UIFont(name: "SFCamera-Regular", size: 13)
        label1.textAlignment = .center
        addSubview(label1)
        
        if findFriendsButton != nil { findFriendsButton.setImage(UIImage(), for: .normal) }
        findFriendsButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 121, y: label1.frame.maxY + 23, width: 242, height: 43))
        findFriendsButton.setImage(UIImage(named: "FeedAddFriends"), for: .normal)
        addSubview(findFriendsButton)
    }
}

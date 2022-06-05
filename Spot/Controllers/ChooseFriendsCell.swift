//
//  ChooseFriendsCell.swift
//  Spot
//
//  Created by Kenny Barone on 5/4/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import FirebaseUI

class ChooseFriendsCell: UITableViewCell {
    
    var profilePic: UIImageView!
    var username: UILabel!
    var selectedBubble: UIView!
    var bottomLine: UIView!
    
    var userID = ""
    
    func setUp(friend: UserProfile) {
        
        backgroundColor = .white
        userID = friend.id!
        
        resetCell()
        
        profilePic = UIImageView(frame: CGRect(x: 15, y: 8, width: 42, height: 42))
        profilePic.contentMode = .scaleAspectFill
        profilePic.layer.cornerRadius = 21
        profilePic.clipsToBounds = true
        contentView.addSubview(profilePic)
            
        let avatar = (friend.avatarURL ?? "") != ""
        let url = avatar ? friend.avatarURL! : friend.imageURL
        if avatar { profilePic.frame = CGRect(x: 19, y: 10, width: 35, height: 44.5); profilePic.layer.cornerRadius = 0 }
        
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }
        
        username = UILabel(frame: CGRect(x: profilePic.frame.maxX + 8, y: 21, width: UIScreen.main.bounds.width - profilePic.frame.maxX - 60, height: 19))
        username.text = friend.username
        username.textColor = .black
        username.font = UIFont(name: "SFCompactText-Semibold", size: 16)
        contentView.addSubview(username)
        
        selectedBubble = UIView(frame: CGRect(x: UIScreen.main.bounds.width - 49, y: 17, width: 24, height: 24))
        selectedBubble.backgroundColor = friend.selected ? UIColor(named: "SpotGreen") : UIColor(red: 0.975, green: 0.975, blue: 0.975, alpha: 1)
        selectedBubble.layer.borderColor = UIColor(red: 0.863, green: 0.863, blue: 0.863, alpha: 1).cgColor
        selectedBubble.layer.borderWidth = 2
        selectedBubble.layer.cornerRadius = 12.5
        contentView.addSubview(selectedBubble)
        
        bottomLine = UIView(frame: CGRect(x: 0, y: 62, width: UIScreen.main.bounds.width, height: 1))
        bottomLine.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
        contentView.addSubview(bottomLine)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        contentView.addGestureRecognizer(tap)
    }
    
    @objc func tap(_ sender: UITapGestureRecognizer) {
        guard let infoVC = viewContainingController() as? PostInfoController else { return }
        infoVC.selectFriend(id: userID)
    }
    
    func resetCell() {
        if profilePic != nil { profilePic.image = UIImage() }
        if username != nil { username.text = "" }
        if selectedBubble != nil { selectedBubble.backgroundColor = nil; selectedBubble.layer.borderColor = nil }
        if bottomLine != nil { bottomLine.backgroundColor = nil }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if profilePic != nil { profilePic.removeFromSuperview(); profilePic.sd_cancelCurrentImageLoad() }
    }
}


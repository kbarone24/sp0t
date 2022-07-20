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
    
    func setUp(friend: UserProfile, allowsSelection: Bool, editable: Bool) {
        
        backgroundColor = .white
        contentView.alpha = 1.0
        selectionStyle = .none
        userID = friend.id!
        
        resetCell()
        
        profilePic = UIImageView {
            $0.frame = CGRect(x: 15, y: 8, width: 42, height: 42)
            $0.contentMode = .scaleAspectFill
            $0.layer.cornerRadius = 21
            $0.clipsToBounds = true
            contentView.addSubview($0)
        }
            
        let avatar = (friend.avatarURL ?? "") != ""
        let url = avatar ? friend.avatarURL! : friend.imageURL
        if avatar { profilePic.frame = CGRect(x: 19, y: 10, width: 35, height: 44.5); profilePic.layer.cornerRadius = 0 }
        
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }
        
        username = UILabel {
            $0.frame = CGRect(x: profilePic.frame.maxX + 8, y: 21, width: UIScreen.main.bounds.width - profilePic.frame.maxX - 60, height: 19)
            $0.text = friend.username
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 16)
            contentView.addSubview($0)
        }
        
        if allowsSelection {
            selectedBubble = UIView {
                $0.frame = CGRect(x: UIScreen.main.bounds.width - 49, y: 17, width: 24, height: 24)
                $0.backgroundColor = friend.selected ? UIColor(named: "SpotGreen") : UIColor(red: 0.975, green: 0.975, blue: 0.975, alpha: 1)
                $0.layer.borderColor = UIColor(red: 0.863, green: 0.863, blue: 0.863, alpha: 1).cgColor
                $0.layer.borderWidth = 2
                $0.layer.cornerRadius = 12.5
                contentView.addSubview($0)
            }
        }
        
        bottomLine = UIView {
            $0.frame = CGRect(x: 0, y: 62, width: UIScreen.main.bounds.width, height: 1)
            $0.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            contentView.addSubview($0)
        }
                
        if !editable {
            contentView.alpha = 0.5
        }
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


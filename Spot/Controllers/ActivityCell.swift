//
//  ActivityCell.swift
//  Spot
//
//  Created by Shay Gyawali on 6/26/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import FirebaseUI

class ActivityCell: UITableViewCell {
    
    var username = UILabel()
    var detail = UILabel()
    var profilePic: UIImageView!
        
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?){
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        addSubview(username)
        addSubview(detail)
        
        configureProfilePic()
        configureView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureProfilePic(){
        profilePic = UIImageView(frame: CGRect(x: 65, y: 27.5, width: 50, height: 50))
        profilePic.layer.masksToBounds = false
        profilePic.layer.cornerRadius = profilePic.frame.height/2
        profilePic.clipsToBounds = true
        profilePic.contentMode = UIView.ContentMode.scaleAspectFill
        profilePic.isHidden = false
        self.addSubview(profilePic)

    }
    
    func configureView(){

        username.numberOfLines = 0
        username.textColor = .black
        username.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
        username.translatesAutoresizingMaskIntoConstraints = false
        username.topAnchor.constraint(equalTo: topAnchor, constant: 15).isActive = true
        username.leadingAnchor.constraint(equalTo: profilePic.trailingAnchor, constant: 8).isActive = true
        
        detail.numberOfLines = 0
        detail.textColor = .black
        detail.font = UIFont(name: "SFCompactText-Regular", size: 14.5)
        detail.translatesAutoresizingMaskIntoConstraints = false
        detail.topAnchor.constraint(equalTo: username.bottomAnchor).isActive = true
        detail.leadingAnchor.constraint(equalTo: profilePic.trailingAnchor, constant: 8).isActive = true
        
    }
    
    func set(notification: UserNotification){
        username.text = notification.senderUsername
        
        let notiType = notification.type
        switch notiType {
        case "like":
            detail.text = "liked your post"
        case "comment":
            detail.text = "commented on your post"
        default:
            detail.text = notification.type
        }
        
        
        let url = notification.userInfo!.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
            profilePic.translatesAutoresizingMaskIntoConstraints = false
            profilePic.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
            profilePic.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16).isActive = true
            profilePic.heightAnchor.constraint(equalToConstant: 50).isActive = true
            profilePic.widthAnchor.constraint(equalToConstant: 50).isActive = true
        } else {print("🙈 NOOOOOOO")}
        
    }
    
}

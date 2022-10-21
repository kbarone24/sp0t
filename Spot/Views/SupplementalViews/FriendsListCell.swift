//
//  FriendsListCell.swift
//  Spot
//
//  Created by Kenny Barone on 6/6/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import FirebaseUI
import Foundation
import UIKit

class FriendsListCell: UITableViewCell {

    var profilePic: UIImageView!
    var name: UILabel!
    var username: UILabel!

    func setUp(user: UserProfile) {

        self.backgroundColor = UIColor(named: "SpotBlack")
        self.selectionStyle = .none

        resetCell()

        profilePic = UIImageView(frame: CGRect(x: 14, y: 8.5, width: 44, height: 44))
        profilePic.layer.cornerRadius = 22
        profilePic.clipsToBounds = true
        self.addSubview(profilePic)

        let url = user.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }

        name = UILabel(frame: CGRect(x: profilePic.frame.maxX + 9, y: 14.5, width: UIScreen.main.bounds.width - 186, height: 15))
        name.textAlignment = .left
        name.lineBreakMode = .byTruncatingTail
        name.text = user.name
        name.textColor = UIColor(red: 0.946, green: 0.946, blue: 0.946, alpha: 1)
        name.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
        self.addSubview(name)

        username = UILabel(frame: CGRect(x: profilePic.frame.maxX + 9, y: name.frame.maxY + 1, width: 150, height: 15))
        username.text = user.username
        username.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        username.font = UIFont(name: "SFCompactText-Regular", size: 12.5)
        username.textAlignment = .left
        self.addSubview(username)
    }

    func resetCell() {
        if profilePic != nil { profilePic.image = UIImage() }
        if name != nil { name.text = "" }
        if username != nil { username.text = "" }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        /// cancel image fetch when cell leaves screen
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
    }
}

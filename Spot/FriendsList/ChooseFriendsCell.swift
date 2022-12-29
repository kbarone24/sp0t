//
//  ChooseFriendsCell.swift
//  Spot
//
//  Created by Kenny Barone on 5/4/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import FirebaseUI
import Foundation
import UIKit

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
            $0.contentMode = .scaleAspectFit
            $0.layer.cornerRadius = 21
            $0.clipsToBounds = true
            contentView.addSubview($0)
        }
        profilePic.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.top.equalTo(8)
            $0.width.height.equalTo(42)
        }

        let avatar = (friend.avatarURL ?? "") != ""
        let url = avatar ? friend.avatarURL! : friend.imageURL
        if avatar { profilePic.frame = CGRect(x: 19, y: 10, width: 35, height: 44.5); profilePic.layer.cornerRadius = 0 }

        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 69.4, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
        }

        username = UILabel {
            $0.text = friend.username
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 16)
            contentView.addSubview($0)
        }
        username.snp.makeConstraints {
            $0.leading.equalTo(profilePic.snp.trailing).offset(8)
            $0.top.equalTo(21)
            $0.trailing.equalToSuperview().inset(60)
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
            selectedBubble.snp.makeConstraints {
                $0.trailing.equalToSuperview().inset(25)
                $0.width.height.equalTo(24)
                $0.centerY.equalToSuperview()
            }
        }

        bottomLine = UIView {
            $0.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            contentView.addSubview($0)
        }
        bottomLine.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(1)
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

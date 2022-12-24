//
//  LikerCell.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 12/24/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import Mixpanel
import SDWebImage


final class LikerCell: UITableViewCell {
    var profilePic: UIImageView!
    var username: UILabel!
    var user: UserProfile!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1)
        contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(likerCellTap)))

        profilePic = UIImageView {
            $0.layer.cornerRadius = 39 / 2
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFill
            contentView.addSubview($0)
        }
        profilePic.snp.makeConstraints {
            $0.leading.equalTo(9)
            $0.top.equalTo(15)
            $0.width.height.equalTo(39)
        }

        username = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 14.5)
            contentView.addSubview($0)
        }
        username.snp.makeConstraints {
            $0.leading.equalTo(profilePic.snp.trailing).offset(9)
            $0.centerY.equalTo(profilePic.snp.centerY)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUp(user: UserProfile) {
        let url = user.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
        }
        username.text = user.username
        self.user = user
    }

    @objc func likerCellTap() {
        Mixpanel.mainInstance().track(event: "CommentsLikerCellTap")
        guard let commentsVC = viewContainingController() as? CommentsController else { return }
        commentsVC.openProfile(user: user)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        /// cancel image fetch when cell leaves screen
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
    }
}


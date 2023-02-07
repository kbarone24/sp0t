//
//  ButtonView.swift
//  Spot
//
//  Created by Kenny Barone on 1/30/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class PostButtonView: UIView {
    lazy var likeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "LikeButton"), for: .normal)
        return button
    }()

    private lazy var numLikes: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "UniversCE-Black", size: 12)
        return label
    }()

    lazy var commentButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "CommentButton"), for: .normal)
        return button
    }()

    private lazy var numComments: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "UniversCE-Black", size: 12)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black.withAlphaComponent(0.6)

        addSubview(likeButton)
        likeButton.snp.makeConstraints {
            $0.trailing.equalTo(-51)
            $0.top.equalTo(18)
            $0.width.equalTo(35)
            $0.height.equalTo(32.5)
        }

        addSubview(numLikes)
        numLikes.snp.makeConstraints {
            $0.leading.equalTo(likeButton.snp.trailing)
            $0.bottom.equalTo(likeButton).offset(-4)
        }

        addSubview(commentButton)
        commentButton.snp.makeConstraints {
            $0.trailing.equalTo(likeButton.snp.leading).offset(-56)
            $0.bottom.equalTo(likeButton)
            $0.width.equalTo(35.35)
            $0.height.equalTo(35.35)
        }

        addSubview(numComments)
        numComments.snp.makeConstraints {
            $0.leading.equalTo(commentButton.snp.trailing)
            $0.bottom.equalTo(commentButton).offset(-4)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setCommentsAndLikes(post: MapPost?) {
        let liked = post?.likers.contains(UserDataModel.shared.uid) ?? false
        let likeImage = liked ? UIImage(named: "LikeButtonFilled") : UIImage(named: "LikeButton")

        numLikes.text = post?.likers.count ?? 0 > 0 ? String(post?.likers.count ?? 0) : ""
        likeButton.setImage(likeImage, for: .normal)

        let commentCount = max((post?.commentList.count ?? 0) - 1, 0)
        numComments.text = commentCount > 0 ? String(commentCount) : ""
    }
}

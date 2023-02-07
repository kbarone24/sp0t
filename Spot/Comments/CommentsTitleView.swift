//
//  CommentsTitleView.swift
//  Spot
//
//  Created by Kenny Barone on 2/3/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class CommentsTitleView: UIView {
    private lazy var commentsIcon = UIImageView(image: UIImage(named: "CommentsTitleCommentIcon"))
    private lazy var commentsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SFCompactText-Bold", size: 16)
        label.textColor = .black
        return label
    }()
    private lazy var underline: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.layer.cornerRadius = 1
        return view
    }()

    public var commentCount: Int = 0 {
        didSet {
            var commentText = "\(commentCount) comment"
            commentText += commentCount == 1 ? "" : "s"
            commentsLabel.text = commentText
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white

        addSubview(commentsLabel)
        commentsLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview().offset(27.4 / 2)
            $0.bottom.equalTo(-10)
        }

        addSubview(commentsIcon)
        commentsIcon.snp.makeConstraints {
            $0.trailing.equalTo(commentsLabel.snp.leading).offset(-5)
            $0.height.width.equalTo(22.4)
            $0.centerY.equalTo(commentsLabel)
        }

        addSubview(underline)
        underline.snp.makeConstraints {
            $0.bottom.equalToSuperview()
            $0.leading.equalTo(commentsIcon).offset(-2)
            $0.trailing.equalTo(commentsLabel).offset(2)
            $0.height.equalTo(3.5)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

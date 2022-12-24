//
//  CommentSeg.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 12/24/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class CommentSeg: UIButton {
    private(set) lazy var commentIcon: UIImageView = {
        let icon = UIImageView()
        icon.image = UIImage(named: "CommentSegCommentIcon")
        return icon
    }()
    
    var commentLabel: UILabel!

    var commentCount: Int = 0 {
        didSet {
            var commentText = "\(max(commentCount, 0)) comment"
            if commentCount - 1 != 1 { commentText += "s" }
            commentLabel.text = commentText
        }
    }

    var index: Int = 0 {
        didSet {
            let selectedSeg = index == 0
            commentIcon.alpha = selectedSeg ? 1.0 : 0.6
            commentLabel.alpha = selectedSeg ? 1.0 : 0.6
            commentLabel.font = selectedSeg ? UIFont(name: "SFCompactText-Bold", size: 16) : UIFont(name: "SFCompactText-Semibold", size: 16)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(commentIcon)
        commentIcon.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(22.4)
        }

        commentLabel = UILabel {
            $0.textColor = .black
            addSubview($0)
        }
        commentLabel.snp.makeConstraints {
            $0.leading.equalTo(commentIcon.snp.trailing).offset(5)
            $0.centerY.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

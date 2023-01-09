//
//  LikeSeg.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 12/24/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class LikeSeg: UIButton {
    private(set) lazy var likeIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "CommentSegLikeIcon")
        return imageView
    }()
    
    var likeLabel: UILabel!

    var likeCount: Int = 0 {
        didSet {
            var likeText = "\(max(likeCount, 0)) like"
            if likeCount - 1 != 1 { likeText += "s" }
            likeLabel.text = likeText
        }
    }

    var index: Int = 0 {
        didSet {
            let selectedSeg = index == 1
            likeIcon.alpha = selectedSeg ? 1.0 : 0.6
            likeLabel.alpha = selectedSeg ? 1.0 : 0.6
            likeLabel.font = selectedSeg ? UIFont(name: "SFCompactText-Bold", size: 16) : UIFont(name: "SFCompactText-Semibold", size: 16)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        likeLabel = UILabel {
            $0.textColor = .black
            addSubview($0)
        }
        likeLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview().offset(12.5)
            $0.centerY.equalToSuperview()
        }

        addSubview(likeIcon)
        likeIcon.snp.makeConstraints {
            $0.trailing.equalTo(likeLabel.snp.leading).offset(-5)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(22.5)
            $0.height.equalTo(20)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

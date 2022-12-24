//
//  PostButton.swift
//  Spot
//
//  Created by Kenny Barone on 10/6/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

final class PostButton: UIButton {
    
    private(set) lazy var postIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "PostIcon")
        return imageView
    }()
    
    var postText: UILabel!
    override var isEnabled: Bool {
        didSet {
            alpha = isEnabled ? 1.0 : 0.5
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(named: "SpotGreen")
        layer.cornerRadius = 9

        addSubview(postIcon)
        postIcon.snp.makeConstraints {
            $0.leading.equalTo(self.snp.centerX).offset(-30)
            $0.centerY.equalToSuperview().offset(-1)
            $0.height.equalTo(21.5)
            $0.width.equalTo(16)
        }

        postText = UILabel {
            $0.text = "Post"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Bold", size: 16.5)
            addSubview($0)
        }
        postText.snp.makeConstraints {
            $0.leading.equalTo(postIcon.snp.trailing).offset(6)
            $0.centerY.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

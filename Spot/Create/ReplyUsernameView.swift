//
//  ReplyUsernameView.swift
//  Spot
//
//  Created by Kenny Barone on 7/20/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class ReplyUsernameView: UIView {
    private lazy var replyArrow = UIImageView(image: UIImage(named: "ReplyArrow"))

    private lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.467, green: 0.467, blue: 0.467, alpha: 1)
        label.font = UIFont(name: "SFCompactRounded-Medium", size: 17.5)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: .zero)
        backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1)
        layer.cornerRadius = 9

        addSubview(replyArrow)
        replyArrow.snp.makeConstraints {
            $0.leading.equalTo(8)
            $0.top.bottom.equalToSuperview().inset(8.5)
        }

        addSubview(usernameLabel)
        usernameLabel.snp.makeConstraints {
            $0.leading.equalTo(replyArrow.snp.trailing).offset(4)
            $0.centerY.equalToSuperview()
            $0.trailing.equalTo(-12)
        }
    }

    func configure(username: String) {
        usernameLabel.text = username
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//
//  NotificationsButton.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class NotificationsButton: UIButton {
    private lazy var bellView = UIImageView(image: UIImage(named: "NotificationsNavIcon"))
    private lazy var bubbleIcon: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 1, green: 0.421, blue: 0.873, alpha: 1)
        view.layer.cornerRadius = 16 / 2
        view.isHidden = true
        return view
    }()
    var countLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Heavy", size: 11.5)
        label.textAlignment = .center
        return label
    }()

    lazy var pendingCount: Int = 0 {
        didSet {
            countLabel.text = String(pendingCount)
            bubbleIcon.isHidden = pendingCount == 0
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(bellView)
        bellView.addShadow(shadowColor: UIColor.black.cgColor, opacity: 0.5, radius: 4, offset: CGSize(width: 0, height: 1))
        bellView.snp.makeConstraints {
            $0.leading.bottom.equalToSuperview().inset(5)
            $0.width.equalTo(29)
            $0.height.equalTo(29)
        }

        addSubview(bubbleIcon)
        bubbleIcon.snp.makeConstraints {
            $0.trailing.top.equalToSuperview().inset(5)
            $0.height.width.equalTo(16)
        }

        bubbleIcon.addSubview(countLabel)
        countLabel.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

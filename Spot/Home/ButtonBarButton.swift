//
//  ButtonBarButton.swift
//  Spot
//
//  Created by Kenny Barone on 8/19/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class ButtonBarButton: UIButton {
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.layer.cornerRadius = 11
        view.layer.borderWidth = 2.5
        return view
    }()

    private lazy var containerView = UIView()
    private lazy var icon = UIImageView()
    lazy var label: UILabel = {
        let label = UILabel()
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 15)
        label.addShadow(shadowColor: UIColor.black.cgColor, opacity: 0.25, radius: 1, offset: CGSize(width: 0, height: 0.5))
        return label
    }()

    private(set) lazy var unseenIcon: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hexString: "FF00A8")
        view.layer.borderColor = UIColor.white.cgColor
        view.layer.borderWidth = 3
        view.layer.cornerRadius = 19 / 2
        view.clipsToBounds = false
        view.isHidden = true
        return view
    }()

    var hasUnseenNoti = false {
        didSet {
            bringSubviewToFront(unseenIcon)
            unseenIcon.isHidden = !hasUnseenNoti
        }
    }

    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                alpha = 0.6
            } else {
                alpha = 1.0
            }
        }
    }

    init(backgroundColor: UIColor, borderColor: CGColor, image: UIImage, title: String) {
        super.init(frame: .zero)
        clipsToBounds = false
        translatesAutoresizingMaskIntoConstraints = false

        // create separate background view so the unseen noti shows above it
        backgroundView.backgroundColor = backgroundColor
        backgroundView.layer.borderColor = borderColor
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints {
            $0.leading.bottom.equalToSuperview()
            $0.top.equalToSuperview().offset(7.5)
            $0.trailing.equalToSuperview().offset(-5.5)
        }

        let contentContainer = UIView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(contentContainer)
        contentContainer.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
        }

        contentContainer.addSubview(label)
        label.text = title
        label.textColor = .white
        label.snp.makeConstraints {
            $0.trailing.centerY.equalToSuperview()
        }

        contentContainer.addSubview(icon)
        icon.image = image
        icon.snp.makeConstraints {
            $0.trailing.equalTo(label.snp.leading).offset(-8)
            $0.centerY.leading.equalToSuperview()
        }

        addSubview(unseenIcon)
        unseenIcon.snp.makeConstraints {
            $0.top.trailing.equalToSuperview()
            $0.height.width.equalTo(19)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

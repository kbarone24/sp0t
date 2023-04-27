//
//  ProfileTitleView.swift
//  Spot
//
//  Created by Kenny Barone on 3/31/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class ProfileTitleView: UIView {
    override var intrinsicContentSize: CGSize {
        // override to provide touch area
        return CGSize(width: 77, height: 40)
    }

    lazy var backgroundImage: UIImageView = {
        let view = UIImageView(image: UIImage(named: "SpotscoreBackground"))
        view.isUserInteractionEnabled = true
        view.isHidden = true
        return view
    }()
    private(set) lazy var label: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "Gameplay", size: 11.5)
        label.textColor = .white
        return label
    }()

    var score: Int = 0 {
        didSet {
            backgroundImage.isHidden = false
            label.text = String(max(score, 0))
        }
    }

    var showNoti: Bool = false {
        didSet {
            backgroundImage.image = showNoti ? UIImage(named: "SpotscoreNoti") : UIImage(named: "SpotscoreBackground")
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        isUserInteractionEnabled = true

        addSubview(backgroundImage)
        backgroundImage.snp.makeConstraints {
            $0.centerY.equalToSuperview().offset(-4)
            $0.centerX.equalToSuperview()
        }

        backgroundImage.addSubview(label)
        label.snp.makeConstraints {
            $0.centerX.equalToSuperview().offset(0.5)
            $0.bottom.equalToSuperview().offset(-4.5)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

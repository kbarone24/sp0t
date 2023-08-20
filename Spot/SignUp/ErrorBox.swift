//
//  ErrorBox.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 1/19/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit

final class ErrorBox: UIView {
    var label: UILabel = {
        let label = UILabel()
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        label.textColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.00)
        label.textAlignment = .center
        label.font = SpotFonts.SFCompactRoundedRegular.fontWith(size: 14)
        return label
    }()

    var message = "" {
        didSet {
            label.text = message
            label.sizeToFit()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1)

        label.text = message
        addSubview(label)
        label.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.centerY.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

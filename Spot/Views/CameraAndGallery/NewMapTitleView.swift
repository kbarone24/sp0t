//
//  NewMapTitleView.swift
//  Spot
//
//  Created by Kenny Barone on 10/6/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class NewMapTitleView: UIView {
    private(set) lazy var topLabel: UILabel = {
        let label = UILabel()
        label.text = "Share your first post to"
        label.textColor = UIColor(red: 0.729, green: 0.729, blue: 0.729, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 13)
        label.textAlignment = .center
        return label

    }()
    private(set) lazy var mapLabel: UILabel = {
        let label = UILabel()
        label.text = "\(UploadPostModel.shared.mapObject?.mapName ?? "")"
        label.textColor = .white
        label.font = UIFont(name: "SFCompactText-Bold", size: 16.5)
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(topLabel)
        topLabel.snp.makeConstraints {
            $0.top.centerX.equalToSuperview()
        }
        addSubview(mapLabel)
        mapLabel.snp.makeConstraints {
            $0.top.equalTo(topLabel.snp.bottom).offset(2)
            $0.leading.trailing.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

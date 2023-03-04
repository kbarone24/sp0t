//
//  ExploreMapTitleView.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class ExploreMapTitleView: UIView {
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SFCompactText-Semibold", size: 14)
        label.numberOfLines = 0
        label.textColor = UIColor(red: 0.733, green: 0.733, blue: 0.733, alpha: 1)
        label.textAlignment = .center
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        
        addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, description: String) {
        self.descriptionLabel.text = description
        layoutIfNeeded()
    }
}

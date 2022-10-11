//
//  PillButtonWithImage.swift
//  Spot
//
//  Created by Kenny Barone on 10/10/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class PillButtonWithImage: UIButton {
    var icon: UIImageView!
    var label: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        backgroundColor = UIColor(named: "SpotGreen")
        
        let containerView = UIView {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        containerView.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
        }

        icon = UIImageView {
            containerView.addSubview($0)
        }
        icon.snp.makeConstraints {
            $0.leading.centerY.equalToSuperview()
        }
        
        label = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
            containerView.addSubview($0)
        }
        label.snp.makeConstraints {
            $0.leading.equalTo(icon.snp.trailing).offset(6)
            $0.centerY.trailing.equalToSuperview()
        }
    }
    
    func setUp(image: UIImage, str: String) {
        icon.image = image
        label.text = str
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

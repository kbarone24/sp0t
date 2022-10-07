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
    var topLabel: UILabel!
    var mapLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        topLabel = UILabel {
            $0.text = "Share your first post to"
            $0.textColor = UIColor(red: 0.729, green: 0.729, blue: 0.729, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 13)
            $0.textAlignment = .center
            addSubview($0)
        }
        topLabel.snp.makeConstraints {
            $0.top.centerX.equalToSuperview()
        }
        
        mapLabel = UILabel {
            $0.text = "\(UploadPostModel.shared.mapObject!.mapName)"
            $0.textColor = .white
            $0.font = UIFont(name: "SFCompactText-Bold", size: 16.5)
            $0.textAlignment = .center
            addSubview($0)
        }
        mapLabel.snp.makeConstraints {
            $0.top.equalTo(topLabel.snp.bottom).offset(2)
            $0.centerX.equalToSuperview()
        }
    }    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

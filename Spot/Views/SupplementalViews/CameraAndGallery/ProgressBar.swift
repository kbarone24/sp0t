//
//  ProgressBar.swift
//  Spot
//
//  Created by Kenny Barone on 10/6/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class ProgressBar: UIView {
    var progressFill: UIView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    
        backgroundColor = UIColor(named: "SpotGreen")?.withAlphaComponent(0.22)
        layer.cornerRadius = 6
        layer.borderWidth = 2
        layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        
        progressFill = UIView {
            $0.backgroundColor = UIColor(named: "SpotGreen")
            $0.layer.cornerRadius = 6
            addSubview($0)
        }
        progressFill.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(1)
            $0.width.equalTo(0)
            $0.height.equalTo(16)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

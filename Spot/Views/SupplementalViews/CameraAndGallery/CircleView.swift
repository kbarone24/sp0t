//
//  CircleView.swift
//  Spot
//
//  Created by Kenny Barone on 7/5/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class CircleView: UIView {
    
    var number: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp(index: Int) {
        
        let gallery = bounds.height < 25
        let maxSelected = UploadPostModel.shared.selectedObjects.count > 4
        if maxSelected && index == 0 { self.alpha = 0.3 }
        
        layer.borderWidth = gallery ? 1.25 : 1.5
        isUserInteractionEnabled = false
        layer.borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1).cgColor
        
        if number != nil { number.text = "" }
        number = UILabel()

        if index > 0 {
            
            backgroundColor = UIColor(red: 0.18, green: 0.776, blue: 0.816, alpha: 1)
            
            number.text = String(index)
            number.textColor = .black
            let size: CGFloat = bounds.height > 25 ? 18 : 15
            number.font = UIFont(name: "SFCompactText-Heavy", size: size)
            number.textAlignment = .center
            addSubview(number)
            number.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.centerY.equalToSuperview()
                $0.height.equalTo(15)
            }
            
        } else { backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.15) }
    }
}


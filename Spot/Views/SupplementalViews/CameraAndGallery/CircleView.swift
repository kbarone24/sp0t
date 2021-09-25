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
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp(index: Int) {
        
        layer.borderWidth = 1.25
        isUserInteractionEnabled = false
        layer.borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.85).cgColor
        layer.cornerRadius = bounds.width/2
        
        if index > 0 {
            
            backgroundColor = UIColor(red: 0.07, green: 0.75, blue: 0.71, alpha: 1.00)
            
            let minY: CGFloat = bounds.height > 25 ? 6.5 : 4
            let number = UILabel(frame: CGRect(x: 0, y: minY, width: bounds.width, height: 15))
            number.text = String(index)
            number.textColor = .white
            let size: CGFloat = bounds.height > 25 ? 16 : 14
            number.font = UIFont(name: "SFCamera-Semibold", size: size)
            number.textAlignment = .center
            addSubview(number)
            
        } else { backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.15) }
    }
}


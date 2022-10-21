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
    var selected: Bool = false {
        didSet {
            backgroundColor = selected ? UIColor(named: "SpotGreen") : UIColor(red: 0, green: 0, blue: 0, alpha: 0.15)
            let maxSelected = UploadPostModel.shared.selectedObjects.count > 4
            if maxSelected && !selected { self.alpha = 0.3 }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.15)
        layer.borderWidth = 1.25
        isUserInteractionEnabled = false
        layer.borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1).cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

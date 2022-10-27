//
//  TextCancelButton.swift
//  Spot
//
//  Created by Kenny Barone on 10/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class TextCancelButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setTitle("Cancel", for: .normal)
        setTitleColor(UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1), for: .normal)
        titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 14)
        titleLabel?.textAlignment = .center
        titleEdgeInsets = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

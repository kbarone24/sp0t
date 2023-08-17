//
//  AddFriendButton.swift
//  Spot
//
//  Created by Kenny Barone on 1/24/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class AddFriendButton: UIButton {
    init(frame: CGRect, title: String) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
        layer.cornerRadius = 14
        imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 7)
        translatesAutoresizingMaskIntoConstraints = false
        setAttTitle(title: title, color: .black)
    }

    func setAttTitle(title: String, color: UIColor) {
        let title = NSMutableAttributedString(string: title, attributes: [
            NSAttributedString.Key.font: SpotFonts.SFCompactRoundedBold.fontWith(size: 15),
            NSAttributedString.Key.foregroundColor: color
        ])
        setAttributedTitle(title, for: .normal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

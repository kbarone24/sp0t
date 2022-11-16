//
//  SpotSearchBar.swift
//  Spot
//
//  Created by Kenny Barone on 10/7/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class SpotSearchBar: UISearchBar {
    /// set placeholder + delegate
    override init(frame: CGRect) {
        super.init(frame: frame)

        searchBarStyle = .default
        tintColor = UIColor(named: "SpotGreen")
        barTintColor = UIColor(red: 0.945, green: 0.945, blue: 0.949, alpha: 1)
        searchTextField.backgroundColor = UIColor(red: 0.945, green: 0.945, blue: 0.949, alpha: 1)
        searchTextField.leftView?.tintColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        searchTextField.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        autocapitalizationType = .none
        autocorrectionType = .no
        searchTextField.font = UIFont(name: "SFCompactText-Medium", size: 15)
        clipsToBounds = true
        layer.masksToBounds = true
        searchTextField.layer.masksToBounds = true
        searchTextField.clipsToBounds = true
        layer.cornerRadius = 2
        searchTextField.layer.cornerRadius = 2
        backgroundImage = UIImage()
        translatesAutoresizingMaskIntoConstraints = false
        returnKeyType = .done
        enablesReturnKeyAutomatically = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

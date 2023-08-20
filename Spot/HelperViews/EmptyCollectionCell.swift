//
//  EmptyCollectionCell.swift
//  Spot
//
//  Created by Kenny Barone on 4/14/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class EmptyCollectionCell: UICollectionViewCell {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(named: "SpotBlack")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

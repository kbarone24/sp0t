//
//  Tag.swift
//  Spot
//
//  Created by kbarone on 1/8/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class Tag {
    
    var name: String
    var image: UIImage
    var selected: Bool
    var spotCount: Int
    
    init(name: String) {
        self.name = name
        selected = false
        spotCount = 0
        image = UIImage(named: "\(name)Tag") ?? UIImage() 
    }
}

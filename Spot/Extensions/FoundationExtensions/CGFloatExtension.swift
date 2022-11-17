//
//  CGFloatExtension.swift
//  Spot
//
//  Created by Kenny Barone on 11/17/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
extension CGFloat {
    func roundDownTo(multiple: Int) -> Int {
        return multiple * Int((self / CGFloat(multiple)).rounded())
    }
}

//
//  CGPointExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 12/1/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation

extension CGPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.x)
        hasher.combine(self.y)
    }
}

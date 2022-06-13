//
//  Declarative.swift
//  Spot
//
//  Created by Arnold on 6/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation

protocol Declarative: AnyObject {
    init()
}

extension Declarative {
    init(configureHandler: (Self) -> Void) {
        self.init()
        configureHandler(self)
    }
}

extension NSObject: Declarative { }

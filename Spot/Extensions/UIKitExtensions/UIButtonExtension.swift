//
//  UIButtonExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 12/23/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

extension UIButton {
    // MARK: - This should be removed!!!
    // It's not a good practive to initialize views this way with closures
    @available(*, deprecated, message: "This initializer will be removed in the future. It's a practice")
    convenience init(configureHandler: (UIButton) -> Void) {
        self.init()
        configureHandler(self)
    }
}

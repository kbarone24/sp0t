//
//  AddButtonTransition.swift
//  Spot
//
//  Created by Kenny Barone on 8/21/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class AddButtonTransition: CATransition {
    override init() {
        super.init()
        duration = 0.3
        timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        type = CATransitionType.push
        subtype = CATransitionSubtype.fromTop
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

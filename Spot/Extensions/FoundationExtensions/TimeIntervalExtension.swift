//
//  TimeIntervalExtension.swift
//  Spot
//
//  Created by Kenny Barone on 4/5/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation

extension TimeInterval {
    var minutesSeconds: String {
        String(format:"%d:%02d", minute, second, millisecond)
    }
    var hour: Int {
        Int((self/3600).truncatingRemainder(dividingBy: 3600))
    }
    var minute: Int {
        Int((self/60).truncatingRemainder(dividingBy: 60))
    }
    var second: Int {
        Int(truncatingRemainder(dividingBy: 60))
    }
    var millisecond: Int {
        Int((self*1000).truncatingRemainder(dividingBy: 1000))
    }
}

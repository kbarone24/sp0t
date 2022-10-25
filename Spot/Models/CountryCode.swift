//
//  CountryCode.swift
//  Spot
//
//  Created by Kenny Barone on 3/25/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation

struct CountryCode {
    let id: Int
    let code: String
    let name: String

    init(id: Int, code: String, name: String) {
        self.id = id
        self.code = code
        self.name = name
    }
}

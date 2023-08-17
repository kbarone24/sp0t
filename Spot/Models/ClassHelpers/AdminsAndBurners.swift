//
//  AdminsAndBurners.swift
//  Spot
//
//  Created by Kenny Barone on 8/16/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class AdminsAndBurners {
    let burnerPhoneNumbers: [String] = [
        "1111111111",
        "1112223333",
        "0000000000",
        "4442223333",
        "0987654321",
        "8988989999",
        "0009998888",
        "1234567890",
        "2223334444",
        "4204206969",
        "9736324554",
        "9197104789",
        "11111111112",
        "12223334446",
        "8049127534"
    ]

    func containsUserPhoneNumber() -> Bool {
        let formattedNumber = String(UserDataModel.shared.userInfo.phone?.components(separatedBy: CharacterSet.decimalDigits.inverted).joined().suffix(10) ?? "")
        return burnerPhoneNumbers.contains(formattedNumber)
    }
}

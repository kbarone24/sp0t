//
//  ContactInfo.swift
//  Spot
//
//  Created by Kenny Barone on 3/7/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation

struct ContactInfo: Identifiable, Hashable, Equatable {
    var id: ObjectIdentifier
    var realNumber: String
    var formattedNumber: String
    var firstName: String
    var lastName: String
    var thumbnailData: Data?
    var pending: Bool

    var fullName: String {
        var name = firstName
        if name != "" && lastName != "" { name += " " }
        name += lastName
        return name
    }

    init(realNumber: String, formattedNumber: String, firstName: String, lastName: String, thumbnailData: Data?, pending: Bool) {
        id = ObjectIdentifier(ContactInfo.self)
        self.realNumber = realNumber
        self.formattedNumber = formattedNumber
        self.firstName = firstName
        self.lastName = lastName
        self.thumbnailData = thumbnailData
        self.pending = pending 
    }
}

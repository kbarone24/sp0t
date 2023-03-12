//
//  AvatarProfile.swift
//  Spot
//
//  Created by Kenny Barone on 3/10/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation

struct AvatarProfile: Identifiable, Hashable, Equatable {
    var id: ObjectIdentifier
    var family: AvatarFamily
    var item: AvatarItem?

    var baseAvatar: Bool {
        return item == nil
    }

    var avatarName: String {
        var name = family.rawValue
        if let itemName = item?.rawValue {
            name += itemName
        }
        return name
    }

    init(family: AvatarFamily, item: AvatarItem? = nil) {
        id = ObjectIdentifier(AvatarProfile.self)
        self.family = family
        self.item = item
    }
}

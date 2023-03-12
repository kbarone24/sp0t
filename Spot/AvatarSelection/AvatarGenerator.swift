//
//  avatarURLs.swift
//  Spot
//
//  Created by Shay Gyawali on 8/3/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import MapKit
import UIKit

enum AvatarFamily: String, CaseIterable {
    case Bear
    case Bunny
    case Cow
    case Deer
    case Elephant
    case Giraffe
    case Lion
    case Monkey
    case Panda
    case Pig
}

enum AvatarItem: String, CaseIterable {
    case CatEyeShades
    case HardoShades
    case HeartShades
    case LennonShades
    case ScubaShades
    case SpikeyShades
}

final class AvatarGenerator {
    private init() {}
    static let shared = AvatarGenerator()

    func getBaseAvatars() -> [AvatarProfile] {
        var profiles: [AvatarProfile] = []
        let families = AvatarFamily.allCases.shuffled()
        for family in families {
            profiles.append(AvatarProfile(family: family))
        }
        return profiles
    }

    func getStylizedAvatars(family: AvatarFamily) -> [AvatarProfile] {
        var profiles: [AvatarProfile] = []
        let items = AvatarItem.allCases.shuffled()
        for item in items {
            profiles.append(AvatarProfile(family: family, item: item))
        }
        // add base avatar
        profiles.insert(AvatarProfile(family: family), at: 0)
        return profiles
    }
}

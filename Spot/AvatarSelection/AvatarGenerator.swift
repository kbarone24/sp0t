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
    case Croc
    case Chicken
    case Penguin
    case Cat
    case Rhino
    case Cheetah
    case PolarBear
    case Koala
    case Boar
    case Dragon
    case Skunk
    case Zebra
    case Butterfly
    case BlueJay
    case Bee
    case Unicorn
    case Frog
    case Jelly
    case Flower
    case Robot
    case Alien
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

    func getUnlockableAvatars() -> [AvatarProfile] {
        var profiles = [AvatarProfile]()
        let families = AvatarFamily.allCases
        for family in families {
            let profile = AvatarProfile(family: family)
            if profile.unlockScore > 0 {
                profiles.append(profile)
            }
        }
        return profiles.sorted(by: { $0.unlockScore < $1.unlockScore })
    }

    func getBaseAvatars() -> [AvatarProfile] {
        var profiles = [AvatarProfile]()
        let families = AvatarFamily.allCases.shuffled()
        for family in families {
            let profile = AvatarProfile(family: family)
            if profile.isUnlocked {
                profiles.append(AvatarProfile(family: family))
            }
        }
        return profiles.sorted(by: { $0.unlockScore > $1.unlockScore })
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

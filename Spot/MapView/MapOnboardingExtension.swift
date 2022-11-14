//
//  MapOnboardingExtension.swift
//  Spot
//
//  Created by Kenny Barone on 9/1/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation
import MapKit
import UIKit

extension MapController {
    func userInChapelHill() -> Bool {
        let chapelHillLocation = CLLocation(latitude: 35.913_2, longitude: -79.055_8)
        let distance = UserDataModel.shared.currentLocation.distance(from: chapelHillLocation)
        // include users within 10km of downtown CH
        return distance / 1_000 < 10
    }

    func loadAdditionalOnboarding() {
        let posts = friendsPostsDictionary.count
         if UserDataModel.shared.userInfo.avatarURL ?? "" == "" {
            let avc = AvatarSelectionController(sentFrom: .map)
            self.navigationController?.pushViewController(avc, animated: true)

        } else if userInChapelHill() {
            displayHeelsMap()

        } else if UserDataModel.shared.userInfo.friendIDs.count < 4 && posts == 0 {
            self.addFriendsView = AddFriendsView {
                $0.layer.cornerRadius = 13
                $0.isHidden = false
                self.view.addSubview($0)
            }

            self.addFriendsView.addFriendButton.addTarget(self, action: #selector(self.findFriendsTap(_:)), for: .touchUpInside)
            self.addFriendsView.snp.makeConstraints {
                $0.height.equalTo(160)
                $0.leading.trailing.equalToSuperview().inset(16)
                $0.centerY.equalToSuperview()
            }
        }
    }

    func displayHeelsMap() {
        if !(UserDataModel.shared.userInfo.respondedToCampusMap ?? false) {
            openExploreMaps(onboarding: true)
        }
    }
}

extension MapController: MapCodeDelegate {
    func finishPassing(newMapID: String) {
        self.newMapID = newMapID
    }
}

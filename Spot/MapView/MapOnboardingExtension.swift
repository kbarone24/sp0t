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

    func loadAdditionalOnboarding() {
        let posts = postDictionary.count
        if UserDataModel.shared.userInfo.avatarURL ?? "" == "" {
            let avc = AvatarSelectionController(sentFrom: .map)
            self.navigationController?.pushViewController(avc, animated: true)

        } else if UserDataModel.shared.currentLocation.userInChapelHill() {
            displayHeelsMap()

        } else if UserDataModel.shared.userInfo.friendIDs.count < 4 && posts == 0 {
            view.addSubview(addFriendsView)
            addFriendsView.addFriendButton.addTarget(self, action: #selector(findFriendsTap), for: .touchUpInside)
            addFriendsView.snp.makeConstraints {
                $0.height.equalTo(160)
                $0.leading.trailing.equalToSuperview().inset(16)
                $0.centerY.equalToSuperview()
            }
        }
    }

    func displayHeelsMap() {
        if !(UserDataModel.shared.userInfo.respondedToCampusMap ?? false) && UserDataModel.shared.currentLocation.userInChapelHill() {
            openExploreMaps(onboarding: true)
            UserDataModel.shared.userInfo.respondedToCampusMap = true
            db.collection("users").document(uid).updateData(["respondedToCampusMap": true])
        }
    }
}

extension MapController: MapCodeDelegate {
    func finishPassing(newMapID: String) {
        self.newMapID = newMapID
    }
}

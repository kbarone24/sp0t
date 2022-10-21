//
//  MapOnboardingExtension.swift
//  Spot
//
//  Created by Kenny Barone on 9/1/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import MapKit

extension MapController {
    func userInChapelHill() -> Bool {
        let chapelHillLocation = CLLocation(latitude: 35.9132, longitude: -79.0558)
        let distance = UserDataModel.shared.currentLocation.distance(from: chapelHillLocation)
        /// include users within 10km of downtown CH
        return distance/1000 < 10
    }
    
    func loadAdditionalOnboarding() {
        let posts = friendsPostsDictionary.count
         if (UserDataModel.shared.userInfo.avatarURL ?? "" == "") {
            let avc = AvatarSelectionController(sentFrom: .map)
            self.navigationController!.pushViewController(avc, animated: true)
            
        } else if !(UserDataModel.shared.userInfo.respondedToCampusMap ?? false) {
            displayHeelsMap()
            
        } else if (UserDataModel.shared.userInfo.friendIDs.count < 4 && posts == 0) {
            self.addFriendsView = AddFriendsView {
                $0.layer.cornerRadius = 13
                $0.isHidden = false
                self.view.addSubview($0)
            }
            
            self.addFriendsView.addFriendButton.addTarget(self, action: #selector(self.findFriendsTap(_:)), for: .touchUpInside)
            self.addFriendsView.snp.makeConstraints{
                $0.height.equalTo(160)
                $0.leading.trailing.equalToSuperview().inset(16)
                $0.centerY.equalToSuperview()
            }
        }
    }
    
    
    func displayHeelsMap() {
        /// maps list check shouldnt be necessary anymore
        if userInChapelHill() && !UserDataModel.shared.userInfo.mapsList.contains(where: {$0.id == heelsMapID}) {
            let vc = HeelsMapPopUpController()
            vc.delegate = self
            DispatchQueue.main.async { self.present(vc, animated: true) }
            db.collection("users").document(uid).updateData(["respondedToCampusMap" : true])
        }
    }
}

extension MapController: MapCodeDelegate {
    func finishPassing(newMapID: String) {
        self.newMapID = newMapID
    }
}

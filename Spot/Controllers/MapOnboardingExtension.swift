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
        }
        else if (UserDataModel.shared.userInfo.friendIDs.count < 6 && posts == 0) {
            self.addFriends = AddFriendsView {
                $0.layer.cornerRadius = 13
                $0.isHidden = false
                self.view.addSubview($0)
            }
            
            self.addFriends.addFriendButton.addTarget(self, action: #selector(self.findFriendsTap(_:)), for: .touchUpInside)
            self.addFriends.snp.makeConstraints{
                $0.height.equalTo(160)
                $0.leading.trailing.equalToSuperview().inset(16)
                $0.centerY.equalToSuperview()
            }
        }
    }
}

extension MapController: MapControllerDelegate {

    func displayHeelsMap() {
        if userInChapelHill() && !UserDataModel.shared.userInfo.mapsList.contains(where: {$0.id == heelsMapID}) {
            let vc = HeelsMapPopUpController()
            vc.mapDelegate = self
            self.present(vc, animated: true)
        }
    }
    
    func addHeelsMap(heelsMap: CustomMap) {
        UserDataModel.shared.userInfo.mapsList.append(heelsMap)
        self.db.collection("maps").document("9ECABEF9-0036-4082-A06A-C8943428FFF4").updateData([
            "memberIDs": FieldValue.arrayUnion([uid]),
            "likers": FieldValue.arrayUnion([uid])
        ])
        reloadMapsCollection(resort: true, newPost: true)
        self.homeFetchGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            self.getRecentPosts(map: heelsMap)
        }
    }
}


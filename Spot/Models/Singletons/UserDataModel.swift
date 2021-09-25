//
//  UserDataModel.swift
//  Spot
//
//  Created by Kenny Barone on 9/8/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import Firebase

/// keep main user data in a singleton to avoid having to pass mapVC too much. Serves the function of the primary global variable
class UserDataModel {
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    static let shared = UserDataModel()
    
    var adminIDs: [String] = []
    var friendIDs: [String] = []
    var friendsList: [UserProfile] = []

    var userInfo: UserProfile!
    var userSpots: [String] = []
    var userCity: String = ""
    
    var screenSize = UIScreen.main.bounds.height < 800 ? 0 : UIScreen.main.bounds.width > 400 ? 2 : 1 /// 0 = iphone8-, 1 = iphoneX + with 375 width, 2 = iPhoneX+ with 414 width
    var largeScreen = UIScreen.main.bounds.width > 800
    
    var currentLocation: CLLocation!
    
    init() {
        userInfo = UserProfile(username: "", name: "", imageURL: "", currentLocation: "", userBio: "")
        userInfo.id = ""
        currentLocation = CLLocation()
    }
        
    func destroy() {
        adminIDs.removeAll()
        friendIDs.removeAll()
        friendsList.removeAll()
        userInfo = UserProfile(username: "", name: "", imageURL: "", currentLocation: "", userBio: "")
        userSpots.removeAll()
        userCity = ""
    }
}

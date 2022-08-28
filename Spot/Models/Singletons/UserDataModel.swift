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
    var uid: String { Auth.auth().currentUser?.uid ?? "invalid user" }
    static let shared = UserDataModel()
    
    var userInfo: UserProfile!
    var adminIDs: [String] = []
    var deletedPostIDs: [String] = []
    var userSpots: [String] = []
    var userCity: String = ""
    
    var screenSize = UIScreen.main.bounds.height < 800 ? 0 : UIScreen.main.bounds.width > 400 ? 2 : 1 /// 0 = iphone8-, 1 = iphoneX + with 375 width, 2 = iPhoneX+ with 414 width
    var largeScreen = UIScreen.main.bounds.width > 800
    
    var maxAspect: CGFloat {
        return screenSize == 0 ? 1.7 : screenSize == 1 ? 1.75 : 1.81
    }
    
    var currentLocation: CLLocation!
    
    init() {
        userInfo = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: "")
        userInfo.id = ""
        currentLocation = CLLocation()
    }
            
    func destroy() {
        userInfo = nil
        userInfo = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: "")
        userInfo.id = ""
        
        adminIDs.removeAll()
        userSpots.removeAll()
        userCity = ""
    }
}

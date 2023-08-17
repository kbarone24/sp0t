//
//  UserDataModel.swift
//  Spot
//
//  Created by Kenny Barone on 9/8/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import CoreLocation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Foundation
import UIKit

/// keep main user data in a singleton to avoid having to pass mapVC too much. Serves the function of the primary global variable
final class UserDataModel {
    var uid: String { Auth.auth().currentUser?.uid ?? "invalid user" }
    static let shared = UserDataModel()

    lazy var userCity: String = ""

    lazy var adminIDs: [String] = []
    lazy var deletedPostIDs: [String] = []
    lazy var deletedFriendIDs: [String] = []

    // 0 = iphone8-, 1 = iphoneX + with 375 width, 2 = iPhoneX+ with 414 width
    var screenSize = UIScreen.main.bounds.height < 800 ? 0 : UIScreen.main.bounds.width > 400 ? 2 : 1
    var largeScreen = UIScreen.main.bounds.width > 800

    // MARK: fetch values
    let db = Firestore.firestore()
    var friendsFetched = false
    var notificationsEndDocument: DocumentSnapshot?
    var userListener, notificationsListener: ListenerRegistration?

    var maxAspect: CGFloat {
        return screenSize == 0 ? 1.7 : screenSize == 1 ? 1.78 : 1.83
    }

    var userInfo: UserProfile
    var currentLocation: CLLocation

    lazy var userService: UserServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.userService)
        return service
    }()

    lazy var spotService: SpotServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.spotService)
        return service
    }()

    var pushManager: PushNotificationManager?

    var statusHeight: CGFloat {
        let window = UIApplication.shared.keyWindow
        let minStatusHeight: CGFloat = screenSize == 2 ? 54 : screenSize == 1 ? 47 : 20
        let statusHeight = max(window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 20.0, minStatusHeight)
        return statusHeight
    }

    private init() {
        userInfo = UserProfile()
        userInfo.id = ""
        currentLocation = CLLocation()
        pushManager = PushNotificationManager(userID: uid)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func destroy() {
        userInfo = UserProfile()
        userInfo.id = ""

        adminIDs.removeAll()
        deletedPostIDs.removeAll()
        deletedFriendIDs.removeAll()
        userCity = ""

        userListener?.remove()
    }

    func addListeners() {
        userInfo.id = uid
        DispatchQueue.global(qos: .utility).async {
            self.addUserListener()
            self.spotService?.resetUserHereNow()
        }
    }
}

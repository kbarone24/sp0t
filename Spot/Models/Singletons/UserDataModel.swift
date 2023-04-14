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

    lazy var userSpots: [String] = []
    lazy var userCity: String = ""

    lazy var adminIDs: [String] = []
    lazy var deletedPostIDs: [String] = []
    lazy var deletedMapIDs: [String] = []
    lazy var deletedFriendIDs: [String] = []

    var screenSize = UIScreen.main.bounds.height < 800 ? 0 : UIScreen.main.bounds.width > 400 ? 2 : 1 /// 0 = iphone8-, 1 = iphoneX + with 375 width, 2 = iPhoneX+ with 414 width
    var largeScreen = UIScreen.main.bounds.width > 800

    // MARK: fetch values
    let db = Firestore.firestore()
    lazy var notifications: [UserNotification] = []
    lazy var pendingFriendRequests: [UserNotification] = []
    lazy var notificationsRefreshStatus: RefreshStatus = .activelyRefreshing
    var notificationsFetched = false
    var friendsFetched = false
    var notificationsEndDocument: DocumentSnapshot?
    var userListener, mapsListener, notificationsListener: ListenerRegistration?

    var muteAudio = false
    
    var maxAspect: CGFloat {
        return screenSize == 0 ? 1.7 : screenSize == 1 ? 1.78 : 1.83
    }

    var userInfo: UserProfile
    var currentLocation: CLLocation

    lazy var userService: UserServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.userService)
        return service
    }()

    lazy var mapService: MapPostServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.mapPostService)
        return service
    }()

    var pushManager: PushNotificationManager?

    private init() {
        userInfo = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: "")
        userInfo.id = ""
        currentLocation = CLLocation()
        pushManager = PushNotificationManager(userID: uid)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func destroy() {
        userInfo = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: "")
        userInfo.id = ""

        adminIDs.removeAll()
        deletedPostIDs.removeAll()
        deletedMapIDs.removeAll()
        deletedFriendIDs.removeAll()
        userSpots.removeAll()
        userCity = ""

        notifications.removeAll()
        pendingFriendRequests.removeAll()
        notificationsEndDocument = nil
        userListener?.remove()
        mapsListener?.remove()
        notificationsListener?.remove()
    }

    func addListeners() {
        DispatchQueue.global(qos: .utility).async {
            self.addUserListener()
            self.addMapsListener()
            self.addNotificationsListener()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendRequestAccept(_:)), name: NSNotification.Name(rawValue: "AcceptedFriendRequest"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostDelete(_:)), name: NSNotification.Name(rawValue: "DeletePost"), object: nil)
    }
}

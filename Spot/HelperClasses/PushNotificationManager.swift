//
//  PushNotificationManager.swift
//  Spot
//
//  Created by kbarone on 10/15/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFirestore
import FirebaseMessaging
import Foundation
import Mixpanel
import UIKit
import UserNotifications

class PushNotificationManager: NSObject, MessagingDelegate, UNUserNotificationCenterDelegate {
    let userID: String

    init(userID: String) {
        self.userID = userID
        super.init()
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            if settings.authorizationStatus == .authorized {
                DispatchQueue.main.async { self.registerForNotifications() }
            }
        }
    }

    func checkNotificationsAuth() {
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            if settings.authorizationStatus != .authorized {
                // Either denied or notDetermined, ask for access on notis open
                let authOptions: UNAuthorizationOptions = [.alert, .badge]
                UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { (granted: Bool, _) in
                    if granted {
                        DispatchQueue.main.async {
                            self.registerForNotifications()
                        }
                    } else {
                        Mixpanel.mainInstance().track(event: "NotificationsAccessDenied")
                    }
                }
            }
        }
    }

    private func registerForNotifications() {
        Mixpanel.mainInstance().track(event: "NotificationsEnabled")
        Messaging.messaging().delegate = self
        UIApplication.shared.registerForRemoteNotifications()
        updateFirestorePushToken()
    }

    private func updateFirestorePushToken() {
        if let token = Messaging.messaging().fcmToken {
            let usersRef = Firestore.firestore().collection("users").document(userID)
            usersRef.setData(["notificationToken": token], merge: true)
        }
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        updateFirestorePushToken()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        var payload: [String: Any] = [:]
        if let popID = response.notification.request.content.userInfo["popID"] {
            payload["popID"] = popID
        }

        if let postID = response.notification.request.content.userInfo["postID"] {
            payload["postID"] = postID
        }
        if let mapID = response.notification.request.content.userInfo["spotID"] {
            payload["spotID"] = mapID
        }
        if let commentID = response.notification.request.content.userInfo["commentID"] {
            payload["commentID"] = commentID
        }
        NotificationCenter.default.post(Notification(name: Notification.Name("IncomingNotification"), object: nil, userInfo: payload))
        completionHandler()
    }
}

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
    var receivedNoti = false
    //  var notificationName = Notification.Name("sentFromNotification")

    init(userID: String) {
        self.userID = userID
        super.init()
    }

    func registerForPushNotifications() {
        updateFirestorePushTokenIfNeeded()
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            if settings.authorizationStatus != .authorized {
                // Either denied or notDetermined
                let authOptions: UNAuthorizationOptions = [.alert, .badge]
                UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { (granted: Bool, _) in
                    if granted {
                        DispatchQueue.main.async {
                            Messaging.messaging().delegate = self
                            UIApplication.shared.registerForRemoteNotifications()
                            self.updateFirestorePushTokenIfNeeded()
                        }
                    } else { Mixpanel.mainInstance().track(event: "NotificationsAccessDenied") }
                }
            }
        }
        UNUserNotificationCenter.current().delegate = self
    }

    func updateFirestorePushTokenIfNeeded() {
        if let token = Messaging.messaging().fcmToken {
            let usersRef = Firestore.firestore().collection("users").document(userID)
            usersRef.setData(["notificationToken": token], merge: true)
        }
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        updateFirestorePushTokenIfNeeded()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        receivedNoti = true
        // tell the app that we have finished processing the user’s action / response
        completionHandler()
    }
}

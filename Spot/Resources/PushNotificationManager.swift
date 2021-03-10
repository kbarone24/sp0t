//
//  PushNotificationManager.swift
//  Spot
//
//  Created by kbarone on 10/15/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseMessaging
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
        
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            
            if settings.authorizationStatus == .authorized {
                return
            }
            
            else {
                // Either denied or notDetermined
                let authOptions: UNAuthorizationOptions = [.alert, .badge]
                UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { (granted: Bool, err) in
                    
                    if granted {
                        DispatchQueue.main.async {
                            Messaging.messaging().delegate = self
                            UIApplication.shared.registerForRemoteNotifications()
                            self.updateFirestorePushTokenIfNeeded()
                        }
                    }
                }
            }
        }
        
        UNUserNotificationCenter.current().delegate = self
        
    }
    
    func updateFirestorePushTokenIfNeeded() {
        
        if let token = Messaging.messaging().fcmToken {
            let usersRef = Firestore.firestore().collection("users").document(userID)
            print("register", token)
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


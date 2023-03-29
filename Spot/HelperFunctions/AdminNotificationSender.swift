//
//  AdminNotificationSender.swift
//  Spot
//
//  Created by Kenny Barone on 1/12/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import FirebaseFirestore
import Firebase

class AdminNotificationSender {
    let db = Firestore.firestore()

    private func sendPushNotification(token: String, title: String, body: String) {
        let urlString = "https://fcm.googleapis.com/fcm/send"
        guard let url = NSURL(string: urlString) else { return }
        let paramString: [String: Any] = ["to": token,
                                           "notification": ["title": title, "body": body]
        ]

        let request = NSMutableURLRequest(url: url as URL)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: paramString, options: [.prettyPrinted])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "key=AAAAYHoPwzI:APA91bHBXGQ2Dyb6MehENaYyFB8A8JE4wZQ_oPegX5GdeDWd-_3lwlC6nBE84M_4BTMd5CBgtYAeq32ii5FRfeMoZq2uMTTb39pSKgFmDvuxLjPocEIVVD7IHo7V2ndEgfDRQcPuKU59",
            forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request as URLRequest) { (data, _, _) in
            do {
                if let jsonData = data {
                    if let jsonDataDict = try JSONSerialization.jsonObject(
                        with: jsonData,
                        options: JSONSerialization.ReadingOptions.allowFragments)
                        as? [String: AnyObject] {
                        NSLog("Received data:\n\(jsonDataDict))")
                    }
                }
            } catch let err as NSError {
                print(err.debugDescription)
            }
        }
        task.resume()
    }

    func sendNotificationsTo(userIDs: [String], title: String, body: String) {
        for id in userIDs {
            db.collection("users").document(id).getDocument { doc, _ in
                guard let token = doc?.get("notificationToken") as? String else { return }
                print("got token")
                self.sendPushNotification(token: token, title: title, body: body)
            }
        }
    }

    func sendNotificationsToHeelsmapMembers(title: String, body: String) {
        db.collection("maps").document("9ECABEF9-0036-4082-A06A-C8943428FFF4").getDocument { doc, _ in
            if let members = doc?.get("memberIDs") as? [String] {
                self.sendNotificationsTo(userIDs: members, title: title, body: body)
            }
        }
    }
}

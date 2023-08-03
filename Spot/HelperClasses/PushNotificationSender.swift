//
//  PushNotificationSender.swift
//  Spot
//
//  Created by kbarone on 10/15/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class PushNotificationSender {
    // change to uid and get username // token from this or handle all in the sender class and use string interpolation

    func sendPushNotification(token: String, title: String, body: String) {

        let urlString = "https://fcm.googleapis.com/fcm/send"
        let url = NSURL(string: urlString)!
        let paramString: [String: Any] = ["to": token,
                                           "notification": ["title": title, "body": body]
        ]

        let request = NSMutableURLRequest(url: url as URL)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: paramString, options: [.prettyPrinted])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("key=AAAAYHoPwzI:APA91bHBXGQ2Dyb6MehENaYyFB8A8JE4wZQ_oPegX5GdeDWd-_3lwlC6nBE84M_4BTMd5CBgtYAeq32ii5FRfeMoZq2uMTTb39pSKgFmDvuxLjPocEIVVD7IHo7V2ndEgfDRQcPuKU59", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request as URLRequest) { (data, _, _) in
            do {
                if let jsonData = data {
                    if let jsonDataDict = try JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: AnyObject] {
                        NSLog("Received data:\n\(jsonDataDict))")
                    }
                }
            } catch let err as NSError {
                print(err.debugDescription)
            }
        }
        task.resume()
    }
}

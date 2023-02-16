//
//  TabBarFetchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 2/9/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel

extension SpotTabBarController {
    func getAdmins() {
        db.collection("users").whereField("admin", isEqualTo: true).getDocuments { (snap, _) in
            guard let snap = snap else { return }
            for doc in snap.documents { UserDataModel.shared.adminIDs.append(doc.documentID)
            }
        }
        // opt kenny/tyler/b0t/hog/test/john/ella out of tracking
        let uid = UserDataModel.shared.uid
        if uid == "djEkPdL5GQUyJamNXiMbtjrsUYM2" ||
            uid == "kwpjnnDCSKcTZ0YKB3tevLI1Qdi2" ||
            uid == "T4KMLe3XlQaPBJvtZVArqXQvaNT2" ||
            uid == "Za1OQPFoCWWbAdxB5yu98iE8WZT2" ||
            uid == "oAKwM2NgLjTlaE2xqvKEXiIVKYu1" ||
            uid == "2MpKovZvUYOR4h7YvAGexGqS7Uq1" ||
            uid == "W75L1D248ibsm6heDoV8AzlWXCx2" {
            Mixpanel.mainInstance().optOutTracking()
        }
    }
}

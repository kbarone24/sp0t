//
//  UIViewExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import UIKit

extension UIView {

    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }

    func getTimestamp(postTime: Firebase.Timestamp) -> String {
        let seconds = postTime.seconds
        let current = Date().timeIntervalSince1970
        let currentTime = Int64(current)
        let timeSincePost = currentTime - seconds

        if timeSincePost < 604_800 {
            // return time since post

            if timeSincePost <= 86_400 {
                if timeSincePost <= 3_600 {
                    if timeSincePost <= 60 {
                        return "\(timeSincePost)s"
                    } else {
                        let minutes = timeSincePost / 60
                        return "\(minutes)m"
                    }
                } else {
                    let hours = timeSincePost / 3_600
                    return "\(hours)h"
                }
            } else {
                let days = timeSincePost / 86_400
                return "\(days)d"
            }
        } else {
            // return date
            let timeInterval = TimeInterval(integerLiteral: seconds)
            let date = Date(timeIntervalSince1970: timeInterval)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "M/dd/yy"
            let dateString = dateFormatter.string(from: date)
            return dateString
        }
    }
}

//
//  UsernameLabel.swift
//  Spot
//
//  Created by Kenny Barone on 9/20/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

final class UsernameLabel: UILabel {
    var username: UILabel!
    var timestamp: UILabel!
    var moreLabel: UILabel!
    var spotAnnotation = false

    func setUp(post: MapPost, moreText: String, spotAnnotation: Bool) {
        self.spotAnnotation = spotAnnotation
        layer.cornerRadius = 6
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        
        username = UILabel {
            let minX: CGFloat = spotAnnotation ? 8 : 4
            $0.frame = CGRect(x: minX, y: 5, width: 42, height: 12)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 11.5)
            $0.textColor = .black
            $0.numberOfLines = 1
            $0.text = post.userInfo?.username ?? ""
            $0.sizeToFit()
            addSubview($0)
        }

        timestamp = UILabel {
            $0.frame = CGRect(x: 46, y: 2.8, width: 20, height: 12)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 10)
            $0.textColor = UIColor(red: 0.575, green: 0.575, blue: 0.575, alpha: 1)
            $0.numberOfLines = 1
            addSubview($0)
        }

        moreLabel = UILabel {
            $0.frame = CGRect(x: 2, y: 17, width: 42, height: 12)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 11.5)
            $0.textColor = .black
            $0.numberOfLines = 1
            addSubview($0)
        }

        let moreShowing = moreText != ""
        if moreShowing {
            timestamp.isHidden = true
            moreLabel.text = moreText
            moreLabel.sizeToFit()

            let spaceWidth: CGFloat = spotAnnotation ? 14 : 8
            let newWidth = max(moreLabel.frame.width, username.frame.width) + spaceWidth
            resizeView(newWidth: newWidth)
        } else {
            timestamp.text = post.timestamp.toString(allowDate: false)
            timestamp.sizeToFit()
            moreLabel.isHidden = true

            let spaceWidth: CGFloat = spotAnnotation ? 16 : 12
            let newWidth = username.bounds.width + timestamp.bounds.width + spaceWidth
            resizeView(newWidth: newWidth)
        }
    }

    func resizeView(newWidth: CGFloat) {
        frame = CGRect(x: frame.minX, y: frame.minY, width: newWidth, height: bounds.height)
    }

    func repositionSubviews(minX: CGFloat, minY: CGFloat) {
        let usernameHeight = moreLabel.isHidden ? username.bounds.height + 4 : bounds.height
        let adjustedY = minY + (bounds.height - usernameHeight) / 2
        frame = CGRect(x: minX, y: adjustedY, width: bounds.width, height: usernameHeight)
        let usernameX: CGFloat = spotAnnotation ? 10 : 4
        username.frame = CGRect(x: usernameX, y: 2, width: username.bounds.width, height: username.bounds.height)
        timestamp.frame = CGRect(x: username.frame.maxX + 2, y: 2.8, width: timestamp.bounds.width, height: timestamp.bounds.height)
        moreLabel.frame = CGRect(x: 4, y: username.bounds.maxY, width: moreLabel.bounds.width, height: moreLabel.bounds.height)
    }
}

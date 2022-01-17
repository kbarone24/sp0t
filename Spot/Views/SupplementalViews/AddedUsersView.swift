//
//  AddedUsersView.swift
//  Spot
//
//  Created by Kenny Barone on 11/5/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import FirebaseUI

class AddedUsersView: UIView {
    
    func setUp(users: [UserProfile]) {

        backgroundColor = nil
        
        /// add extra cell (first because working right to left
        var minX = bounds.width - 23
        if users.count > 3 {
            let extraView = UILabel(frame: CGRect(x: minX, y: 2, width: 23, height: 23))
            extraView.text = "+ \(users.count - 3)"
            extraView.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
            extraView.font = UIFont(name: "SFCompactText-Semibold", size: 13)
            extraView.textAlignment = .center
            addSubview(extraView)
            minX -= 23
        }
        
        /// add first 3 tagged users
        for user in users.prefix(3).reversed() {

            let userView = UIImageView(frame: CGRect(x: minX, y: 0, width: 24, height: 24))
            userView.layer.cornerRadius = 7
            userView.layer.borderWidth = 2.5
            userView.layer.borderColor = UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1.00).cgColor
            userView.clipsToBounds = true
            userView.backgroundColor = .clear
            addSubview(userView)
            
            let url = user.imageURL
            if url != "" {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
                userView.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
            }
            
            minX -= 17
        }
    }
}

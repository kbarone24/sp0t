//
//  UploadPrivacyCell.swift
//  Spot
//
//  Created by Kenny Barone on 9/22/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class UploadPrivacyCell: UITableViewCell {
    
    var icon: UIImageView!
    var topLine: UIView!
    var label: UILabel!
    var privacyButton: UIButton!
    
    var postPrivacy: String!
    var spotPrivacy: String!
    
    func setUp(postPrivacy: String, spotPrivacy: String) {
        
        backgroundColor = .black
        contentView.backgroundColor = .black
        
        self.postPrivacy = postPrivacy
        self.spotPrivacy = spotPrivacy
        
        resetCell()
        
        topLine = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
        topLine.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        contentView.addSubview(topLine)
        
        icon = UIImageView(frame: CGRect(x: 16, y: 12, width: 19, height: 23))
        icon.image = UIImage(named: "UploadPrivacyIcon")
        contentView.addSubview(icon)
        
        if label != nil { label.text = "" }
        label = UILabel(frame: CGRect(x: 49, y: 15, width: 150, height: 18))
        label.text = "Who can see this post"
        label.textColor = UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1)
        label.font = UIFont(name: "SFCamera-Regular", size: 13.5)
        contentView.addSubview(label)
        
        privacyButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 132, y: 15, width: 120, height: 28))
        var privacyString = postPrivacy == "public" ? "Everyone" : postPrivacy == "friends" ? "Friends-only" : "Invite-only"
        privacyString += "   >"
        privacyButton.setTitle(privacyString, for: .normal)
        privacyButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        privacyButton.setTitleColor(UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1), for: .normal)
        privacyButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 13.5)
        privacyButton.contentHorizontalAlignment = .right
        privacyButton.addTarget(self, action: #selector(privacyTap(_:)), for: .touchUpInside)
        contentView.addSubview(privacyButton)
    }
    
    func resetCell() {
        if label != nil { label.text = "" }
        if icon != nil { icon.image = UIImage() }
        if topLine != nil { topLine.backgroundColor = nil }
        if privacyButton != nil { privacyButton.setTitle("", for: .normal)}
    }
    
    @objc func privacyTap(_ sender: UIButton) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        uploadVC.presentPrivacyPicker()
    }
}

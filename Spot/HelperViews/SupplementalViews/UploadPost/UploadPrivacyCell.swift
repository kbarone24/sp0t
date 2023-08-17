//
//  UploadPrivacyCell.swift
//  Spot
//
//  Created by Kenny Barone on 9/22/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//
/*
import Foundation
import UIKit

class UploadPrivacyCell: UITableViewCell {
    
    var icon: UIImageView!
    var topLine: UIView!
    var label: UILabel!
    var arrow: UIImageView!
    var privacyButton: UIButton!
    
    var postPrivacy: String!
    var spotPrivacy: String!
    var hide = false
    
    func setUp() {
        
        backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1.00)
        contentView.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1.00)
                
        resetCell()
        
        topLine = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
        topLine.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        contentView.addSubview(topLine)
        
        icon = UIImageView(frame: CGRect(x: 16, y: 12, width: 19, height: 23))
        icon.image = UIImage(named: "UploadPrivacyIcon")
        contentView.addSubview(icon)
        
        if label != nil { label.text = "" }
        label = UILabel(frame: CGRect(x: 49, y: 15, width: 150, height: 18))
        label.text = "Privacy options"
        label.textColor = UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Regular", size: 13.5)
        contentView.addSubview(label)
        
        privacyButton = UIButton(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 48))
        privacyButton.addTarget(self, action: #selector(privacyTap(_:)), for: .touchUpInside)
        contentView.addSubview(privacyButton)
    }
    
    func resetCell() {
        if label != nil { label.text = "" }
        if icon != nil { icon.image = UIImage() }
        if topLine != nil { topLine.backgroundColor = nil }
        if arrow != nil { arrow.image = UIImage() }
    }
    
    @objc func privacyTap(_ sender: UIButton) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        uploadVC.presentPrivacyPicker()
    }
}
*/

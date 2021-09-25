//
//  UploadPrivacyViews.swift
//  Spot
//
//  Created by Kenny Barone on 9/22/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

extension UploadPostController {
    
    func presentPrivacyPicker() {

        if maskView != nil && maskView.superview != nil { return }
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        window?.addSubview(maskView)
        
        let pickerView = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 300, width: UIScreen.main.bounds.width, height: 300))
        pickerView.backgroundColor = UIColor(named: "SpotBlack")
        maskView.addSubview(pickerView)
        
        let titleLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 100, y: 10, width: 200, height: 20))
        titleLabel.text = "Privacy"
        titleLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        titleLabel.font = UIFont(name: "SFCamera-Semibold", size: 14)
        titleLabel.textAlignment = .center
        pickerView.addSubview(titleLabel)
        
        let whoCanSee = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 100, y: 28, width: 200, height: 20))
        whoCanSee.text = "Who can see your post?"
        whoCanSee.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        whoCanSee.font = UIFont(name: "SFCamera-Regular", size: 12)
        whoCanSee.textAlignment = .center
        pickerView.addSubview(whoCanSee)
        
        /// can't post non POI spots publicly
        let publicButton = UIButton(frame: CGRect(x: 14, y: 65, width: 171, height: 54))
        publicButton.setImage(UIImage(named: "PublicButton"), for: .normal)
        publicButton.layer.cornerRadius = 7.5
        publicButton.tag = 0
        publicButton.addTarget(self, action: #selector(privacySelect(_:)), for: .touchUpInside)
        
        if postObject.privacyLevel == "public" {
            publicButton.layer.borderWidth = 1
            publicButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        }
        pickerView.addSubview(publicButton)
                        
        let friendsButton = UIButton(frame: CGRect(x: 14, y: 119, width: 171, height: 54))
        friendsButton.setImage(UIImage(named: "FriendsButton"), for: .normal)
        friendsButton.layer.cornerRadius = 7.5
        friendsButton.tag = 1
        friendsButton.addTarget(self, action: #selector(privacySelect(_:)), for: .touchUpInside)
        
        if postObject.privacyLevel == "friends" {
            friendsButton.layer.borderWidth = 1
            friendsButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        }
        
        pickerView.addSubview(friendsButton)
        
        // only can do invite only spots not posts
        if postType == .newSpot {
            let inviteButton = UIButton(frame: CGRect(x: 14, y: friendsButton.frame.maxY + 10, width: 171, height: 54))
            inviteButton.setImage(UIImage(named: "InviteButton"), for: .normal)
            inviteButton.layer.cornerRadius = 7.5
            inviteButton.tag = 2
            inviteButton.addTarget(self, action: #selector(privacySelect(_:)), for: .touchUpInside)
            if postObject.privacyLevel == "invite" {
                inviteButton.layer.borderWidth = 1
                inviteButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
            }
            pickerView.addSubview(inviteButton)
        }
    }
    
    @objc func privacySelect(_ sender: UIButton) {
        
        if maskView == nil { return }
        for subview in maskView.subviews { subview.removeFromSuperview() }

        switch sender.tag {
        
        case 0:
            
            if postType == .newSpot {
                launchSubmitPublic()
                return
                
            } else {
                postObject.privacyLevel = "public"
            }

        case 1:
            postObject.privacyLevel = "friends"
            
        default:
            postObject.privacyLevel = "invite"
            pushInviteFriends()
        }

        maskView.removeGestureRecognizer(privacyCloseTap)
        maskView.removeFromSuperview()
        
        DispatchQueue.main.async { self.tableView.reloadRows(at: [IndexPath(row: 5, section: 0)], with: .none) }
    }
    
    
    func launchSubmitPublic() {
        
        let infoView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 116, y: UIScreen.main.bounds.height/2 - 140, width: 232, height: 190))
        infoView.backgroundColor = UIColor(named: "SpotBlack")
        infoView.layer.cornerRadius = 7.5
        infoView.clipsToBounds = true
        infoView.tag = 2
        maskView.addSubview(infoView)
        
        let botPic = UIImageView(frame: CGRect(x: 21, y: 22, width: 30, height: 34.44))
        botPic.image = UIImage(named: "OnboardB0t")
        infoView.addSubview(botPic)
        
        let botName = UILabel(frame: CGRect(x: botPic.frame.maxX + 8, y: 37, width: 80, height: 20))
        botName.text = "sp0tb0t"
        botName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        botName.font = UIFont(name: "SFcamera-Semibold", size: 12.5)
        infoView.addSubview(botName)
        
        let botComment = UILabel(frame: CGRect(x: 22, y: botPic.frame.maxY + 21, width: 196, height: 15))
        botComment.text = "After uploading this spot will be submitted for approval on the public map."
        botComment.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        botComment.font = UIFont(name: "SFCamera-Regular", size: 14)
        botComment.numberOfLines = 0
        botComment.lineBreakMode = .byWordWrapping
        botComment.sizeToFit()
        botComment.tag = 3
        infoView.addSubview(botComment)
        
        let submitButton = UIButton(frame: CGRect(x: 12, y: botComment.frame.maxY + 15, width: 95, height: 35))
        submitButton.setTitle("Okay", for: .normal)
        submitButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        submitButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 12.5)
        submitButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        submitButton.layer.borderWidth = 1
        submitButton.layer.cornerRadius = 8
        submitButton.addTarget(self, action: #selector(submitPublicTap(_:)), for: .touchUpInside)
        submitButton.tag = 4
        infoView.addSubview(submitButton)
        
        let cancelButton = UIButton(frame: CGRect(x: 122, y: botComment.frame.maxY + 15, width: 95, height: 35))
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor.lightGray, for: .normal)
        cancelButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 12.5)
        cancelButton.layer.borderColor = UIColor.lightGray.cgColor
        cancelButton.layer.borderWidth = 1
        cancelButton.layer.cornerRadius = 8
        cancelButton.addTarget(self, action: #selector(cancelSubmitPublic(_:)), for: .touchUpInside)
        cancelButton.tag = 5
        infoView.addSubview(cancelButton)
    }
    
    @objc func cancelSubmitPublic(_ sender: UIButton) {
        closePrivacyPicker()
    }

    @objc func submitPublicTap(_ sender: UIButton) {
        
        postObject.privacyLevel = "public"
        submitPublic = true
        
        guard let infoView = maskView.subviews.first(where: {$0.tag == 2}) else { return }
        for sub in infoView.subviews {
            if sub.tag > 2 { sub.removeFromSuperview() }
        }
        
        let botComment = UILabel(frame: CGRect(x: 22, y: 75, width: 196, height: 15))
        botComment.text = "I'll let you know if your spot gets approved!"
        botComment.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        botComment.font = UIFont(name: "SFCamera-Regular", size: 14)
        botComment.numberOfLines = 0
        botComment.lineBreakMode = .byWordWrapping
        botComment.sizeToFit()
        botComment.tag = 2
        infoView.addSubview(botComment)
        
        let okButton = UIButton(frame: CGRect(x: 22, y: botComment.frame.maxY + 15, width: 196, height: 40))
        okButton.setTitle("Okay", for: .normal)
        okButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        okButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 12.5)
        okButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        okButton.layer.borderWidth = 1
        okButton.layer.cornerRadius = 10
        okButton.addTarget(self, action: #selector(submitPublicOkay(_:)), for: .touchUpInside)
        infoView.addSubview(okButton)
        
        DispatchQueue.main.async { self.tableView.reloadRows(at: [(IndexPath(row: 5, section: 0))], with: .none)}
    }
        
    @objc func submitPublicOkay(_ sender: UIButton) {
        closePrivacyPicker()
    }
    
    func closePrivacyPicker() {
        for subview in maskView.subviews { subview.removeFromSuperview() }
        maskView.removeGestureRecognizer(privacyCloseTap)
        maskView.removeFromSuperview()
    }
}

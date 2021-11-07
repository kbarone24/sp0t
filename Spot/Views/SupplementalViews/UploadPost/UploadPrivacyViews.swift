//
//  UploadPrivacyViews.swift
//  Spot
//
//  Created by Kenny Barone on 9/22/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

extension UploadPostController {
        
    func presentPrivacyPicker() {

        if maskView != nil && maskView.superview != nil { return }
        privacyCloseTap = UITapGestureRecognizer(target: self, action: #selector(closePrivacyPicker(_:)))
        maskView.addGestureRecognizer(privacyCloseTap)
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        window?.addSubview(maskView)
        
        let pickerHeight: CGFloat = postType == .newSpot ? 390 : 320
        let pickerView = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - pickerHeight, width: UIScreen.main.bounds.width, height: pickerHeight))
        pickerView.backgroundColor = UIColor(named: "SpotBlack")
        maskView.addSubview(pickerView)
        
        let privacyHeight: CGFloat = postType == .newSpot ? 250 : 180
        privacyView = UploadPrivacyPicker(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: privacyHeight))
        privacyView.setUp(privacyLevel: postObject.privacyLevel ?? "friends", postType: postType)
        privacyView.delegate = self
        pickerView.addSubview(privacyView)
        
        showOnFeed = UploadShowOnFeedView(frame: CGRect(x: 0, y: privacyHeight + 20, width: UIScreen.main.bounds.width, height: 50))
        showOnFeed.setUp(hide: postObject.hideFromFeed ?? false)
        showOnFeed.delegate = self
        pickerView.addSubview(showOnFeed)
    }
    
    @objc func closePrivacyPicker(_ sender: UITapGestureRecognizer) {
        closePrivacyPicker()
    }
    
    func closePrivacyPicker() {
        for subview in maskView.subviews { subview.removeFromSuperview() }
        maskView.removeGestureRecognizer(privacyCloseTap)
        maskView.removeFromSuperview()
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
    }
        
    @objc func submitPublicOkay(_ sender: UIButton) {
        closePrivacyPicker()
    }

}

protocol PrivacyPickerDelegate {
    func finishPassingPrivacy(tag: Int)
}

class UploadPrivacyPicker: UIView {
    
    var privacyLevel: String!
    var postType: UploadPostController.PostType!
    var delegate: PrivacyPickerDelegate?
    
    var titleLabel, whoCanSee: UILabel!
    var publicButton, friendsButton, InviteButton: UIButton!
    
    func setUp(privacyLevel: String, postType: UploadPostController.PostType) {
        
        self.privacyLevel = privacyLevel
        self.postType = postType
        resetView()

        titleLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 100, y: 10, width: 200, height: 20))
        titleLabel.text = "Privacy"
        titleLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        titleLabel.font = UIFont(name: "SFCamera-Semibold", size: 14)
        titleLabel.textAlignment = .center
        addSubview(titleLabel)
        
        whoCanSee = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 100, y: 28, width: 200, height: 20))
        whoCanSee.text = "Who can see your post?"
        whoCanSee.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        whoCanSee.font = UIFont(name: "SFCamera-Regular", size: 12)
        whoCanSee.textAlignment = .center
        addSubview(whoCanSee)
        
        /// can't post non POI spots publicly
        publicButton = UIButton(frame: CGRect(x: 14, y: 65, width: 171, height: 54))
        publicButton.setImage(UIImage(named: "PublicButton"), for: .normal)
        publicButton.layer.cornerRadius = 7.5
        publicButton.tag = 0
        publicButton.addTarget(self, action: #selector(privacySelect(_:)), for: .touchUpInside)
        
        if privacyLevel == "public" {
            publicButton.layer.borderWidth = 1
            publicButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        }
        
        addSubview(publicButton)
                        
        friendsButton = UIButton(frame: CGRect(x: 14, y: 119, width: 171, height: 54))
        friendsButton.setImage(UIImage(named: "FriendsButton"), for: .normal)
        friendsButton.layer.cornerRadius = 7.5
        friendsButton.tag = 1
        friendsButton.addTarget(self, action: #selector(privacySelect(_:)), for: .touchUpInside)
        
        if privacyLevel == "friends" {
            friendsButton.layer.borderWidth = 1
            friendsButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        }
        
        addSubview(friendsButton)
        
        var minY: CGFloat = 200
        // only can do invite only spots not posts
        if postType == .newSpot {
            let inviteButton = UIButton(frame: CGRect(x: 14, y: friendsButton.frame.maxY + 10, width: 171, height: 54))
            inviteButton.setImage(UIImage(named: "InviteButton"), for: .normal)
            inviteButton.layer.cornerRadius = 7.5
            inviteButton.tag = 2
            inviteButton.addTarget(self, action: #selector(privacySelect(_:)), for: .touchUpInside)
            
            if privacyLevel == "invite" {
                inviteButton.layer.borderWidth = 1
                inviteButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
            }
            
            addSubview(inviteButton)
            minY += 70
        }
    }
    
    func resetView() {
        for sub in subviews { sub.removeFromSuperview() }
    }

    
    @objc func privacySelect(_ sender: UIButton) {
        delegate?.finishPassingPrivacy(tag: sender.tag)
    }
}

protocol ShowOnFeedDelegate {
    func finishPassingVisibility(hide: Bool)
}

class UploadShowOnFeedView: UIView {
    
    var icon: UIImageView!
    var topLine: UIView!
    var label: UILabel!
    var toggle: UIButton!
    
    var hide = false
    var delegate: ShowOnFeedDelegate?
    
    func setUp(hide: Bool) {
        
        backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1.00)
        
        self.hide = hide
        resetView()
        
        topLine = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
        topLine.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        addSubview(topLine)
        
        icon = UIImageView(frame: CGRect(x: 14, y: 12, width: 28, height: 25))
        icon.image = UIImage(named: "ShowOnFeedIcon")
        icon.contentMode = .scaleAspectFit
        addSubview(icon)
        
        if label != nil { label.text = "" }
        label = UILabel(frame: CGRect(x: 49, y: 15, width: 150, height: 18))
        label.text = "Post to friends feed"
        label.textColor = UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1)
        label.font = UIFont(name: "SFCamera-Regular", size: 13.5)
        addSubview(label)
        
        toggle = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 71.5, y: 5, width: 57.5, height: 38))
        let image = hide ? UIImage(named: "HideToggleOff") : UIImage(named: "HideToggleOn")
        toggle.setImage(image, for: .normal)
        toggle.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        toggle.addTarget(self, action: #selector(toggle(_:)), for: .touchUpInside)
        addSubview(toggle)
    }
    
    func resetView() {
        if topLine != nil { topLine.backgroundColor = nil }
        if icon != nil { icon.image = UIImage() }
        if toggle != nil { toggle.setImage(UIImage(), for: .normal) }

    }
    
    @objc func toggle(_ sender: UIButton) {
        
        hide = !hide
        let image = hide ? UIImage(named: "HideToggleOff") : UIImage(named: "HideToggleOn")
        toggle.setImage(image, for: .normal)
        
        let event = hide ? "HideToggleOff" : "HideToggleOn"
        Mixpanel.mainInstance().track(event: event)
        
        delegate?.finishPassingVisibility(hide: hide)
    }
}

//
//  UploadPrivacyViews.swift
//  Spot
//
//  Created by Kenny Barone on 9/22/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//
/*
import Foundation
import UIKit
import Mixpanel

extension UploadPostController {
        
    func presentPrivacyPicker() {

        if maskView != nil && maskView.superview != nil { return }
        closeKeyboard() /// close caption keyboard if open

        Mixpanel.mainInstance().track(event: "UploadPrivacyPickerOpen", properties: nil)
        
        privacyCloseTap = UITapGestureRecognizer(target: self, action: #selector(closePrivacyPicker(_:)))
        privacyCloseTap.delegate = self
        maskView.addGestureRecognizer(privacyCloseTap)
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        window?.addSubview(maskView)
        
        /// 3 options, new spot, 1 option for post to private spot
        let privacyHeight: CGFloat = postType == .newSpot ? 234 : postType != .postToSpot || postObject.spotPrivacy == "public" ? 182 : 130
        
        let pickerHeight: CGFloat = privacyHeight + 155
        let pickerView = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - pickerHeight, width: UIScreen.main.bounds.width, height: pickerHeight))
        pickerView.layer.cornerRadius = 8
        pickerView.layer.cornerCurve = .continuous
        pickerView.backgroundColor = UIColor(named: "SpotBlack")
        maskView.addSubview(pickerView)

        privacyView = UploadPrivacyPicker(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: privacyHeight))
        privacyView.setUp(privacyLevel: postObject.privacyLevel ?? "friends", spotPrivacy: postObject.spotPrivacy ?? "friends", postType: postType)
        privacyView.delegate = self
        privacyView.tag = 100
        privacyView.layer.cornerRadius = 8
        privacyView.layer.cornerCurve = .continuous
        pickerView.addSubview(privacyView)
        
        showOnFeed = UploadShowOnFeedView(frame: CGRect(x: 0, y: privacyHeight, width: UIScreen.main.bounds.width, height: 100))
        showOnFeed.setUp(hide: postObject.hideFromFeed ?? false)
        showOnFeed.delegate = self
        showOnFeed.tag = 100
        pickerView.addSubview(showOnFeed)
    }
    
    @objc func closePrivacyPicker(_ sender: UITapGestureRecognizer) {
        closePrivacyPicker()
    }
    
    func closePrivacyPicker() {
        /// these views were holding strong references for some reason -> setting to nil seems to fix it
        if privacyView != nil { privacyView.delegate = nil; privacyView = nil }
        if showOnFeed != nil { showOnFeed.delegate = nil; showOnFeed = nil }
        for subview in maskView.subviews { subview.removeFromSuperview() }
        maskView.removeGestureRecognizer(privacyCloseTap)
        maskView.removeFromSuperview()
    }
    
    func launchSubmitPublic() {
        
        if postObject.privacyLevel == "public" { return }
        
        privacyMask = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        privacyMask.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        maskView.addSubview(privacyMask)
        
        let infoView = BotDetailView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 116, y: UIScreen.main.bounds.height/2 - 140, width: 232, height: 190))
        infoView.setUpSubmitPublic()
        infoView.actionButton.addTarget(self, action: #selector(submitPublicOkay(_:)), for: .touchUpInside)
        infoView.cancelButton.addTarget(self, action: #selector(cancelSubmitPublic(_:)), for: .touchUpInside)
        privacyMask.addSubview(infoView)
    }
    
    @objc func cancelSubmitPublic(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "UploadSubmitPublicCancel", properties: nil)
        removeBotDetail()
    }
        
    @objc func submitPublicOkay(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "UploadSubmitPublicOkay", properties: nil)
        removeBotDetail()
        finishPassingPrivacy(tag: 3)
    }
    
    func removeBotDetail() {
        
        if privacyMask != nil {
            for sub in privacyMask.subviews { sub.removeFromSuperview() }
            privacyMask.removeFromSuperview()
        }
        
        for sub in maskView.subviews { sub.removeFromSuperview() }
        maskView.removeFromSuperview()
    }
}

protocol PrivacyPickerDelegate {
    func finishPassingPrivacy(tag: Int)
}

class UploadPrivacyPicker: UIView {
    
    var privacyLevel: String!
    var postType: UploadPostController.PostType!
    var delegate: PrivacyPickerDelegate?
    
    var titleLabel: UILabel!
    var publicButton, friendsButton, InviteButton: UIButton!
    
    func setUp(privacyLevel: String, spotPrivacy: String, postType: UploadPostController.PostType) {
        
        self.privacyLevel = privacyLevel
        self.postType = postType
        resetView()

        titleLabel = UILabel(frame: CGRect(x: 24, y: 25, width: 200, height: 20))
        titleLabel.text = "Who can see my post"
        titleLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        titleLabel.font = UIFont(name: "SFCompactText-Semibold", size: 17)
        addSubview(titleLabel)
        
        var minY: CGFloat = titleLabel.frame.maxY + 20

        /// can't post non POI spots publicly
        if spotPrivacy == "public" || postType != .postToSpot {
            publicButton = UIButton(frame: CGRect(x: 20, y: minY, width: 138, height: 38))
            publicButton.setImage(UIImage(named: "PublicButton"), for: .normal)
            publicButton.layer.cornerRadius = 9
            publicButton.tag = 0
            publicButton.addTarget(self, action: #selector(privacySelect(_:)), for: .touchUpInside)
            
            if privacyLevel == "public" {
                publicButton.layer.borderWidth = 2
                publicButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
            }
            
            addSubview(publicButton)
            minY += 52
        }
               
        if !(postType == .postToSpot && privacyLevel == "invite") {
            friendsButton = UIButton(frame: CGRect(x: 20, y: minY, width: 138, height: 38))
            friendsButton.setImage(UIImage(named: "FriendsButton"), for: .normal)
            friendsButton.layer.cornerRadius = 7.5
            friendsButton.tag = 1
            friendsButton.addTarget(self, action: #selector(privacySelect(_:)), for: .touchUpInside)
            
            if privacyLevel == "friends" {
                friendsButton.layer.borderWidth = 2
                friendsButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
            }
        
            addSubview(friendsButton)
            minY += 52
        }
        
        // only can do invite only spots not posts
        if postType == .newSpot || privacyLevel == "invite" {
            let inviteButton = UIButton(frame: CGRect(x: 20, y: minY, width: 208, height: 38))
            inviteButton.setImage(UIImage(named: "PrivateButton"), for: .normal)
            inviteButton.layer.cornerRadius = 7.5
            inviteButton.tag = 2
            inviteButton.addTarget(self, action: #selector(privacySelect(_:)), for: .touchUpInside)
            
            if privacyLevel == "invite" {
                inviteButton.layer.borderWidth = 2
                inviteButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
            }
            
            addSubview(inviteButton)
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
    
    var topLine: UIView!
    var label: UILabel!
    var toggle: UIButton!
    
    var hide = false
    var delegate: ShowOnFeedDelegate?
    
    func setUp(hide: Bool) {
        
        backgroundColor = nil
        
        self.hide = hide
        resetView()
        
        topLine = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
        topLine.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        addSubview(topLine)
            
        if label != nil { label.text = "" }
        label = UILabel(frame: CGRect(x: 24, y: 25, width: 250, height: 18))
        label.text = "Post to friends feed"
        label.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 17)
        addSubview(label)
        
        toggle = UIButton(frame: CGRect(x: 20, y: label.frame.maxY + 10, width: 62, height: 42))
        let image = hide ? UIImage(named: "HideToggleOff") : UIImage(named: "HideToggleOn")
        toggle.setImage(image, for: .normal)
        toggle.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        toggle.addTarget(self, action: #selector(toggle(_:)), for: .touchUpInside)
        addSubview(toggle)
    }
    
    func resetView() {
        if topLine != nil { topLine.backgroundColor = nil }
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

class BotDetailView: UIView {
    
    var image: UIImageView!
    var name: UILabel!
    var detail: UILabel!
    
    var actionButton: UIButton!
    var cancelButton: UIButton!
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        backgroundColor = UIColor(named: "SpotBlack")
        layer.cornerRadius = 7.5
        clipsToBounds = true
        tag = 2
        
        image = UIImageView(frame: CGRect(x: 21, y: 22, width: 30, height: 34.44))
        image.contentMode = .scaleAspectFill
        addSubview(image)
        
        name = UILabel(frame: CGRect(x: image.frame.maxX + 8, y: 37, width: bounds.width - image.frame.maxX - 8, height: 20))
        name.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        name.font = UIFont(name: "SFcamera-Semibold", size: 12.5)
        name.lineBreakMode = .byTruncatingTail
        addSubview(name)
        
        detail = UILabel(frame: CGRect(x: 22, y: image.frame.maxY + 21, width: 196, height: 15))
        detail.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        detail.font = UIFont(name: "SFCompactText-Regular", size: 14)
        detail.numberOfLines = 0
        detail.lineBreakMode = .byWordWrapping
        detail.tag = 3
        addSubview(detail)
        
        actionButton = UIButton(frame: CGRect(x: 20, y: bounds.height - 45, width: 85, height: 30))
        actionButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        actionButton.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 12.5)
        actionButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        actionButton.layer.borderWidth = 1
        actionButton.layer.cornerRadius = 8
        actionButton.tag = 4
        addSubview(actionButton)
        
        cancelButton = UIButton(frame: CGRect(x: bounds.width - 105, y: bounds.height - 45, width: 85, height: 30))
        cancelButton.setTitleColor(UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1), for: .normal)
        cancelButton.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 12.5)
        cancelButton.layer.borderColor = UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1).cgColor
        cancelButton.layer.borderWidth = 1
        cancelButton.layer.cornerRadius = 8
        cancelButton.tag = 5
        addSubview(cancelButton)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUpSubmitPublic() {
        image.image = UIImage(named: "OnboardB0t")
        name.text = "sp0tb0t"
        detail.text = "After uploading this spot will be submitted for approval on the public map."
        detail.sizeToFit()
        actionButton.setTitle("Okay", for: .normal)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor.lightGray, for: .normal)
        cancelButton.layer.borderColor = UIColor.lightGray.cgColor
    }
    
    func setUp(postDraft: PostDraft, image: UIImage) {
        
        self.image.image = image
        self.image.frame = CGRect(x: 21, y: 22, width: 42, height: 54)
        self.image.layer.cornerRadius = 6
        self.image.layer.masksToBounds = true
        
        name.frame = CGRect(x: self.image.frame.maxX + 12, y: 37, width: bounds.width - self.image.frame.maxX - 8, height: 20)
        name.text = postDraft.spotNames?.first ?? ""
        
        detail.frame = CGRect(x: 22, y: self.image.frame.maxY + 21, width: 196, height: 15)
        detail.text = "Retry failed upload?"
        
        actionButton.setTitle("Submit", for: .normal)
        cancelButton.setTitle("Delete", for: .normal)
    }
}
*/

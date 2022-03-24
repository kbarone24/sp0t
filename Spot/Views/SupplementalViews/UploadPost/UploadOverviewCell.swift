//
//  UploadOverviewCell.swift
//  Spot
//
//  Created by Kenny Barone on 9/16/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Photos
import Mixpanel

/// upload overview cell and subclasses for UploadPostController
class UploadOverviewCell: UITableViewCell, UITextViewDelegate {
    
    var cellHeight: CGFloat!
    
    var spotIcon: UIImageView!
    var spotLabel: UILabel!
    var spotButton: UIButton!
    
    var addedUsersButton: UIButton!
    var addedUsersIcon: UIImageView!
    var addedUsersLabel: UILabel!
    
    var detailView: UIView!
    var captionView: UITextView!
    
    var imagePreview: ImagePreviewView!
    
    var friendsButton: UIButton!
    var tagButton: UIButton!
    var privacyButton: UIButton!
    
    lazy var imageFetcher = ImageFetcher()

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PreviewRemove"), object: nil)
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        selectionStyle = .none
        backgroundColor = .clear
        
        cellHeight = 120

        let backgroundLayer = CAGradientLayer()
        backgroundLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: cellHeight)
       // backgroundLayer.shouldRasterize = true
        backgroundLayer.colors = [
            UIColor.white.withAlphaComponent(0.0).cgColor,
            UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1).withAlphaComponent(0.5).cgColor,
            UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1).cgColor,
            UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1).cgColor
        ]
        backgroundLayer.locations = [0, 0.2, 0.5, 1.0]
        backgroundLayer.startPoint = CGPoint(x: 0.5, y: 0)
        backgroundLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(backgroundLayer, at: 0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp(post: MapPost) {
               
        // load separately to avoid re-laying out collection on reload
        resetDetailView()
        
        let minY: CGFloat = 5
        let alpha = post.spotName == "" ? 0.55 : 1.0
        
        detailView = UIView(frame: CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: cellHeight - minY))
        detailView.backgroundColor = .clear
        detailView.tag = 41
        contentView.addSubview(detailView)
        
        spotIcon = UIImageView(frame: CGRect(x: 15, y: 3, width: 17, height: 17))
        spotIcon.image = post.tag == "" ? UIImage(named: "FeedSpotIcon") : Tag(name: post.tag!).image
        spotIcon.alpha = alpha
        detailView.addSubview(spotIcon)
        
        if post.tag != "" {
            let spotImageButton = UIButton(frame: CGRect(x: spotIcon.frame.minX - 3, y: spotIcon.frame.minY - 3, width: spotIcon.frame.width + 6, height: spotIcon.frame.height + 6))
            spotImageButton.addTarget(self, action: #selector(tagTap(_:)), for: .touchUpInside)
            detailView.addSubview(spotImageButton)
        }
                
        if post.spotName != "" {
            
            spotIcon.alpha = 1.0
            
            let labelWidth: CGFloat = UIScreen.main.bounds.width - spotIcon.frame.maxX - 17
            spotLabel = UILabel(frame: CGRect(x: spotIcon.frame.maxX + 8, y: 4.5, width: labelWidth, height: 15))
            spotLabel.text = post.spotName
            spotLabel.lineBreakMode = .byTruncatingTail
            spotLabel.numberOfLines = 1
            spotLabel.textColor = UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 1)
            spotLabel.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
            spotLabel.sizeToFit()
            if spotLabel.frame.width > labelWidth { spotLabel.frame = CGRect(x: spotIcon.frame.maxX + 8, y: minY + 2, width: labelWidth, height: 15) } /// prevent overflow on sizetofit
            detailView.addSubview(spotLabel)
            
            /// extend past bounds to expand touch area
            spotButton = UIButton(frame: CGRect(x: spotLabel.frame.minX - 3, y: 0, width: spotLabel.frame.width + 15, height: spotLabel.frame.height + 12))
            spotButton.addTarget(self, action: #selector(spotNameTap(_:)), for: .touchUpInside)
            detailView.addSubview(spotButton)
            
        } else { spotIcon.alpha = 0.55 }

    //    let heightAdjust: CGFloat = post.spotName == "" ? 0 : 20
        captionView = UITextView(frame: CGRect(x: spotIcon.frame.minX - 4, y: spotIcon.frame.maxY + 8, width: UIScreen.main.bounds.width - 90, height: cellHeight - spotIcon.frame.maxY - 60))
        captionView.backgroundColor = nil
        captionView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        let captionEmpty = post.caption == ""
        captionView.text = captionEmpty ? "What's up..." : post.caption
        captionView.textColor = captionEmpty ? UIColor(red: 0.267, green: 0.267, blue: 0.267, alpha: 1) : UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha: 1.00)
        captionView.tag = captionEmpty ? 1 : 2 /// 1 is for placeholder text, 2 for acitve text
        captionView.font = UIFont(name: "SFCompactText-Regular", size: 15)
        captionView.keyboardDistanceFromTextField = 50
        captionView.isUserInteractionEnabled = true
        captionView.delegate = self
        captionView.tintColor = .white
        detailView.addSubview(captionView)
        
        if spotButton != nil { contentView.bringSubviewToFront(spotButton) }
        
        if !(post.addedUsers?.isEmpty ?? true) {
            addedUsersIcon = UIImageView(frame: CGRect(x: 17, y: captionView.frame.maxY + 7, width: 14.6, height: 14))
            addedUsersIcon.image = UIImage(named: "TaggedFriendIcon")
            detailView.addSubview(addedUsersIcon)
            
            let labelWidth: CGFloat = UIScreen.main.bounds.width - addedUsersIcon.frame.maxX - 20
            addedUsersLabel = UILabel(frame: CGRect(x: addedUsersIcon.frame.maxX + 5, y: captionView.frame.maxY + 5, width: labelWidth, height: 16))
            addedUsersLabel.textColor = UIColor(red: 0.412, green: 0.412, blue: 0.412, alpha: 1)
            addedUsersLabel.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
            addedUsersLabel.lineBreakMode = .byTruncatingTail
            addedUsersLabel.numberOfLines = 1
            addedUsersLabel.backgroundColor = nil
            
            var textString = ""
            for user in post.addedUserProfiles { textString.append(user.username); if user.id != post.addedUserProfiles.last?.id { textString.append(", ")} }
            addedUsersLabel.text = textString
            addedUsersLabel.sizeToFit()
            if addedUsersLabel.frame.width > labelWidth { addedUsersLabel.frame = CGRect(x: addedUsersIcon.frame.maxX + 5, y: captionView.frame.maxY + 5, width: labelWidth, height: 16) } /// prevent overflow on sizetofit
            detailView.addSubview(addedUsersLabel)
            
            addedUsersButton = UIButton(frame: CGRect(x: addedUsersIcon.frame.minX - 5, y: addedUsersLabel.frame.minY - 5, width: addedUsersLabel.frame.maxX - addedUsersIcon.frame.minX + 10, height: 25))
            addedUsersButton.addTarget(self, action: #selector(friendsTap(_:)), for: .touchUpInside)
            detailView.addSubview(addedUsersButton)
        }
        
        friendsButton = UIButton(frame: CGRect(x: 8, y: detailView.bounds.maxY - 45, width: 94, height: 43))
        friendsButton.setImage(UIImage(named: "UploadFriendsButton"), for: .normal)
        friendsButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        friendsButton.addTarget(self, action: #selector(friendsTap(_:)), for: .touchUpInside)
        detailView.addSubview(friendsButton)
        
        tagButton = UIButton(frame: CGRect(x: friendsButton.frame.maxX + 2, y: friendsButton.frame.minY, width: 78, height: 43))
        tagButton.setImage(UIImage(named: "UploadTagsButton"), for: .normal)
        tagButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        tagButton.addTarget(self, action: #selector(tagTap(_:)), for: .touchUpInside)
        detailView.addSubview(tagButton)
        
        privacyButton = UIButton(frame: CGRect(x: tagButton.frame.maxX + 2, y: friendsButton.frame.minY, width: 95, height: 43))
        privacyButton.setImage(UIImage(named: "UploadPrivacyButton"), for: .normal)
        privacyButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        privacyButton.addTarget(self, action: #selector(privacyTap(_:)), for: .touchUpInside)
        detailView.addSubview(privacyButton)
    }

    @objc func friendsTap(_ sender: UIButton) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        uploadVC.pushInviteFriends()
    }
    
    @objc func tagTap(_ sender: UIButton) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        uploadVC.presentTagPicker()
    }
    
    @objc func privacyTap(_ sender: UIButton) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        uploadVC.presentPrivacyPicker()
    }
    
    @objc func spotNameTap(_ sender: UIButton) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        uploadVC.spotObject == nil ? uploadVC.presentAddNew() : uploadVC.switchToChooseSpot()
    }
         
    func resetDetailView() {
        if captionView != nil { captionView.text = "" }
        if spotIcon != nil { spotIcon.image = UIImage() }
        if spotLabel != nil { spotLabel.text = "" }
        if addedUsersIcon != nil { addedUsersIcon.image = UIImage() }
        if addedUsersLabel != nil { addedUsersLabel.text = "" }
        if friendsButton != nil { friendsButton.setImage(UIImage(), for: .normal) }
        if tagButton != nil { tagButton.setImage(UIImage(), for: .normal) }
        if privacyButton != nil { privacyButton.setImage(UIImage(), for: .normal) }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        
        if let uploadVC = viewContainingController() as? UploadPostController {
            uploadVC.uploadTable.addGestureRecognizer(uploadVC.tapToClose)
        }
        
        /// tag = 2 for spot during editing / when text isn't empty
        if textView.tag == 1 {
            textView.text = nil
            textView.tag = 2
            textView.textColor = UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha: 1.00)
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        
        if let uploadVC = viewContainingController() as? UploadPostController {
            uploadVC.mapVC.removeTable()
            uploadVC.uploadTable.removeGestureRecognizer(uploadVC.tapToClose)
        }
        
        /// tag = 1 for placeholder
        if textView.tag == 2 && textView.text.isEmpty {
            textView.text = "What's up..."
            textView.tag = 1
            textView.textColor = UIColor(red: 0.267, green: 0.267, blue: 0.267, alpha: 1)
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        
        /// add tag table if this is the same word after @ was type     d
        let cursor = textView.getCursorPosition()
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        uploadVC.addRemoveTagTable(text: textView.text ?? "", cursorPosition: cursor, tableParent: .upload)
        
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        
        let currentText = textView.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: text)
        
        ///update parent
        if let uploadVC = self.viewContainingController() as? UploadPostController {
            if updatedText.count <= 500 { uploadVC.postObject.caption = updatedText }
        }
        
        return updatedText.count <= 500
    }
}

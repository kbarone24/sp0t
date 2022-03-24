//
//  EditPostView.swift
//  Spot
//
//  Created by Kenny Barone on 5/20/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Geofirestore
import CoreLocation
import Mixpanel

class EditPostView: UIView, UITextViewDelegate {
    
    var row = 0
    var postingToView: UIView!
    var spotNameLabel: UILabel!
    
    var captionView: UIView!
    var postImage: UIImageView!
    var postCaption: UITextView!
    var timestampLabel: UILabel!
    var editImage: UIImageView!
    var editButton: UIButton!
    
    var locationView: UIView!
    var addressButton: UIButton!
    var editAddress: UIButton!
    
    var whoCanSee: UILabel!
    var privacyView: UIView!
    var friendCount: UILabel!
    var actionArrow: UIButton!
    var privacyButton: UIButton!
    var privacyIcon: UIImageView!
    var privacyLabel: UILabel!
    var privacyMask: UIView!
    
    var post: MapPost!
    weak var postVC: PostViewController!
    var newPrivacy: String!
    
    var editedDate = false
    var datePicker: UIDatePicker!
    var textDatePicker: UITextField!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = UIColor(red: 0.086, green: 0.086, blue: 0.086, alpha: 1)
        layer.cornerRadius = 12
    }
    
    func setUp(post: MapPost, postVC: PostViewController) {
        
        self.post = post
        self.postVC = postVC
        
        if post.spotID != "" {
            
            postingToView = UIView(frame: CGRect(x: 0, y: 0, width: self.bounds.width, height: 64))
            postingToView.backgroundColor = nil
            self.addSubview(postingToView)
            
            let postingToLabel = UILabel(frame: CGRect(x: 14, y: 14, width: 65, height: 15))
            postingToLabel.text = "Posting to"
            postingToLabel.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
            postingToLabel.font = UIFont(name: "SFCompactText-Regular", size: 12.5)
            postingToView.addSubview(postingToLabel)
            
            let targetIcon = UIImageView(frame: CGRect(x: 14, y: 34, width: 17, height: 17))
            targetIcon.image = UIImage(named: "PlainSpotIcon")
            postingToView.addSubview(targetIcon)
            
            spotNameLabel = UILabel(frame: CGRect(x: targetIcon.frame.maxX + 6, y: 34, width: self.bounds.width - 40, height: 17))
            spotNameLabel.text = post.spotName
            spotNameLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
            spotNameLabel.font = UIFont(name: "SFCompactText-Regular", size: 12.5)
            spotNameLabel.lineBreakMode = .byTruncatingTail
            postingToView.addSubview(spotNameLabel)
            
            if post.createdBy == postVC.uid && !(post.spotPrivacy == "public") {
                let editSpotButton = UIButton(frame: CGRect(x: spotNameLabel.frame.maxX + 2, y: 36, width: 55, height: 15))
                editSpotButton.setTitle("EDIT SPOT", for: .normal)
                editSpotButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
                editSpotButton.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 9.5)
                editSpotButton.addTarget(self, action: #selector(editSpotTap(_:)), for: .touchUpInside)
                postingToView.addSubview(editSpotButton)
                
                let bottomLine = UIView(frame: CGRect(x: 0, y: 61, width: UIScreen.main.bounds.width, height: 1))
                bottomLine.backgroundColor = UIColor(red: 0.179, green: 0.179, blue: 0.179, alpha: 1)
                postingToView.addSubview(bottomLine)
            }
        }
        
        let rollingY: CGFloat = post.spotID == "" ? 0 : 64
        
        captionView = UIView(frame: CGRect(x: 0, y: rollingY, width: self.bounds.width, height: 183))
        captionView.backgroundColor = nil
        self.addSubview(captionView)
        
        var minX: CGFloat = 14
        
        if post.postImage.first ?? UIImage() != UIImage() {
            postImage = UIImageView(frame: CGRect(x: minX, y: 36, width: 71, height: 99))
            postImage.image = post.postImage.first ?? UIImage(color: UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0))
            postImage.clipsToBounds = true
            postImage.layer.cornerRadius = 3.33
            postImage.contentMode = .scaleAspectFill
            captionView.addSubview(postImage)
            
            minX += 80
        }
        
        timestampLabel = UILabel(frame: CGRect(x: minX + 3, y: 38, width: 100, height: 15))
        let postTimestamp = post.actualTimestamp == nil ? post.timestamp : post.actualTimestamp
        timestampLabel.text = getDateTimestamp(postTime: postTimestamp!)
        timestampLabel.textColor = UIColor(red: 0.442, green: 0.442, blue: 0.442, alpha: 1)
        timestampLabel.font = UIFont(name: "SFCompactText-Semibold", size: 11.25)
        timestampLabel.sizeToFit()
        captionView.addSubview(timestampLabel)
        
        editImage = UIImageView(frame: CGRect(x: timestampLabel.frame.maxX + 4, y: timestampLabel.frame.minY - 0.5, width: 11, height: 12.2))
        editImage.image = UIImage(named: "EditDateButton")
        editImage.contentMode = .scaleAspectFit
        captionView.addSubview(editImage)
        
        editButton = UIButton(frame: CGRect(x: timestampLabel.frame.minX - 5, y: timestampLabel.frame.minY - 5, width: timestampLabel.frame.width + 30, height: timestampLabel.frame.height + 10))
        editButton.addTarget(self, action: #selector(editDateTap(_:)), for: .touchUpInside)
        captionView.addSubview(editButton)
        
        postCaption = VerticallyCenteredTextView(frame: CGRect(x: minX, y: editImage.frame.maxY + 7, width: bounds.width - minX - 14, height: 80))
        postCaption.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        
        if post.caption == "" {
            postCaption.alpha = 0.5
            postCaption.text = "Write a caption..."
        } else {
            postCaption.text = post.caption
        }
        
        postCaption.font = UIFont(name: "SFCompactText-Regular", size: 13)
        postCaption.backgroundColor = nil
        postCaption.isScrollEnabled = true
        postCaption.textContainer.lineBreakMode = .byTruncatingHead
        postCaption.keyboardDistanceFromTextField = 100
        postCaption.delegate = self
        captionView.addSubview(postCaption)
                
        let bottomLine = UIView(frame: CGRect(x: 0, y: 182, width: self.bounds.width, height: 1))
        bottomLine.backgroundColor = UIColor(red: 0.179, green: 0.179, blue: 0.179, alpha: 1)
        captionView.addSubview(bottomLine)
        
        locationView = UIView(frame: CGRect(x: 0, y: captionView.frame.maxY, width: self.bounds.width, height: 56))
        locationView.backgroundColor = nil
        self.addSubview(locationView)
        
        let postLabel = UILabel(frame: CGRect(x: 14, y: 10, width: 100, height: 17))
        postLabel.text = "Post location"
        postLabel.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        postLabel.font = UIFont(name: "SFCompactText-Regular", size: 12.5)
        locationView.addSubview(postLabel)
        
        addressButton = UIButton(frame: CGRect(x: 14, y: postLabel.frame.maxY - 4, width: self.bounds.width - 50, height: 15))
        addressButton.setTitleColor(UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1), for: .normal)
        addressButton.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 11.5)
        addressButton.titleLabel?.lineBreakMode = .byTruncatingTail
        addressButton.addTarget(self, action: #selector(editAddress(_:)), for: .touchUpInside)
        
        postVC.reverseGeocodeFromCoordinate(numberOfFields: 4, location: CLLocation(latitude: post.postLat, longitude: post.postLong)) { [weak self] (address) in
            guard let self = self else { return }
            
            self.addressButton.setTitle(address, for: .normal)
            self.addressButton.sizeToFit()
            self.locationView.addSubview(self.addressButton)
            
            self.editAddress = UIButton(frame: CGRect(x: self.addressButton.frame.maxX + 2, y: postLabel.frame.maxY - 5, width: 27, height: 27))
            self.editAddress.setImage(UIImage(named: "EditPost"), for: .normal)
            self.editAddress.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            self.editAddress.addTarget(self, action: #selector(self.editAddress(_:)), for: .touchUpInside)
            self.locationView.addSubview(self.editAddress)
        }
        
        let line = UIView(frame: CGRect(x: 0, y: 55, width: self.bounds.width, height: 1))
        line.backgroundColor = UIColor(red: 0.179, green: 0.179, blue: 0.179, alpha: 1)
        locationView.addSubview(line)
        
        privacyView = UIView(frame: CGRect(x: 0, y: locationView.frame.maxY, width: self.bounds.width, height: 106))
        privacyView.backgroundColor = nil
        self.addSubview(privacyView)
        
        whoCanSee = UILabel(frame: CGRect(x: 14, y: 10, width: 100, height: 17))
        whoCanSee.text = "Who can see?"
        whoCanSee.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        whoCanSee.font = UIFont(name: "SFCompactText-Regular", size: 12.5)
        privacyView.addSubview(whoCanSee)
        
        privacyIcon = UIImageView()
        privacyIcon.contentMode = .scaleAspectFit
        
        privacyLabel = UILabel()
        privacyLabel.textColor = .white
        privacyLabel.font = UIFont(name: "SFCompactText-Semibold", size: 13)
        
        friendCount = UILabel()
        friendCount.textColor = UIColor(named: "SpotGreen")
        friendCount.font = UIFont(name: "SFCompactText-Regular", size: 10.5)
        
        actionArrow = UIButton()
        actionArrow.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        actionArrow.setImage(UIImage(named: "ActionArrow"), for: .normal)
        actionArrow.addTarget(self, action: #selector(actionTap(_:)), for: .touchUpInside)
                
        loadPrivacyView()
        privacyView.addSubview(privacyIcon)
        privacyView.addSubview(privacyLabel)
        
        if post.privacyLevel == "invite" { privacyView.addSubview(friendCount) }
        if (post.spotPrivacy == "public" || post.spotID == "") {
            privacyView.addSubview(privacyButton)
            privacyView.addSubview(actionArrow)
        }
        
        let cancelButton = UIButton(frame: CGRect(x: 200, y: 70, width: 65, height: 20))
        cancelButton.titleEdgeInsets = UIEdgeInsets(top: 2.5, left: 2.5, bottom: 2.5, right: 2.5)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor(red: 0.769, green: 0.769, blue: 0.769, alpha: 1), for: .normal)
        cancelButton.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 14)
        cancelButton.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
        privacyView.addSubview(cancelButton)
        
        let saveButton = UIButton(frame: CGRect(x: 275, y: 70, width: 43, height: 20))
        saveButton.titleEdgeInsets = UIEdgeInsets(top: 2.5, left: 2.5, bottom: 2.5, right: 2.5)
        saveButton.setTitle("Save", for: .normal)
        saveButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        saveButton.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 14)
        saveButton.addTarget(self, action: #selector(saveTap(_:)), for: .touchUpInside)
        privacyView.addSubview(saveButton)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func editDateTap(_ sender: UIButton) {

        let postTimestamp = post.actualTimestamp == nil ? post.timestamp : post.actualTimestamp

        datePicker = UIDatePicker()
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.date = postTimestamp!.dateValue()
        datePicker.datePickerMode = .date
        datePicker.maximumDate = post.timestamp.dateValue() /// cant go forward in time
        
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(doneDatePicker(_:)));
        doneButton.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "SFCompactText-Semibold", size: 15) as Any, NSAttributedString.Key.foregroundColor: UIColor(named: "SpotGreen") as Any], for: .normal)
        let spaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelDatePicker(_:)));
        cancelButton.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "SFCompactText-Regular", size: 14) as Any, NSAttributedString.Key.foregroundColor: UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1) as Any], for: .normal)
        toolbar.setItems([cancelButton, spaceButton, doneButton], animated: false)
        
        textDatePicker = UITextField()
        textDatePicker.inputAccessoryView = toolbar
        textDatePicker.inputView = datePicker
        addSubview(textDatePicker)
        
        textDatePicker.becomeFirstResponder()
    }
    
    @objc func cancelDatePicker(_ sender: UIBarButtonItem) {
        textDatePicker.resignFirstResponder()
        textDatePicker.removeFromSuperview()
    }
    
    @objc func doneDatePicker(_ sender: UIBarButtonItem) {
        
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        let dateString = formatter.string(from: datePicker.date)
        
        timestampLabel.text = dateString
        timestampLabel.frame = CGRect(x: postImage.frame.maxX + 12, y: postImage.frame.minY + 2, width: 100, height: 15)
        timestampLabel.sizeToFit()
        editImage.frame = CGRect(x: timestampLabel.frame.maxX + 4, y: timestampLabel.frame.minY - 0.5, width: 11, height: 12.2)
        editButton.frame = CGRect(x: timestampLabel.frame.minX - 5, y: timestampLabel.frame.minY - 5, width: timestampLabel.frame.width + 30, height: timestampLabel.frame.height + 10)
        
        editedDate = true
        postVC.editedPost.actualTimestamp = Timestamp(date: datePicker.date)

        textDatePicker.resignFirstResponder()
        textDatePicker.removeFromSuperview()
    }
    
    func loadPrivacyView() {
        
        let privacyString = post.privacyLevel! == "public" ? "Anyone" : post.privacyLevel! == "friends" ? "Friends-only" : post.privacyLevel!.prefix(1).capitalized + post.privacyLevel!.dropFirst()
        privacyLabel.text = privacyString
        
        if post.privacyLevel == "friends" {
            privacyIcon.frame = CGRect(x: 14, y: whoCanSee.frame.maxY + 10, width: 20, height: 13)
            privacyIcon.image = UIImage(named: "FriendsIcon")
            privacyLabel.frame = CGRect(x: privacyIcon.frame.maxX + 6, y: privacyIcon.frame.minY - 2, width: 100, height: 15)
            
        } else if post.privacyLevel == "public" {
            privacyIcon.frame = CGRect(x: 14, y: whoCanSee.frame.maxY + 10, width: 18, height: 18)
            privacyIcon.image = UIImage(named: "PublicIcon")
            privacyLabel.frame = CGRect(x: privacyIcon.frame.maxX + 6, y: privacyIcon.frame.minY + 1, width: 100, height: 15)
            
        } else {
            privacyIcon.frame = CGRect(x: 14, y: whoCanSee.frame.maxY + 11, width: 17.8, height: 22.25)
            privacyIcon.image = UIImage(named: "PrivateIcon")
            privacyLabel.frame = CGRect(x: privacyIcon.frame.maxX + 8, y: privacyIcon.frame.minY + 5, width: 100, height: 15)
            privacyLabel.text = "Private"
        }
        
        privacyLabel.sizeToFit()
        
        if post.privacyLevel == "invite" {
            privacyLabel.frame = CGRect(x: privacyIcon.frame.maxX + 8, y: whoCanSee.frame.maxY + 6.5, width: 100, height: 15)
            privacyLabel.sizeToFit()
            
            friendCount.frame = CGRect(x: privacyIcon.frame.maxX + 8, y: privacyLabel.frame.maxY + 2, width: 70, height: 14)
            var countText = "\(post.inviteList?.count ?? 1) friend"
            if post.inviteList?.count != 1 { countText += "s"}
            friendCount.text = countText
            friendCount.sizeToFit()
        }
        
        if (post.spotPrivacy == "public" || post.spotID == "") {
            actionArrow.frame = CGRect(x: privacyLabel.frame.maxX, y: privacyLabel.frame.minY, width: 23, height: 17)
            
            privacyButton = UIButton(frame: CGRect(x: privacyIcon.frame.minX, y: privacyIcon.frame.minY, width: actionArrow.frame.maxX - privacyIcon.frame.minY, height: 25))
            privacyButton.addTarget(self, action: #selector(actionTap(_:)), for: .touchUpInside)
        }
        
    }
    
    @objc func editSpotTap(_ sender: UIButton) {
        removeEditPost()
        postVC.editPostView = false
    //    postVC.openSpotPage(edit: true, post: post)
    }
    
    @objc func editAddress(_ sender: UIButton) {
        
  /*      if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "LocationPicker") as? LocationPickerController {
            
            vc.selectedImages = post.postImage
            vc.passedLocation = CLLocation(latitude: post.postLat, longitude: post.postLong)
            if post.spotID != "" {
                vc.secondaryLocation = CLLocation(latitude: post.spotLat ?? post.postLong, longitude: post.spotLong ?? post.postLong)
                vc.spotName = post.spotName ?? ""
            }
            
            vc.passedAddress = addressButton.titleLabel?.text ?? ""
            postVC.mapVC.navigationController?.pushViewController(vc, animated: true)
            postVC.addedLocationPicker = true
            
            removeEditPost()
        } */
    }
    
    @objc func actionTap(_ sender: UIButton) {
        ///show privacy picker on action arrow tap
        if let postMask = self.superview {
            privacyMask = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
            privacyMask.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            privacyMask.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closePrivacyPicker(_:))))
            postMask.addSubview(privacyMask)
            
            let pickerView = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 260, width: UIScreen.main.bounds.width, height: 260))
            pickerView.backgroundColor = UIColor(named: "SpotBlack")
            privacyMask.addSubview(pickerView)
            
            let titleLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 100, y: 10, width: 200, height: 20))
            titleLabel.text = "Who can see this?"
            titleLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
            titleLabel.font = UIFont(name: "SFCompactText-Semibold", size: 15)
            titleLabel.textAlignment = .center
            pickerView.addSubview(titleLabel)
            
            let publicButton = UIButton(frame: CGRect(x: 14, y: 50, width: 171, height: 54))
            publicButton.setImage(UIImage(named: "PublicButton"), for: .normal)
            publicButton.layer.cornerRadius = 7.5
            publicButton.tag = 0
            publicButton.addTarget(self, action: #selector(privacyTap(_:)), for: .touchUpInside)
            if post.privacyLevel == "public" {
                publicButton.layer.borderWidth = 1
                publicButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
            }
            pickerView.addSubview(publicButton)
            
            let friendsButton = UIButton(frame: CGRect(x: 14, y: publicButton.frame.maxY + 10, width: 171, height: 54))
            friendsButton.setImage(UIImage(named: "FriendsButton"), for: .normal)
            friendsButton.layer.cornerRadius = 7.5
            friendsButton.tag = 1
            friendsButton.addTarget(self, action: #selector(privacyTap(_:)), for: .touchUpInside)
            if post.privacyLevel == "friends" {
                friendsButton.layer.borderWidth = 1
                friendsButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
            }
            pickerView.addSubview(friendsButton)
        }
    }
    
    @objc func privacyTap(_ sender: UIButton) {
        
        switch sender.tag {
        case 0:
            post.privacyLevel = "public"
            postVC.editedPost.privacyLevel = "public"
        default:
            post.privacyLevel = "friends"
            postVC.editedPost.privacyLevel = "friends"
        }
        
        for subview in privacyMask.subviews { subview.removeFromSuperview() }
        privacyMask.removeFromSuperview()
        
        loadPrivacyView()
    }
    
    
    @objc func closePrivacyPicker(_ sender: UITapGestureRecognizer) {
        for subview in privacyMask.subviews { subview.removeFromSuperview() }
        privacyMask.removeFromSuperview()
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        removeEditPost()
        postVC.editPostView = false
    }
    
    func removeEditPost() {
            
        postVC.editPostView = false
        postVC.mapVC.removeTable()
        postVC.tableView.reloadData()
        
        if let postMask = self.superview {
            postMask.removeFromSuperview()
        }
        
        for sub in self.subviews {
            sub.removeFromSuperview()
        }
        
        self.removeFromSuperview()
    }
    
    @objc func saveTap(_ sender: UIButton) {
        
        Mixpanel.mainInstance().track(event: "EditPostSave")
        
        let captionText = postCaption.text == "Write a caption..." ? "" : postCaption.text
        
        var taggedUsernames: [String] = []
        var selectedUsers: [UserProfile] = []
        
        ///for tagging users on comment post
        let words = captionText!.components(separatedBy: .whitespacesAndNewlines)
        
        for w in words {
            let username = String(w.dropFirst())
            if w.hasPrefix("@") {
                if let f = UserDataModel.shared.friendsList.first(where: {$0.username == username}) {
                    selectedUsers.append(f)
                }
            }
        }
        
        taggedUsernames = selectedUsers.map({$0.username})
        
        
        postVC.postsList[row].caption = captionText ?? ""
        postVC.postsList[row].taggedUsers = taggedUsernames
        postVC.postsList[row].postLong = postVC.editedPost.postLong
        postVC.postsList[row].postLat = postVC.editedPost.postLat
        postVC.postsList[row].privacyLevel = postVC.editedPost.privacyLevel
        postVC.postsList[row] = postVC.setSecondaryPostValues(post: postVC.postsList[row])
        
        if editedDate { postVC.postsList[row].actualTimestamp = postVC.editedPost.actualTimestamp }
        
        let uploadPost = postVC.postsList[row]
        
        postVC.editedPost = nil
        postVC.editPostView = false
                
        //reset annotation
        postVC.mapVC.postsList = postVC.postsList
        let mapPass = ["selectedPost": row as Any, "firstOpen": false, "parentVC": postVC.parentVC] as [String : Any]
        let infoPass: [String: Any] = ["post": uploadPost as Any]
        
        DispatchQueue.main.async {
            self.removeEditPost()
            NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: mapPass)
            NotificationCenter.default.post(name: Notification.Name("EditPost"), object: nil, userInfo: infoPass)
        }
        
        var values : [String: Any] = ["caption" : captionText ?? "", "postLat": uploadPost.postLat, "postLong": uploadPost.postLong, "privacyLevel": uploadPost.privacyLevel as Any, "taggedUsers": taggedUsernames]
        
        if editedDate {
            values["actualTimestamp"] = uploadPost.actualTimestamp
        }
        
      
        DispatchQueue.global(qos: .utility).async {
            /// set edit values for individual posts
            self.updatePostValues(values: values)
            /// update city on location change
            let db = Firestore.firestore()
            self.postVC.reverseGeocodeFromCoordinate(numberOfFields: 2, location: CLLocation(latitude: uploadPost.postLat, longitude: uploadPost.postLong)) { (city) in

                if city == "" { return }
                db.collection("posts").document(uploadPost.id!).updateData(["city" : city])
            }
        }
    }
    
    func updatePostCoordinate(postID: String, location: CLLocation) {
        
        let db = Firestore.firestore()
        let coordinate = location.coordinate
        
        db.collection("posts").document(postID).updateData(["postLat" : coordinate.latitude, "postLong": coordinate.longitude])
        
        GeoFirestore(collectionRef: Firestore.firestore().collection("posts")).setLocation(location: location, forDocumentWithID: postID) { (error) in
            if (error != nil) {
                print("An error occured: \(String(describing: error))")
            } else {
                print("Saved location successfully!")
            }
        }
    }

    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.alpha == 0.5 {
            textView.text = nil
            textView.alpha = 1.0
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.alpha = 0.5
            textView.text = "Write a caption..."
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        
        let cursor = textView.getCursorPosition()
        postVC.addRemoveTagTable(text: textView.text ?? "", cursorPosition: cursor, tableParent: .post)
    }

    
    func updatePostValues(values: [String: Any]) {
        
        let db = Firestore.firestore()
        db.collection("posts").document(post.id!).updateData(values)
        
        updatePostCoordinate(postID: post.id!, location: CLLocation(latitude: post.postLat, longitude: post.postLong))
    }
    
    func getDateTimestamp(postTime: Firebase.Timestamp) -> String {

        let timeInterval = TimeInterval(integerLiteral: postTime.seconds)
        let date = Date(timeIntervalSince1970: timeInterval)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        let dateString = dateFormatter.string(from: date)
        return dateString
    }
}

class VerticallyCenteredTextView: UITextView {
    override var contentSize: CGSize {
        didSet {
            var topCorrection = (bounds.size.height - contentSize.height * zoomScale) / 2.0
            topCorrection = max(0, topCorrection)
            contentInset = UIEdgeInsets(top: topCorrection, left: 0, bottom: 0, right: 0)
        }
    }
}

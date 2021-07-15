//
//  UploadPostController.swift
//  Spot
//
//  Created by kbarone on 9/17/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Photos
import CoreLocation
import Geofirestore
import Mixpanel
import CoreData

class UploadPostController: UIViewController {
    
    unowned var mapVC: MapViewController!
    var spotObject: MapSpot!
    var poi: POI!
    var postDirectToSpot = false
    
    var selectedImages: [UIImage] = []
    var frameIndexes: [Int] = []
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var postLocation: CLLocationCoordinate2D!
    var postDate: Date!
    var imageFromCamera = false
    var draftID: Int64!
    
    lazy var tableView: UITableView = UITableView()
    var postType: PostType!
    
    ///mutable objects that represent fields in the tableview
    lazy var inviteList: [String] = []
    lazy var selectedTags: [String] = []
    lazy var postCity = ""
    var postPrivacy: String!
    var submitPublic = false
    var spotName: String!
    var caption: String!
    var hideFromFeed = false
    
    var maskView: UIView!
    var imageCloseTap, botCloseTap, privacyCloseTap: UITapGestureRecognizer!
    var maskImage, maskImageNext, maskImagePrevious: UIImageView!
    
    var selectedIndex = 0 /// selectedIndex refers to the index of the images as user sees it
    
    var progressView: UIProgressView!
    var errorBox: UIView!
    var errorText: UILabel!
    lazy var uploadFailed = false
    
    lazy var selectedUsers: [UserProfile] = []
    var tapToClose: UITapGestureRecognizer!
    lazy var imageY: CGFloat = 0
    var navBarHeight: CGFloat = 0
    
    var initialDate: Date!
    var datePicker: UIDatePicker!
    var textDatePicker: UITextField!
        
    enum PostType {
        case postToPOI /// "posting to _spot name" + tags, create spot object on upload
        case postToPublic /// "posting to _spot name" + tags (selected if selected), upload to existing  + update tags
        case postToPrivate /// "posting to _spot name"  + hide tags. upload to existing
        case newSpot /// spot name field editable + create spot object on upload
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("TagSelect"), object: nil)
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        Mixpanel.mainInstance().track(event: "UploadPostOpen")
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        navBarHeight = statusHeight +
                    (self.navigationController?.navigationBar.frame.height ?? 44.0)
        /// was having issues with view slid
        
        tableView = UITableView(frame: CGRect(x: 0, y: navBarHeight, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = UIScreen.main.bounds.height < 600
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isUserInteractionEnabled = true
        tableView.allowsSelection = false
        tableView.register(UploadOverviewCell.self, forCellReuseIdentifier: "SpotOverviewCell")
        tableView.register(SpotTagCell.self, forCellReuseIdentifier: "SpotTagCell")
        tableView.register(SpotPrivacyCell.self, forCellReuseIdentifier: "SpotPrivacyCell")
        tableView.register(ShowOnFeedCell.self, forCellReuseIdentifier: "ShowOnFeedCell")
        view.addSubview(tableView)
        
        if tableView.isScrollEnabled { tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0) }
        
        if spotObject != nil {
            postPrivacy = spotObject.privacyLevel
            selectedTags = spotObject.tags
        } else if poi != nil {
            postPrivacy = "public"
        } else {
            postPrivacy = "friends"
        }
        
        imageY = postType == .newSpot ? 87 : 39
        if spotObject != nil && spotObject.privacyLevel == "invite" { inviteList = spotObject.inviteList ?? [] }
        spotName = spotObject == nil ? poi == nil ? "" : poi.name : spotObject.spotName
        
        /// set initial date for comparison on upload
        
        let interval = Date().timeIntervalSince1970
        let currentDate = Date(timeIntervalSince1970: TimeInterval(interval))
        let date = postDate == nil ? currentDate : postDate
        initialDate = date
        
        caption = ""
        
        addSupplementaryViews()
        
        errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 100, width: UIScreen.main.bounds.width, height: 32))
        errorBox.backgroundColor = UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1)
        errorBox.isHidden = true
        view.addSubview(errorBox)
        
        errorText = UILabel(frame: CGRect(x: 0, y: 6, width: UIScreen.main.bounds.width, height: 18))
        errorText.lineBreakMode = .byWordWrapping
        errorText.numberOfLines = 0
        errorText.textColor = UIColor.white
        errorText.textAlignment = .center
        errorText.text = "Name your spot before posting"
        errorText.font = UIFont(name: "SFCamera-Regular", size: 14)!
        errorBox.addSubview(errorText)
        
        NotificationCenter.default.addObserver(self, selector: #selector(tagSelect(_:)), name: NSNotification.Name("TagSelect"), object: nil)
        
        tapToClose = UITapGestureRecognizer(target: self, action: #selector(closeKeyboard(_:)))
        tapToClose.delegate = self
        //tableView.addGestureRecognizer(tapToClose)
        
        tableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        /// reload data to allow user interaction on view did appear unless image preview is showing
        if maskView.isHidden { DispatchQueue.main.async { self.tableView.reloadData() } }
    }
    
    func addSupplementaryViews() {
        
        // set up titleview
        
        /// set up natural back button if pushed from choose spot
        let backArrow = UIImage(named: "BackArrow")?.withRenderingMode(.alwaysOriginal)
        navigationController?.navigationBar.backIndicatorImage = backArrow
        navigationController?.navigationBar.backIndicatorTransitionMaskImage = backArrow
        navigationItem.backBarButtonItem?.tintColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        
        switch postType {
        
        case .newSpot:
            
            let newSpotLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/4, y: 0, width: UIScreen.main.bounds.width/2, height: 16))
            newSpotLabel.text = "New spot"
            newSpotLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
            newSpotLabel.font = UIFont(name: "SFCamera-Regular", size: 18)
            newSpotLabel.textAlignment = .center
            navigationItem.titleView = newSpotLabel
            
        default:
            let titleView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/4, y: 0, width: UIScreen.main.bounds.width/2, height: 40))

            let postingTo = UILabel(frame: CGRect(x: 0, y: 0, width: titleView.frame.width, height: 16))
            postingTo.text = "Posting to"
            postingTo.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
            postingTo.font = UIFont(name: "SFCamera-Regular", size: 12.5)
            postingTo.textAlignment = .center
            titleView.addSubview(postingTo)
            
            let postToName = UILabel(frame: CGRect(x: 0, y: postingTo.frame.maxY, width: titleView.frame.width, height: 17))
            postToName.text = spotName
            postToName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
            postToName.font = UIFont(name: "SFCamera-Semibold", size: 14)
            postToName.textAlignment = .center
            titleView.addSubview(postToName)
            
            navigationItem.titleView = titleView
        }
        
        let alpha: CGFloat = !spotName.isEmpty ? 1.0 : 0.65
        
        let postImage = UIImage(named: "PostButton")?.alpha(alpha).withRenderingMode(.alwaysOriginal)
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: postImage, style: .plain, target: self, action: #selector(postTap(_:)))
                        
        maskView = UIView(frame: CGRect(x: 0, y: navBarHeight, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        maskView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        maskView.isHidden = true
        view.addSubview(maskView)
        
        // progress view for upload
        progressView = UIProgressView(frame: CGRect(x: 50, y: UIScreen.main.bounds.height - 160, width: UIScreen.main.bounds.width - 100, height: 15))
        progressView.subviews[1].clipsToBounds = true
        progressView.clipsToBounds = true
        progressView.progressTintColor = UIColor(named: "SpotGreen")
        progressView.progress = 0.0
        progressView.transform = progressView.transform.scaledBy(x: 1, y: 2)
        progressView.layer.cornerRadius = 1.5
        progressView.layer.sublayers![1].cornerRadius = 1.5
        /// add to mask on upload
    }
        
    func presentPrivacyPicker() {
        
        maskView.isHidden = false
        privacyCloseTap = UITapGestureRecognizer(target: self, action: #selector(closePrivacyPicker(_:)))
        maskView.addGestureRecognizer(privacyCloseTap)
        
        let pickerView = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 391, width: UIScreen.main.bounds.width, height: 391))
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
        publicButton.addTarget(self, action: #selector(privacyTap(_:)), for: .touchUpInside)
        
        if postPrivacy == "public" {
            publicButton.layer.borderWidth = 1
            publicButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        }
        pickerView.addSubview(publicButton)
                        
        let friendsButton = UIButton(frame: CGRect(x: 14, y: 119, width: 171, height: 54))
        friendsButton.setImage(UIImage(named: "FriendsButton"), for: .normal)
        friendsButton.layer.cornerRadius = 7.5
        friendsButton.tag = 1
        friendsButton.addTarget(self, action: #selector(privacyTap(_:)), for: .touchUpInside)
        
        if postPrivacy == "friends" {
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
            inviteButton.addTarget(self, action: #selector(privacyTap(_:)), for: .touchUpInside)
            if postPrivacy == "invite" {
                inviteButton.layer.borderWidth = 1
                inviteButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
            }
            pickerView.addSubview(inviteButton)
        }
    }
    
    func presentDatePicker() {
        
        let interval = Date().timeIntervalSince1970
        let currentDate = Date(timeIntervalSince1970: TimeInterval(interval))
        let date = postDate == nil ? currentDate : postDate

        datePicker = UIDatePicker()
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.date = date!
        datePicker.datePickerMode = .date
        datePicker.maximumDate = currentDate
        
        let toolbar = UIToolbar();
        toolbar.sizeToFit()
        
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(doneDatePicker(_:)));
        doneButton.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "SFCamera-Semibold", size: 15) as Any, NSAttributedString.Key.foregroundColor: UIColor(named: "SpotGreen") as Any], for: .normal)
        let spaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelDatePicker(_:)));
        cancelButton.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "SFCamera-Regular", size: 14) as Any, NSAttributedString.Key.foregroundColor: UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1) as Any], for: .normal)
        toolbar.setItems([cancelButton, spaceButton, doneButton], animated: false)
        
        textDatePicker = UITextField()
        textDatePicker.inputAccessoryView = toolbar
        textDatePicker.inputView = datePicker
        view.addSubview(textDatePicker)
        
        textDatePicker.becomeFirstResponder()
        tableView.addGestureRecognizer(tapToClose)
    }
    
    @objc func cancelDatePicker(_ sender: UIBarButtonItem) {
        textDatePicker.resignFirstResponder()
        textDatePicker.removeFromSuperview()
        tableView.removeGestureRecognizer(tapToClose)
    }
    
    @objc func doneDatePicker(_ sender: UIBarButtonItem) {
        
        Mixpanel.mainInstance().track(event: "EditDateSave")

        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        let dateString = formatter.string(from: datePicker.date)
        
        textDatePicker.resignFirstResponder()
        textDatePicker.removeFromSuperview()
        tableView.removeGestureRecognizer(tapToClose)
        
        /// update timestamp text and size to fit again with new frame
        if let uploadCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell {
            uploadCell.timestampLabel.text = dateString
            uploadCell.timestampLabel.frame = CGRect(x: uploadCell.spotImage.frame.maxX + 12, y: uploadCell.spotImage.frame.minY + 2, width: 100, height: 15)
            uploadCell.timestampLabel.sizeToFit()
            uploadCell.editImage.frame = CGRect(x: uploadCell.timestampLabel.frame.maxX + 4, y: uploadCell.timestampLabel.frame.minY - 0.5, width: 11, height: 12.2)
            uploadCell.editButton.frame = CGRect(x: uploadCell.timestampLabel.frame.minX - 5, y: uploadCell.timestampLabel.frame.minY - 5, width: uploadCell.timestampLabel.frame.width + 30, height: uploadCell.timestampLabel.frame.height + 10)
        }
        
        postDate = datePicker.date
    }


    @objc func tagSelect(_ sender: NSNotification) {
        
        guard let infoPass = sender.userInfo as? [String: Any] else { return }
        guard let username = infoPass["username"] as? String else { return }
        guard let tag = infoPass["tag"] as? Int else { return }
        if tag != 2 { return } /// tag 2 for upload tag. This notification should only come through if tag = 2 because upload will always be topmost VC
        guard let uploadOverviewCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell else { return }
        
        let cursorPosition = uploadOverviewCell.descriptionField.getCursorPosition()
        let tagText = addTaggedUserTo(text: caption ?? "", username: username, cursorPosition: cursorPosition)
        caption = tagText
        uploadOverviewCell.descriptionField.text = tagText        
    }
    
    @objc func privacyTap(_ sender: UIButton) {
        
        for subview in maskView.subviews { subview.removeFromSuperview() }

        switch sender.tag {
        
        case 0:
            
            inviteList = []

            if postType == .newSpot {
                launchSubmitPublic()
                return
                
            } else {
                postPrivacy = "public"
            }

        case 1:
            postPrivacy = "friends"
            inviteList = []
            
        default:
            launchFriendsPicker()
        }

        maskView.isHidden = true
        maskView.removeGestureRecognizer(privacyCloseTap)
        tableView.reloadData()
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
        submitButton.setTitle("Submit", for: .normal)
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

    
    @objc func submitPublicTap(_ sender: UIButton) {
        
        postPrivacy = "public"
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
        
        tableView.reloadData()
    }

    
    // open invite friends view immediately on privacy level pick
    func launchFriendsPicker() {
        if let inviteVC = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "InviteFriends") as? InviteFriendsController {
            
            self.present(inviteVC, animated: true, completion: nil)
            
            inviteVC.uploadVC = self
            
            /// shouldn't be able to invite b0t to an invite only spot
            var noBotList = mapVC.friendsList
            noBotList.removeAll(where: {$0.id == "T4KMLe3XlQaPBJvtZVArqXQvaNT2"})
            
            inviteVC.friendsList = noBotList
            inviteVC.queryFriends = noBotList
            
            for invite in inviteList {
                if let friend = mapVC.friendsList.first(where: {$0.id == invite}) {
                    inviteVC.selectedFriends.append(friend) }
            }
        }
    }
    
    @objc func submitPublicOkay(_ sender: UIButton) {
        closePrivacyPicker()
    }
    
    @objc func cancelSubmitPublic(_ sender: UIButton) {
        closePrivacyPicker()
    }
    
    @objc func closePrivacyPicker(_ sender: UITapGestureRecognizer) {
        closePrivacyPicker()
    }
    
    func closePrivacyPicker() {
        for subview in maskView.subviews { subview.removeFromSuperview() }
        maskView.isHidden = true
        maskView.removeGestureRecognizer(privacyCloseTap)
    }
    
    func imageExpand() {
        
        /// close keyboard
        if let overviewCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell {
            if overviewCell.spotNameField != nil { overviewCell.spotNameField.resignFirstResponder() }
            if overviewCell.descriptionField != nil { overviewCell.descriptionField.resignFirstResponder() }
        }
        
        /// all subviews will be added to the mask so they appear above it in the view hierarchy
        maskView.isHidden = false
        maskView.alpha = 0.0
        imageCloseTap = UITapGestureRecognizer(target: self, action: #selector(closeImageExpand(_:)))
        maskView.addGestureRecognizer(imageCloseTap)
           
        /// mask image starts as the exact size of the thumbmnail then will expand to full screen
        maskImage = UIImageView(frame: CGRect(x: 14, y: imageY, width: 78, height: 104))
        let selectedFrame = frameIndexes[selectedIndex]
        maskImage.image = selectedImages[selectedFrame]
        maskImage.contentMode = .scaleAspectFill
        maskImage.clipsToBounds = true
        maskImage.isUserInteractionEnabled = true
        maskView.addSubview(maskImage)
                
        if frameIndexes.count > 1 {
            
            /// add swipe between images if there are images to swipe through
            maskImage.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(imageSwipe(_:))))
            
            maskImagePrevious = UIImageView()
            maskImagePrevious.image = UIImage()
            maskImagePrevious.contentMode = .scaleAspectFill
            maskImagePrevious.clipsToBounds = true
            maskImagePrevious.isUserInteractionEnabled = true
            maskView.addSubview(maskImagePrevious)
            
            maskImageNext = UIImageView()
            maskImageNext.image = UIImage()
            maskImageNext.contentMode = .scaleAspectFill
            maskImageNext.clipsToBounds = true
            maskImageNext.isUserInteractionEnabled = true
            maskView.addSubview(maskImageNext)
            
            setImageBounds(first: true)
        }
            /// animate image preview expand
        UIView.animate(withDuration: 0.2) {
            let selectedFrame = self.frameIndexes[self.selectedIndex]
            let aspect = self.selectedImages[selectedFrame].size.height / self.selectedImages[selectedFrame].size.width
            let cameraHeight = UIScreen.main.bounds.width * 1.72267
            let height = UIScreen.main.bounds.width * aspect > cameraHeight ? cameraHeight : UIScreen.main.bounds.width * aspect
            let viewHeight = self.view.bounds.height
            self.maskView.alpha = 1.0 /// animate mask appearing
            self.maskImage.frame = CGRect(x: 0, y: (viewHeight - height - self.navBarHeight)/2 - 10, width: UIScreen.main.bounds.width, height: height)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            let animationImages = self.getGifImages()
            if !animationImages.isEmpty {
                self.maskImage.animationImages = animationImages
                /// 5 frame alive check for old alive draft
                let alive = self.imageFromCamera && self.selectedImages.count > 1
                animationImages.count == 5 ? self.maskImage.animate5FrameAlive(directionUp: true, counter: 0) : self.maskImage.animateGIF(directionUp: true, counter: 0, frames: animationImages.count, alive: alive) }
        }
    }
    
    func getGifImages() -> [UIImage] {
        let selectedFrame = frameIndexes[selectedIndex]
        if frameIndexes.count == 1 {
            return selectedImages.count > 1 ? selectedImages : []
        } else if frameIndexes.count - 1 == selectedIndex {
            return selectedImages[selectedFrame] != selectedImages.last ? selectedImages.suffix(selectedImages.count - 1 - selectedFrame) : []
        } else {
            let frame1 = frameIndexes[selectedIndex + 1]
            return frame1 - selectedFrame > 1 ? Array(selectedImages[selectedFrame...frame1 - 1]) : []
        }
    }
    
    func setImageBounds(first: Bool) {
        
        // first = true on original mask expand (will animate the frame of the mask image)
        /// setImageBounds also called on swipe between images
        
        let selectedFrame = frameIndexes[selectedIndex]
        let aspect = selectedImages[selectedFrame].size.height / selectedImages[selectedFrame].size.width
        let cameraHeight = UIScreen.main.bounds.width * 1.72267
        let height = UIScreen.main.bounds.width * aspect > cameraHeight ? cameraHeight : UIScreen.main.bounds.width * aspect
        let viewHeight = self.view.bounds.height
                
        var pHeight: CGFloat = height
        var pImage = UIImage()
        
        if selectedIndex > 0 {
            let pFrame = frameIndexes[selectedIndex - 1]
            pImage = selectedImages[pFrame]
            let pAspect = pImage.size.height / pImage.size.width
            pHeight = UIScreen.main.bounds.width * pAspect
            if pHeight > cameraHeight { pHeight = cameraHeight }
        }
        
        maskImagePrevious.frame = CGRect(x: -UIScreen.main.bounds.width, y: (viewHeight - pHeight - navBarHeight)/2 - 10, width: UIScreen.main.bounds.width, height: pHeight)
        maskImagePrevious.image = pImage
         
        if !first {
            let selectedFrame = frameIndexes[selectedIndex]
            maskImage.frame = CGRect(x: 0, y:(viewHeight - height - navBarHeight)/2 - 10, width: UIScreen.main.bounds.width, height: height)
            maskImage.image = selectedImages[selectedFrame]
            let animationImages = getGifImages()
            let alive = selectedImages.count > 1 && imageFromCamera
            if !animationImages.isEmpty { maskImage.animationImages = animationImages; animationImages.count == 5 ? self.maskImage.animate5FrameAlive(directionUp: true, counter: 0) : self.maskImage.animateGIF(directionUp: true, counter: 0, frames: animationImages.count, alive: alive) }
        }
        
        var nHeight: CGFloat = height
        var nImage = UIImage()
        
        if selectedIndex < frameIndexes.count - 1 {
            let nFrame = frameIndexes[selectedIndex + 1]
            nImage = selectedImages[nFrame]
            let nAspect = nImage.size.height / nImage.size.width
            nHeight = UIScreen.main.bounds.width * nAspect
            if nHeight > cameraHeight { nHeight = cameraHeight }
        }
        
        maskImageNext.frame = CGRect(x: UIScreen.main.bounds.width, y: (viewHeight - nHeight - navBarHeight)/2 - 10, width: UIScreen.main.bounds.width, height: nHeight)
        maskImageNext.image = nImage
    }
    
    @objc func enableDisablePost(text: String) {
        /// don't actually disable the post button bc want to be able to show the error message if user taps before posting
        let alpha: CGFloat = text != "" ? 1.0 : 0.65
        let postImage = UIImage(named: "PostButton")?.alpha(alpha).withRenderingMode(.alwaysOriginal)
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: postImage, style: .plain, target: self, action: #selector(postTap(_:)))
    }
    
    @objc func closeImageExpand(_ sender: UITapGestureRecognizer) {
                
        UIView.animate(withDuration: 0.2) {
            self.maskImage.frame = CGRect(x: 14, y: self.imageY, width: 78, height: 104)
            self.maskImage.layer.cornerRadius = 5
            self.maskView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            for subview in self.maskView.subviews { subview.removeFromSuperview() }
            self.maskView.isHidden = true
            self.maskView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            self.maskView.removeGestureRecognizer(self.imageCloseTap)
            self.tableView.reloadData()
        }
    }
    
    @objc func imageSwipe(_ gesture: UIPanGestureRecognizer) {
        
        let direction = gesture.velocity(in: view)
        let translation = gesture.translation(in: view)
        
        switch gesture.state {
        
        case .changed:
            maskImage.frame = CGRect(x:translation.x, y: maskImage.frame.minY, width: maskImage.frame.width, height: maskImage.frame.height)
            maskImageNext.frame = CGRect(x: UIScreen.main.bounds.width + translation.x, y: maskImageNext.frame.minY, width: maskImageNext.frame.width, height: maskImageNext.frame.height)
            maskImagePrevious.frame = CGRect(x: -UIScreen.main.bounds.width + translation.x, y: maskImagePrevious.frame.minY, width: maskImagePrevious.frame.width, height: maskImagePrevious.frame.height)
            
        case .ended:
            
            if direction.x < 0 {
                if maskImage.frame.maxX + direction.x < UIScreen.main.bounds.width/2 && selectedIndex < frameIndexes.count - 1 {
                    //animate to next image
                    UIView.animate(withDuration: 0.2) {
                        self.maskImageNext.frame = CGRect(x: 0, y: self.maskImageNext.frame.minY, width: self.maskImageNext.frame.width, height: self.maskImageNext.frame.height)
                        self.maskImage.frame = CGRect(x: -UIScreen.main.bounds.width, y: self.maskImage.frame.minY, width: self.maskImage.frame.width, height: self.maskImage.frame.height)
                        self.maskImagePrevious.frame = CGRect(x: -UIScreen.main.bounds.width, y: self.maskImagePrevious.frame.minY, width: self.maskImagePrevious.frame.width, height: self.maskImagePrevious.frame.height)
                    }
                    
                    /// remove animation images early for smooth swiping
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { [weak self] in
                        guard let self = self else { return }
                        self.maskImage.animationImages?.removeAll()
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        guard let self = self else { return }
                        self.selectedIndex += 1
                        self.setImageBounds(first: false)
                        return
                    }
                } else {
                    //return to original state
                    UIView.animate(withDuration: 0.2) { self.setImageBounds(first: false) }
                }
                
            } else {
                if maskImage.frame.minX + direction.x > UIScreen.main.bounds.width/2 && selectedIndex > 0 {
                    //animate to previous image
                    UIView.animate(withDuration: 0.2) {
                        self.maskImagePrevious.frame = CGRect(x: 0, y: self.maskImagePrevious.frame.minY, width: self.maskImagePrevious.frame.width, height: self.maskImagePrevious.frame.height)
                        self.maskImage.frame = CGRect(x: UIScreen.main.bounds.width, y: self.maskImage.frame.minY, width: self.maskImage.frame.width, height: self.maskImage.frame.height)
                        self.maskImageNext.frame = CGRect(x: UIScreen.main.bounds.width, y: self.maskImageNext.frame.minY, width: self.maskImageNext.frame.width, height: self.maskImageNext.frame.height)
                    }
                    
                    /// remove animation images early for smooth swiping
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { [weak self] in
                        guard let self = self else { return }
                        self.maskImage.animationImages?.removeAll()
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        guard let self = self else { return }
                        self.selectedIndex -= 1
                        self.setImageBounds(first: false)
                        return
                    }
                } else {
                    //return to original state
                    UIView.animate(withDuration: 0.2) { self.setImageBounds(first: false)
                    }
                }
            }
        default:
            return
        }
    }
    
    @objc func closeKeyboard(_ sender: UITapGestureRecognizer) {
        guard let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell else { return }
        if textDatePicker != nil { textDatePicker.resignFirstResponder() }
        if cell.descriptionField != nil { cell.descriptionField.resignFirstResponder() }
        if cell.spotNameField != nil { cell.spotNameField.resignFirstResponder() }
    }
}

extension UploadPostController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {

        // only close view on touch outside of textView
        if touch.view!.isKind(of: UITextView.self) { return false }
        
        return true
    }

}

extension UploadPostController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SpotOverviewCell") as! UploadOverviewCell
            let interval = Date().timeIntervalSince1970
            let currentDate = Date(timeIntervalSince1970: TimeInterval(interval))
            let date = postDate == nil ? currentDate : postDate
            cell.setUp(type: postType, images: selectedImages, date: date!, selectedIndex: selectedIndex, frameIndexes: frameIndexes, spotName: spotName, caption: caption)
            return cell
            
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SpotTagCell") as! SpotTagCell
            let spotTags: [String] = spotObject == nil ? [] : spotObject.tags
            let tagsHeight: CGFloat = UIScreen.main.bounds.height < 600 ? 310 : UIScreen.main.bounds.height > 800 ? 240 : 230
            cell.setUp(selectedTags: selectedTags, spotTags: spotTags, collectionHeight: tagsHeight - 25)
            return cell
            
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SpotPrivacyCell") as! SpotPrivacyCell
            let spotPrivacy = spotObject == nil ? "" : spotObject.privacyLevel
            cell.setUp(type: postType, postPrivacy: postPrivacy, spotPrivacy: spotPrivacy, inviteList: inviteList, uploadPost: true, spotNameEmpty: spotName == "", visitorList: [])
            return cell
            
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ShowOnFeedCell") as! ShowOnFeedCell
            cell.setUp(hide: hideFromFeed)
            return cell
        }
    }
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        let screenSize = UIScreen.main.bounds.height > 800 ? 2 : UIScreen.main.bounds.height < 600 ? 0 : 1
        let smallCellSize: CGFloat = screenSize == 2 ? 76 : 69
        
        switch indexPath.row {
        case 0:
            let screenAdjust: CGFloat = screenSize == 2 ? 0 : -15
            return postType == .newSpot ? 230 + screenAdjust : 190 + screenAdjust
        case 1:
            let tagsHeight: CGFloat = screenSize == 0 ? 315 : screenSize == 1 ? 230 : 240
            return tagsHeight
        default:
            return smallCellSize
        }
    }
}

class UploadOverviewCell: UITableViewCell, UITextFieldDelegate, UITextViewDelegate {
    
    var type: UploadPostController.PostType!
    var images: [UIImage] = []
    var frameIndexes: [Int] = []
    var selectedIndex = 0
    
    var spotImage: UIImageView!
    var timestampLabel: UILabel!
    var editImage: UIImageView!
    var editButton: UIButton!
    var expandIcon: UIImageView!
    var spotNameField: PaddedTextField!
    var descriptionField: UITextView!
    
    var addFriendsLabel: UILabel!
    
    
    func setUp(type: UploadPostController.PostType, images: [UIImage], date: Date, selectedIndex: Int, frameIndexes: [Int], spotName: String, caption: String) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        contentView.isUserInteractionEnabled = false
        
        self.type = type
        self.images = images
        self.frameIndexes = frameIndexes
        self.selectedIndex = selectedIndex
        let selectedFrame = frameIndexes[selectedIndex]
        
        resetCell()
        
        switch type {
        
        case .newSpot:
            
            let minY = UIScreen.main.bounds.height > 800 ? 35 : 25
            
            spotNameField = PaddedTextField(frame: CGRect(x: 12, y: minY, width: 295, height: 37))
            
            spotImage = UIImageView(frame: CGRect(x: 14, y: minY + 52, width: 78, height: 104))
            
            
            if spotName == "" {
                spotNameField.attributedPlaceholder = NSAttributedString(string: "Name your spot",
                                                                         attributes: [NSAttributedString.Key.foregroundColor: UIColor(named: "SpotGreen")!.withAlphaComponent(0.6)])
            } else {
                spotNameField.text = spotName
            }
            
            spotNameField.font = UIFont(name: "SFCamera-Regular", size: 16)
            spotNameField.textColor = UIColor(named: "SpotGreen")
            spotNameField.backgroundColor = .black
            spotNameField.tintColor = .white
            spotNameField.layer.cornerRadius = 9
            spotNameField.layer.borderWidth = 1
            spotNameField.layer.borderColor = UIColor(red: 0.196, green: 0.196, blue: 0.196, alpha: 1).cgColor
            spotNameField.delegate = self
            spotNameField.autocapitalizationType = .sentences
            spotNameField.textAlignment = .left
            self.addSubview(spotNameField)
            
                        
        default:
            
            spotImage = UIImageView(frame: CGRect(x: 14, y: 39, width: 78, height: 104))
        }
        
        spotImage.image = images[selectedFrame]
        spotImage.contentMode = .scaleAspectFill
        spotImage.layer.cornerRadius = 5
        spotImage.isUserInteractionEnabled = true
        spotImage.clipsToBounds = true
        spotImage.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(imageExpand(_:))))
        addSubview(spotImage)
        
        timestampLabel = UILabel(frame: CGRect(x: spotImage.frame.maxX + 12, y: spotImage.frame.minY + 2, width: 100, height: 15))
        let timestamp = Timestamp(date: date)
        timestampLabel.text = getDateTimestamp(postTime: timestamp)
        timestampLabel.textColor = UIColor(red: 0.442, green: 0.442, blue: 0.442, alpha: 1)
        timestampLabel.font = UIFont(name: "SFCamera-Semibold", size: 11.25)
        timestampLabel.sizeToFit()
        addSubview(timestampLabel)
        
        editImage = UIImageView(frame: CGRect(x: timestampLabel.frame.maxX + 4, y: timestampLabel.frame.minY - 0.5, width: 11, height: 12.2))
        editImage.image = UIImage(named: "EditDateButton")
        editImage.contentMode = .scaleAspectFit
        addSubview(editImage)
        
        editButton = UIButton(frame: CGRect(x: timestampLabel.frame.minX - 5, y: timestampLabel.frame.minY - 5, width: timestampLabel.frame.width + 30, height: timestampLabel.frame.height + 10))
        editButton.addTarget(self, action: #selector(editDateTap(_:)), for: .touchUpInside)
        addSubview(editButton)
    
        if frameIndexes.count > 1 {
            expandIcon = UIImageView(frame: CGRect(x: spotImage.frame.maxX - 30, y: spotImage.frame.maxY - 30, width: 22, height: 22))
            expandIcon.image = UIImage(named: "PreviewPic")
            self.addSubview(expandIcon)
        }
        
        descriptionField = VerticallyCenteredTextView(frame: CGRect(x: spotImage.frame.maxX + 8, y: editImage.frame.maxY + 7, width: UIScreen.main.bounds.width - 24 - spotImage.frame.maxX, height: spotImage.frame.height - 25))
        descriptionField.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1.0)
        
        if caption == "" {
            descriptionField.alpha = 0.5
            descriptionField.text = type == .newSpot || type == .postToPOI ? "What's it like?" : "Write a caption..."
        } else {
            descriptionField.text = caption
        }
        
        descriptionField.font = UIFont(name: "SFCamera-Regular", size: 14)
        descriptionField.backgroundColor = nil
        descriptionField.isScrollEnabled = true
        descriptionField.textContainer.lineBreakMode = .byTruncatingHead
        descriptionField.keyboardDistanceFromTextField = 100
        descriptionField.delegate = self
        descriptionField.tintColor = .white
        descriptionField.autocorrectionType = .yes
        self.addSubview(descriptionField)
    }
    
    func resetCell() {
        if spotImage != nil { spotImage.image = UIImage() }
        if timestampLabel != nil { timestampLabel.text = "" }
        if editImage != nil { editImage.image = UIImage() }
        if expandIcon != nil { expandIcon.image = UIImage() }
        if spotNameField != nil { spotNameField.text = "" }
        if descriptionField != nil { descriptionField.text = "" }
    }
        
    @objc func imageExpand(_ sender: UITapGestureRecognizer) {
        if let uploadVC = self.viewContainingController() as? UploadPostController {
            uploadVC.imageExpand()
        }
        self.spotImage.isHidden = true
    }
    
    @objc func editDateTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "EditDateOpen")
        if let uploadVC = self.viewContainingController() as? UploadPostController {
            uploadVC.presentDatePicker()
        }
    }
    
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        
        if let uploadVC = self.viewContainingController() as? UploadPostController {
            if updatedText.count <= 60 { uploadVC.spotName = updatedText }
            ///enable disable post button if spot name is empty/not empty
            let trimText = updatedText.trimmingCharacters(in: .whitespacesAndNewlines)
            uploadVC.enableDisablePost(text: trimText)
        }
        
        return updatedText.count <= 60
        
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if let uploadVC = viewContainingController() as? UploadPostController {
            uploadVC.tableView.addGestureRecognizer(uploadVC.tapToClose)
        }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        
        if let uploadVC = viewContainingController() as? UploadPostController {
            uploadVC.tableView.addGestureRecognizer(uploadVC.tapToClose)
        }
        
        if textView.alpha == 0.5 {
            textView.text = nil
            textView.alpha = 1.0
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if let uploadVC = viewContainingController() as? UploadPostController {
            uploadVC.tableView.removeGestureRecognizer(uploadVC.tapToClose)
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        
        if let uploadVC = viewContainingController() as? UploadPostController {
            uploadVC.mapVC.removeTable()
            uploadVC.tableView.removeGestureRecognizer(uploadVC.tapToClose)
        }

        if textView.text.isEmpty {
            textView.alpha = 0.5
            textView.text = type == .newSpot || type == .postToPOI ? "What's it like?" : "Write a caption..."
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
            if updatedText.count <= 500 { uploadVC.caption = updatedText }
        }
        
        return updatedText.count <= 500
    }
    
    ///add textview delegate functions
}

class SpotTagCell: UITableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    var tags: [Tag] = [Tag(name: "Active"), Tag(name: "Art"), Tag(name: "Boogie"), Tag(name: "Chill"), Tag(name: "Coffee"), Tag(name: "Drink"), Tag(name: "Eat"), Tag(name: "Historic"), Tag(name: "Home"), Tag(name: "Nature"), Tag(name: "Shop"), Tag(name: "Smoke"), Tag(name: "Sunset"), Tag(name: "Swim"), Tag(name: "View"), Tag(name: "Weird")]
    var selectedTags: [String] = []
    var spotTags: [String] = []
    var tagsCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: LeftAlignedCollectionViewFlowLayout.init())
    var tagLabel: UILabel!

    func setUp(selectedTags: [String], spotTags: [String], collectionHeight: CGFloat) {
        ///update selected tags on colleciton tap
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        contentView.isUserInteractionEnabled = false
        
        self.selectedTags = selectedTags
        self.spotTags = spotTags
        setSelectedTags()
                
        let tagLayout = LeftAlignedCollectionViewFlowLayout()
        tagLayout.headerReferenceSize = CGSize(width: UIScreen.main.bounds.width, height: 30)
        
        tagsCollection.register(UploadTagCell.self, forCellWithReuseIdentifier: "UploadTagCell")
        tagsCollection.register(UploadTagsHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "UploadTagsHeader")
        tagsCollection.delegate = self
        tagsCollection.dataSource = self
        tagsCollection.backgroundColor = nil
        tagsCollection.isUserInteractionEnabled = true
        tagsCollection.isScrollEnabled = false
        tagsCollection.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: collectionHeight)
        tagsCollection.contentInset = UIEdgeInsets(top: 0, left: 11, bottom: 0, right: 11)
        tagsCollection.setCollectionViewLayout(tagLayout, animated: false)
        addSubview(tagsCollection)
    }
    
    func setSelectedTags() {
        for selected in selectedTags {
            if let index = tags.firstIndex(where: {$0.name == selected}) {
                self.tags[index].selected = true
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {

        let tag = tags[indexPath.row]
        let width = getWidth(name: tag.name)
        return CGSize(width: width, height: 34)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 16
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "UploadTagCell", for: indexPath) as? UploadTagCell else { return UICollectionViewCell() }
        let tag = tags[indexPath.row]
        cell.isSelected = tag.selected
        cell.setUp(tag: tag)
        cell.tag = indexPath.row

        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "UploadTagsHeader", for: indexPath) as? UploadTagsHeader else { return UICollectionReusableView() }
        return header
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        ///update parent with selected tags

        let tag = tags[indexPath.row]
        if spotTags.contains(tag.name) { showBotPopUp(tag: tag.name); return }
        ///remove / add tags
        tag.selected ? selectedTags.removeAll(where: {$0 == tag.name}) : selectedTags.append(tag.name)
        tags[indexPath.row].selected = !tag.selected

        DispatchQueue.main.async { self.tagsCollection.reloadData() }
        
        if let uploadVC = self.viewContainingController() as? UploadPostController {
            uploadVC.selectedTags = self.selectedTags
        } else if let editVC = self.viewContainingController() as? EditSpotController {
            editVC.spotObject.tags = self.selectedTags
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {

        if self.tags[indexPath.row].selected {
            return true
        } else if selectedTags.count < 3 {
            return true
        }
        showTagMessage()
        return false
    }
    
    func showTagMessage() {
        
        if tagLabel != nil && tagLabel.superview != nil { return }
        tagLabel = UILabel(frame: CGRect(x: 75, y: tagsCollection.frame.minY + 3, width: 150, height: 16))
        tagLabel.text = "3 tag max"
        tagLabel.textColor = .white
        tagLabel.font = UIFont(name: "SFCamera-Regular", size: 13)
        addSubview(tagLabel)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            self.tagLabel.removeFromSuperview()
        }
    }
    
    func getWidth(name: String) -> CGFloat {

        var width: CGFloat = 45
        
        let tagName = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 16))
        tagName.text = name
        tagName.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        tagName.sizeToFit()
        width += tagName.frame.width
        return width
    }
    
    func showBotPopUp(tag: String) {
        
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        
        uploadVC.maskView.isHidden = false
        
        let infoView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 116, y: UIScreen.main.bounds.height/2 - 140, width: 232, height: 172))
        infoView.backgroundColor = UIColor(named: "SpotBlack")
        infoView.layer.cornerRadius = 7.5
        infoView.clipsToBounds = true
        infoView.tag = 2
        uploadVC.maskView.addSubview(infoView)
        
        let botPic = UIImageView(frame: CGRect(x: 21, y: 22, width: 30, height: 34.44))
        botPic.image = UIImage(named: "OnboardB0t")
        infoView.addSubview(botPic)
        
        let botName = UILabel(frame: CGRect(x: botPic.frame.maxX + 8, y: 37, width: 80, height: 20))
        botName.text = "sp0tb0t"
        botName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        botName.font = UIFont(name: "SFcamera-Semibold", size: 12.5)
        infoView.addSubview(botName)
        
        let botComment = UILabel(frame: CGRect(x: 22, y: botPic.frame.maxY + 16, width: 196, height: 15))
        botComment.text = "Someone has already added \(tag) to this spot."
        botComment.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        botComment.font = UIFont(name: "SFCamera-Regular", size: 14)
        botComment.numberOfLines = 0
        botComment.lineBreakMode = .byWordWrapping
        botComment.sizeToFit()
        botComment.tag = 3
        infoView.addSubview(botComment)
        
        let okButton = UIButton(frame: CGRect(x: 12, y: botComment.frame.maxY + 15, width: infoView.bounds.width - 24, height: 35))
        okButton.setTitle("Ok", for: .normal)
        okButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        okButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 12.5)
        okButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        okButton.layer.borderWidth = 1
        okButton.layer.cornerRadius = 10
        okButton.addTarget(self, action: #selector(closeBotPopup(_:)), for: .touchUpInside)
        infoView.addSubview(okButton)
    }
    
    @objc func botCloseTap(_ sender: UITapGestureRecognizer) {
        closeBotPopup()
    }
    
    @objc func closeBotPopup(_ sender: UIButton) {
        closeBotPopup()
    }
    
    func closeBotPopup() {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }

        for subview in uploadVC.maskView.subviews {
            subview.removeFromSuperview()
        }
        
        uploadVC.maskView.isHidden = true
        if uploadVC.botCloseTap != nil { uploadVC.maskView.removeGestureRecognizer(uploadVC.botCloseTap)}
    }
}

class UploadTagCell: UICollectionViewCell {
    
    var tagPic: UIImageView!
    var tagName: UILabel!
    
    func setUp(tag: Tag) {
        
        contentView.isUserInteractionEnabled = false
        
        backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)
        layer.cornerRadius = 7.5
        layer.borderWidth = 1
        layer.borderColor = isSelected ? UIColor(named: "SpotGreen")?.cgColor : UIColor(red: 0.17, green: 0.17, blue: 0.17, alpha: 1.00).cgColor
        
        resetCell()
        
        tagPic = UIImageView(frame: CGRect(x: 7, y: 6, width: 22, height: 22))
        tagPic.layer.masksToBounds = true
        tagPic.contentMode = .scaleAspectFit
        tagPic.image = tag.image
        addSubview(tagPic)

        tagName = UILabel(frame: CGRect(x: tagPic.frame.maxX + 5, y: 9, width: self.bounds.width, height: 16))
        tagName.text = tag.name
        tagName.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        tagName.textColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
        tagName.sizeToFit()
        addSubview(tagName)
    }
    
    func resetCell() {
        if tagPic != nil {tagPic.image = UIImage()}
        if tagName != nil {tagName.text = ""}
    }
    
    override func prepareForReuse() {
        isSelected = false
    }
}

class UploadTagsHeader: UICollectionReusableView {
    
    var label: UILabel!
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        
        if label != nil { label.text = "" }
        label = UILabel(frame: CGRect(x: 3, y: 3, width: 100, height: 16))
        label.text = "Add Tags"
        label.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        label.font = UIFont(name: "SFCamera-Regular", size: 12)
        addSubview(label)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SpotPrivacyCell: UITableViewCell {
    
    var descriptionLabel: UILabel!
    var icon: UIImageView!
    var privacyLabel: UILabel!
    var privacyButton: UIButton!
    var friendCount: UILabel!
    var actionArrow: UIButton!
    var inviteButton: UIButton!
        
    func setUp(type: UploadPostController.PostType, postPrivacy: String, spotPrivacy: String, inviteList: [String], uploadPost: Bool, spotNameEmpty: Bool, visitorList: [String]) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        
        resetCell()
        
        descriptionLabel = UILabel(frame: CGRect(x: 14, y: 0, width: 200, height: 20))
        descriptionLabel.textAlignment = .left
        descriptionLabel.text = "Who can see your post"
        descriptionLabel.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        descriptionLabel.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        self.addSubview(descriptionLabel)
        
        icon = UIImageView()
        icon.contentMode = .scaleAspectFit
        
        privacyLabel = UILabel()
        var privacyString = postPrivacy == "public" ? "anyone" : postPrivacy == "friends" ? "friends-only" :  postPrivacy
        privacyString = privacyString.prefix(1).capitalized + privacyString.dropFirst()
        privacyLabel.text = privacyString
        privacyLabel.textColor = .white
        privacyLabel.font = UIFont(name: "SFCamera-Semibold", size: 13)
        
        if postPrivacy == "friends" {
            icon.frame = CGRect(x: 14, y: descriptionLabel.frame.maxY + 6, width: 20, height: 13)
            icon.image = UIImage(named: "FriendsIcon")?.withRenderingMode(.alwaysTemplate)
            icon.tintColor = .white
            privacyLabel.frame = CGRect(x: icon.frame.maxX + 6, y: icon.frame.minY - 1.5, width: 100, height: 15)
            
        } else if postPrivacy == "public" {
            icon.frame = CGRect(x: 14, y: descriptionLabel.frame.maxY + 6, width: 18, height: 18)
            icon.image = UIImage(named: "PublicIcon")?.withRenderingMode(.alwaysTemplate)
            icon.tintColor = .white
            privacyLabel.frame = CGRect(x: icon.frame.maxX + 6, y: icon.frame.minY + 1, width: 100, height: 15)
            
        } else {
            icon.frame = CGRect(x: 14, y: descriptionLabel.frame.maxY + 7, width: 17.8, height: 22.25)
            icon.image = UIImage(named: "PrivateIcon")?.withRenderingMode(.alwaysTemplate)
            icon.tintColor = .white
            privacyLabel.frame = CGRect(x: icon.frame.maxX + 8, y: icon.frame.minY + 5, width: 100, height: 15)
            privacyLabel.text = "Private"
        }
        
        /// for edit spot, add a gray tint to indicate no editing for spot that a friend has visited

        self.addSubview(icon)
        
        privacyLabel.sizeToFit()
        self.addSubview(privacyLabel)
        
        if postPrivacy == "invite" && inviteList.count > 0 {
            privacyLabel.frame = CGRect(x: icon.frame.maxX + 8, y: descriptionLabel.frame.maxY + 2.5, width: 100, height: 15)
            privacyLabel.sizeToFit()
            
            friendCount = UILabel(frame: CGRect(x: icon.frame.maxX + 8, y: privacyLabel.frame.maxY + 1, width: 70, height: 14))
            friendCount.text = "\(inviteList.count) friend"
            if inviteList.count != 1 { friendCount.text! += "s"}
            friendCount.textColor = UIColor(named: "SpotGreen")
            friendCount.font = UIFont(name: "SFCamera-Regular", size: 10.5)
            friendCount.sizeToFit()
            self.addSubview(friendCount)
        }
        
        privacyButton = UIButton(frame: CGRect(x: 12, y: descriptionLabel.frame.maxY + 2, width: privacyLabel.frame.maxX - 20, height: 30))
        privacyButton.backgroundColor = nil
        self.addSubview(privacyButton)
                
        /// cant edit privacy level of a post to a spot if its not public, cant edit privacy level if someone has posted to the spot already
        if (type != .postToPrivate) {
            actionArrow = UIButton(frame: CGRect(x: privacyLabel.frame.maxX, y: privacyLabel.frame.minY, width: 23, height: 17))
            actionArrow.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            actionArrow.setImage(UIImage(named: "ActionArrow"), for: .normal)
            actionArrow.addTarget(self, action: #selector(actionTap(_:)), for: .touchUpInside)
            privacyButton.addTarget(self, action: #selector(actionTap(_:)), for: .touchUpInside)
            self.addSubview(actionArrow)
        }
    }
    
    func resetCell() {
        if descriptionLabel != nil { descriptionLabel.text = "" }
        if icon != nil { icon.image = UIImage() }
        if privacyLabel != nil { privacyLabel.text = "" }
        if friendCount != nil { friendCount.text = "" }
        if actionArrow != nil { actionArrow.setImage(UIImage(), for: .normal) }
    }
        
    @objc func launchEditInvite(_ sender: UIButton) {
        if let editVC = self.viewContainingController() as? EditSpotController {
            editVC.launchFriendsPicker()
        }
    }
    
    @objc func actionTap(_ sender: UIButton) {
        if let uploadVC = self.viewContainingController() as? UploadPostController {
            uploadVC.presentPrivacyPicker()
        } else if let editVC = self.viewContainingController() as? EditSpotController {
            editVC.privacyTap()
        }
    }
    }

class TagCell: UICollectionViewCell {
    
    var tagImage: UIImageView!
    var tagText: UILabel!
    
    func setUp(image: UIImage, text: String) {
        
        resetCell()
        
        backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)
        layer.cornerRadius = 7.5
        layer.borderWidth = 1
        layer.borderColor = UIColor(red: 0.14, green: 0.14, blue: 0.14, alpha: 1.00).cgColor

        tagImage = UIImageView(frame: CGRect(x: (self.bounds.width - 23) / 2, y: 13, width: 23, height: 23))
        tagImage.image = image
        tagImage.contentMode = .center
        self.addSubview(tagImage)
        
        tagText = UILabel(frame: CGRect(x: 0, y: 38, width: self.bounds.width, height: 18))
        tagText.text = text
        tagText.font = UIFont(name: "SFCamera-Regular", size: 13)
        tagText.textColor = UIColor(red:0.88, green:0.88, blue:0.88, alpha:1.0)
        tagText.textAlignment = .center
        let tagAtt = NSAttributedString(string: (tagText.text)!, attributes: [NSAttributedString.Key.kern: 0.25])
        tagText.attributedText = tagAtt
        self.addSubview(tagText)
    }
    
    func resetCell() {
        if tagImage != nil { tagImage.image = UIImage() }
        if tagText != nil { tagText.text = "" }
        self.backgroundColor = UIColor(named: "SpotBlack")
    }
    
    override var isSelected: Bool {
        didSet {
            if isSelected {
                self.backgroundView = UIImageView(image: UIImage(named: "TagBackgroundSelected"))
            } else {
                self.backgroundView = UIImageView(image: UIImage(named: "TagBackgroundUnselected"))
            }
        }
    }
}

// upload methods extension
extension UploadPostController {
    
    @objc func postTap(_ sender: UIBarButtonItem) {
        
        sender.isEnabled = false
        enableDisablePost(text: "") /// gray out post button
        ///check for empty spot name
        if postType == .newSpot {
            let nameTest = self.spotName.trimmingCharacters(in: .whitespacesAndNewlines)
            if nameTest == "" { showError(); return }
        }
                
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        
        if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell {
            //dismiss keyboard
            if cell.spotNameField != nil { cell.spotNameField.resignFirstResponder() }
            if cell.descriptionField != nil { cell.descriptionField.resignFirstResponder() }
        }
      
        DispatchQueue.main.async {
            self.mapVC.removeTable() /// remove tag table
            
            /// add mask for upload
            self.maskView.isHidden = false
            self.view.addSubview(self.maskView)
            
            self.maskView.addSubview(self.progressView)
            self.progressView.setProgress(0.1, animated: true)
        }
            
        /// upload spot image with completion handler
        let postID = UUID().uuidString
        reverseGeocodeFromCoordinate(numberOfFields: 2, location: CLLocation(latitude: postLocation.latitude, longitude: postLocation.longitude)) { (city) in
            self.postCity = city
        }
        
        /// patch fix for uploads going through after failed upload shows
        if uploadFailed { return }
        
        self.uploadPostImage(selectedImages, postID: postID) { [weak self] (imageURLs) in
            
            guard let self = self else { return }
            
            ///return empty array if error or time expired, show error message
            if imageURLs.isEmpty {
                self.runFailedUpload()
                self.uploadFailed = true
                return
            }
            
            if self.uploadFailed { return }

            /// cut for ipad crash
        //    if self.imageFromCamera { self.saveToPhotos(images: self.selectedImages) }
            
            DispatchQueue.main.async { self.progressView.setProgress(1.0, animated: true) }
            
            let postToSpot = self.postType == .postToPublic || self.postType == .postToPrivate
            
            let spotID = postToSpot ? self.spotObject.id! : UUID().uuidString
            let spotCoordinate = postToSpot ? CLLocationCoordinate2D(latitude: self.spotObject.spotLat, longitude: self.spotObject.spotLong) : self.postType == .postToPOI ? CLLocationCoordinate2D(latitude: self.poi.coordinate.latitude, longitude: self.poi.coordinate.longitude) : self.postLocation
            let createdBy = postToSpot ? self.spotObject.founderID : self.uid
            let spotPrivacy = postToSpot ? self.spotObject.privacyLevel : self.postType == .postToPOI ? "public" : self.submitPublic ? "friends" : self.postPrivacy
            /// new post privacy value to account for keeping friend level privacy if submit public
            let adjustedPostPrivacy = self.submitPublic ? "friends" : self.postPrivacy ?? "friends"
            
            let phone = self.postType == .postToPOI ? self.poi.phone : ""
            
            var taggedUsernames: [String] = []
            var selectedUsers: [UserProfile] = []
            
            ///for tagging users on comment post
            let words = self.caption.components(separatedBy: .whitespacesAndNewlines)
            
            for w in words {
                let username = String(w.dropFirst())
                if w.hasPrefix("@") {
                    if let f = self.mapVC.friendsList.first(where: {$0.username == username}) {
                        selectedUsers.append(f)
                    }
                }
            }
            
            taggedUsernames = selectedUsers.map({$0.username})
            self.selectedUsers = selectedUsers
            
            /// set timestamp to original post date or current date
            let interval = Date().timeIntervalSince1970
            let timestamp = Date(timeIntervalSince1970: TimeInterval(interval))
            var actualTimestamp = timestamp

            if self.postDate != nil {
                /// use initial date to preserve exact time if user set the date to the same day as the initial date. Otherwise use post date
                let formatter = DateFormatter()
                formatter.dateFormat = "M/d/yy"
                let string1 = formatter.string(from: self.postDate)
                let string2 = formatter.string(from: self.initialDate)
                actualTimestamp = string1 == string2 ? self.initialDate : self.postDate
            }
            
            var finalInvites = self.inviteList
            if self.postPrivacy == "invite" && !finalInvites.contains(self.uid) { finalInvites.append(self.uid) }
            
            var postFriends = self.hideFromFeed ? [] : self.postPrivacy == "invite" ? finalInvites.filter(self.mapVC.friendIDs.contains) : self.mapVC.friendIDs
            if !postFriends.contains(self.uid) && !self.hideFromFeed { postFriends.append(self.uid) }
            let gif = self.imageFromCamera && self.selectedImages.count > 1 /// for legacy builds gif still corresponds to image animation
            
            var aspectRatios: [CGFloat] = []
            for index in self.frameIndexes {
                let image = self.selectedImages[index]
                aspectRatios.append(image.size.height/image.size.width)
            }
            
            let postValues = ["caption" : self.caption ?? "",
                              "posterID": self.uid,
                              "likers": [],
                              "timestamp": timestamp,
                              "actualTimestamp": actualTimestamp,
                              "taggedUsers": taggedUsernames,
                              "postLat": self.postLocation.latitude,
                              "postLong": self.postLocation.longitude,
                              "privacyLevel": adjustedPostPrivacy,
                              "imageURLs" : imageURLs,
                              "frameIndexes" : self.frameIndexes,
                              "aspectRatios": aspectRatios,
                              "gif": gif,
                              "spotName" : self.spotName ?? "",
                              "createdBy": createdBy,
                              "city" : self.postCity,
                              "inviteList" : finalInvites,
                              "friendsList" : postFriends,
                              "spotID": spotID,
                              "spotLat": spotCoordinate?.latitude ?? 0.0,
                              "spotLong": spotCoordinate?.longitude ?? 0.0,
                              "isFirst": self.postType != .postToPublic && self.postType != .postToPrivate,
                              "spotPrivacy" : spotPrivacy,
                              "hideFromFeed": self.hideFromFeed] as [String : Any]
            
            let commentValues = ["commenterID" : self.uid,
                                 "comment" : self.caption ?? "",
                                 "timestamp" : timestamp,
                                 "taggedUsers": taggedUsernames] as [String : Any]
            
            let commentID = UUID().uuidString
            
            let commentObject = MapComment(id: commentID, comment: self.caption ?? "", commenterID: self.uid, timestamp: Timestamp(date: timestamp as Date), userInfo: self.mapVC.userInfo, taggedUsers: taggedUsernames, commentHeight: self.getCommentHeight(comment: self.caption ?? ""), seconds: Int64(interval))
            
            var postObject = MapPost(id: postID, caption: self.caption ?? "", postLat: self.postLocation.latitude, postLong: self.postLocation.longitude, posterID: self.uid, timestamp: Timestamp(date: timestamp as Date), userInfo: self.mapVC.userInfo, spotID: spotID, city: self.postCity, frameIndexes: self.frameIndexes, aspectRatios: aspectRatios, imageURLs: imageURLs, postImage: self.selectedImages, seconds: Int64(interval), selectedImageIndex: 0, commentList: [commentObject], likers: [], taggedUsers: taggedUsernames, spotName: self.spotName, spotLat: spotCoordinate?.latitude ?? 0.0, spotLong: spotCoordinate?.longitude ?? 0.0, privacyLevel: adjustedPostPrivacy, createdBy: self.uid, inviteList: self.inviteList)
            postObject.friendsList = postFriends
            postObject.actualTimestamp = Timestamp(date: actualTimestamp)
            
            /// notify feed + any other open view controllers (profile posts, nearby) of new post
            NotificationCenter.default.post(Notification(name: Notification.Name("NewPost"), object: nil, userInfo: ["post" : postObject]))
            
            let db = Firestore.firestore()
            
            self.checkForFirstPost()
            
            db.collection("posts").document(postID).setData(postValues)
            db.collection("posts").document(postID).collection("comments").document(commentID).setData(commentValues, merge:true)
            self.setPostLocations(postLocation: self.postLocation, postID: postID)
            
            if !selectedUsers.isEmpty { self.sendTagNotis(post: postObject, spotID: spotID, selectedUsers: selectedUsers, postType: self.postType) }
            ///switch post type
            switch self.postType {
            
            case .postToPublic, .postToPrivate:
                                                                        
                    self.sendPostNotis(post: postObject, spotObject: self.spotObject, selectedUsers: selectedUsers)
                    
                    /// add to users spotslist if not already there
                    if self.spotObject.visitorList.contains(where: {$0 == self.uid}) {
                        db.collection("users").document(self.uid).collection("spotsList").document(spotID).updateData(["postsList" : FieldValue.arrayUnion([postID])])
                    } else {
                        db.collection("users").document(self.uid).collection("spotsList").document(spotID).setData(["spotID" : spotID, "checkInTime" : timestamp, "postsList" : [postID], "city": self.postCity], merge:true)
                    }
                    
                self.incrementSpotScore(user: self.uid, increment: 3)
                self.incrementSpotScore(user: self.spotObject.founderID, increment: 1)
                
                self.runSpotTransactions(spotID: spotID, postPrivacy: adjustedPostPrivacy, postID: postID, timestamp: timestamp)
                
                
            default:
                
                ///3. create new spot from POI or from scratch
                let spotPrivacy = self.submitPublic ? "friends" : self.postType == .newSpot ? self.postPrivacy ?? "friends" : "public"
                let lowercaseName = self.spotName.lowercased()
                let keywords = lowercaseName.getKeywordArray()
                
                let spotValues =  ["city" : self.postCity,
                                   "spotName" : self.spotName ?? "",
                                   "lowercaseName": lowercaseName,
                                   "description": self.caption ?? "",
                                   "tags": self.selectedTags,
                                   "createdBy": self.uid,
                                   "visitorList": [self.uid],
                                   "inviteList" : finalInvites,
                                   "privacyLevel": spotPrivacy,
                                   "taggedUsers": taggedUsernames,
                                   "spotLat": spotCoordinate!.latitude,
                                   "spotLong" : spotCoordinate!.longitude,
                                   "imageURL" : imageURLs.first ?? "",
                                   "phone" : phone,
                                   "postIDs": [postID],
                                   "postTimestamps": [timestamp],
                                   "posterIDs": [self.uid],
                                   "postPrivacies": [adjustedPostPrivacy],
                                   "searchKeywords": keywords] as [String : Any]
                
                    db.collection("spots").document(spotID).setData(spotValues, merge: true)
                    db.collection("users").document(self.uid).collection("spotsList").document(spotID).setData(["spotID" : spotID, "checkInTime" : timestamp, "postsList" : [postID], "city": self.postCity])
                    
                    /// set spot for public submission
                    if self.submitPublic { db.collection("submissions").document(spotID).setData(["spotID" : spotID]) }
                    
                    self.setSpotLocations(spotLocation: spotCoordinate!, spotID: spotID)
                    
                    var spotObject = MapSpot(id: spotID, spotDescription: self.caption ?? "", spotName: self.spotName ?? "", spotLat: self.postLocation.latitude, spotLong: self.postLocation.longitude, founderID: self.uid, privacyLevel: spotPrivacy, visitorList: [self.uid], inviteList: self.inviteList, tags: self.selectedTags, imageURL: imageURLs.first ?? "", spotImage: self.selectedImages.first ?? UIImage(), taggedUsers: taggedUsernames, city: self.postCity, friendVisitors: 0, distance: 0)
                    spotObject.checkInTime = Int64(interval)
                    
                    NotificationCenter.default.post(name: NSNotification.Name("NewSpot"), object: nil, userInfo: ["spot" : spotObject])
                    
                    /// send notifications if this is an invite only spot
                    self.sendInviteNotis(spotObject: spotObject, postObject: postObject, username: self.mapVC.userInfo.username)
                    
                    /// add city to list of cities if this is the first post there
                    self.addToCityList(city: self.postCity)
                    
                    /// increment users spotScore
                    self.incrementSpotScore(user: self.uid, increment: 6)
                    
                    Mixpanel.mainInstance().track(event: "UploadPostSuccessful")
                    
                    self.deleteDraft()
                    self.transitionToMap(postID: postID, spotID: spotID)
            }
        }
    }
    
    
    func sendTagNotis(post: MapPost, spotID: String, selectedUsers: [UserProfile], postType: UploadPostController.PostType) {
        
        let db = Firestore.firestore()
        let interval = Date().timeIntervalSince1970
        let timestamp = Date(timeIntervalSince1970: TimeInterval(interval))
        
        
        for user in selectedUsers {
            let type = postType == .newSpot ? "spotTag" : "postTag"
            let values = ["seen" : false, "timestamp" : timestamp, "senderID": uid, "type": type, "spotID": spotID, "postID": post.id!, "imageURL": post.imageURLs.first!, "spotName": post.spotName ?? ""] as [String : Any]
            let nID = UUID().uuidString
            let notiRef = db.collection("users").document(user.id!).collection("notifications").document(nID)
            notiRef.setData(values)
            let sender = PushNotificationSender()
            
            db.collection("users").document(user.id!).getDocument { [weak self] (tokenSnap, err) in
                guard let self = self else { return }
                guard let token = tokenSnap?.get("notificationToken") as? String else { return }
                let ntext = postType == .newSpot ? "tagged you at a spot" : "tagged you in a post"
                sender.sendPushNotification(token: token, title: "", body: "\(self.mapVC.userInfo.username) \(ntext)")
            }
        }
    }
    
    func sendPostNotis(post: MapPost, spotObject: MapSpot, selectedUsers: [UserProfile]) {
        
        let db = Firestore.firestore()
        let interval = Date().timeIntervalSince1970
        let timestamp = Date(timeIntervalSince1970: TimeInterval(interval))
        
        
        for user in spotObject.visitorList {
            
            if selectedUsers.contains(where: {$0.id == user}) { continue }
            if user == uid { continue }
            
            let notiID = UUID().uuidString
            let notiRef = db.collection("users").document(user).collection("notifications").document(notiID)
            
            let notiValues = ["seen" : false, "timestamp" : timestamp, "senderID": self.uid, "type": "post", "spotID": spotObject.id!, "postID": post.id!, "imageURL": post.imageURLs.first!, "spotName": spotObject.spotName] as [String : Any]
            notiRef.setData(notiValues)
            
            let sender = PushNotificationSender()
            var token: String!
            
            db.collection("users").document(user).getDocument { [weak self] (tokenSnap, err) in
                
                guard let self = self else { return }
                if (tokenSnap == nil) { return }
                  
                token = tokenSnap?.get("notificationToken") as? String
                
                if (token != nil && token != "") {
                    sender.sendPushNotification(token: token, title: "", body: "\(self.mapVC.userInfo.username) posted at \(spotObject.spotName)")
                }
            }
        }
    }
    
    func checkForFirstPost() {
        
        /// send notis to friends on first upload
        if postPrivacy != "invite" && !hideFromFeed && mapVC.userSpotsLoaded && mapVC.userSpots.count == 0 {

            let db = Firestore.firestore()

            for friend in mapVC.friendsList {
                let sender = PushNotificationSender()
                var token: String!
                
                db.collection("users").document(friend.id!).getDocument { [weak self] (tokenSnap, err) in
                    
                    guard let self = self else { return }
                    if (tokenSnap == nil) { return }
                      
                    token = tokenSnap?.get("notificationToken") as? String
                    
                    if (token != nil && token != "") {
                        sender.sendPushNotification(token: token, title: "", body: "\(self.mapVC.userInfo.username) posted their first spot!")
                    }
                }
            }
        }
    }
    
    func deleteDraft() {
        
        if draftID == nil { return }

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        
        let managedContext =
            appDelegate.persistentContainer.viewContext
        let fetchRequest =
            NSFetchRequest<ImagesArray>(entityName: "ImagesArray")
        
        fetchRequest.predicate = NSPredicate(format: "id == %d", draftID)
        do {
            let drafts = try managedContext.fetch(fetchRequest)
            for draft in drafts {
                print("delete draft")
                managedContext.delete(draft)
            }
            do {
                try managedContext.save()
            } catch let error as NSError {
                print("could not save. \(error)")
            }
        }
        catch let error as NSError {
            print("could not fetch. \(error)")
        }
    }
    
    
    func transitionToMap(postID: String, spotID: String) {

        DispatchQueue.main.async {
            
            /// if not transitioning right to spot page prepare for transition
            if ((self.postType == .postToPublic || self.postType == .postToPrivate) && self.mapVC.spotViewController != nil) {
                self.mapVC.spotViewController.newPostReset(tags: self.selectedTags)
                
            } else {
                self.mapVC.customTabBar.tabBar.isHidden = false
                self.hideFromFeed && postID != "" ? self.mapVC.profileUploadReset(spotID: spotID, postID: postID, tags: self.selectedTags) : self.mapVC.feedUploadReset()
            }
            
            self.navigationController?.popToRootViewController(animated: true)

        }
    }
    
    func showError() {
        errorBox.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            self.errorBox.isHidden = true
        }
    }
    
    func uploadPostImage(_ images: [UIImage], postID: String, completion: @escaping ((_ urls: [String]) -> ())){
        
        var index = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard let self = self else { return }
            if self.progressView.progress != 1.0 {
                completion([])
                return
            }
        }
        
        var progress = 0.7/Double(images.count)
        var URLs: [String] = []
        for _ in images {
            URLs.append("")
        }
        
        for image in images {
            
            uploadImageToFirebase(image: image, completion: { url in
                
                let i = images.lastIndex(where: {$0 == image})
                URLs[i ?? 0] = url
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.progressView.setProgress(Float(0.3 + progress), animated: true)
                }
                
                progress = progress * Double(index + 1)
                
                index += 1
                if index == images.count {
                    DispatchQueue.main.async { completion(URLs); return }
                }
            })
        }
    }
    
    func uploadImageToFirebase(image: UIImage, completion: @escaping ((_ url: String) -> ())) {
     
        let imageID = UUID().uuidString
        let storageRef = Storage.storage().reference().child("spotPics-dev").child("\(imageID)")
        
        guard var imageData = image.jpegData(compressionQuality: 0.8) else { completion(""); return }
        
        if imageData.count > 1000000 { imageData = image.jpegData(compressionQuality: 0.5)! }
        
        if imageData.count > 1000000 { imageData = image.jpegData(compressionQuality: 0.3)! }
                
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            storageRef.putData(imageData, metadata: metadata) { metadata, error in
                if error != nil { completion(""); return }
                storageRef.downloadURL { (url, err) in
                    if error != nil { completion(""); return }
                    let urlString = url!.absoluteString
                    completion(urlString)
                    return
                }
            }
        }
    }
    
    func runSpotTransactions(spotID: String, postPrivacy: String, postID: String, timestamp: Date) {
        
        /// run all spot data transactions here to avoid overlap with data updating
        
        let db = Firestore.firestore()
        let ref = db.collection("spots").document(spotID)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let spotDoc: DocumentSnapshot
            do {
                try spotDoc = transaction.getDocument(ref)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            var posterIDs = spotDoc.data()?["posterIDs"] as? [String] ?? []
            posterIDs.append(self.uid)
            
            var postPrivacies = spotDoc.data()?["postPrivacies"] as? [String] ?? []
            postPrivacies.append(postPrivacy)
            
            var visitorList = spotDoc.data()?["visitorList"] as? [String] ?? []
            if !visitorList.contains(self.uid) { visitorList.append(self.uid) }
            
            var postIDs = spotDoc.data()?["postIDs"] as? [String] ?? []
            postIDs.append(postID)
            
            var postTimestamps = spotDoc.data()?["postTimestamps"] as? [Firebase.Timestamp] ?? []
            let firTimestamp = Firebase.Timestamp(date: timestamp as Date)
            postTimestamps.append(firTimestamp)
            
            transaction.updateData([
                "posterIDs": posterIDs,
                "postPrivacies" : postPrivacies,
                "tags" : self.selectedTags,
                "visitorList" : visitorList,
                "postIDs" : postIDs,
                "postTimestamps" : postTimestamps,
            ], forDocument: ref)
            
            return nil
            
        }) { (object, error) in
            self.deleteDraft()
            self.transitionToMap(postID: postID, spotID: spotID)
        }
    }
    
    

    func runFailedUpload() {
        Mixpanel.mainInstance().track(event: "UploadPostFailed")
        /// need to reconfig save to drafts
        saveToDrafts()
        showFailAlert()
    }
    
    func showFailAlert() {
        let alert = UIAlertController(title: "Upload failed", message: "Spot saved to your drafts", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                                        switch action.style{
                                        case .default:
                                            self.transitionToMap(postID: "", spotID: "")
                                        case .cancel:
                                            self.transitionToMap(postID: "", spotID: "")
                                        case .destructive:
                                            self.transitionToMap(postID: "", spotID: "")
                                        @unknown default:
                                            fatalError()
                                        }}))
        present(alert, animated: true, completion: nil)
    }
    
    func saveToDrafts() {

        guard let appDelegate =
                UIApplication.shared.delegate as? AppDelegate else { return }
        
        let managedContext =
            appDelegate.persistentContainer.viewContext
        
        var imageObjects : [ImageModel] = []
        
        var index: Int16 = 0
        for image in selectedImages {
            let im = ImageModel(context: managedContext)
            im.imageData = image.jpegData(compressionQuality: 0.5)
            im.position = index
            imageObjects.append(im)
            index += 1
        }
        
        switch postType {
        
        case .newSpot, .postToPOI:
            
            let spotCoordinate = self.postType == .postToPOI ? CLLocationCoordinate2D(latitude: self.poi.coordinate.latitude, longitude: self.poi.coordinate.longitude) : CLLocationCoordinate2D(latitude: postLocation.latitude, longitude: postLocation.longitude)

            let spotObject = SpotDraft(context: managedContext)
            
            spotObject.spotName = spotName ?? ""
            spotObject.spotDescription = caption ?? ""
            spotObject.tags = selectedTags
            spotObject.taggedUsernames = selectedUsers.map({$0.username})
            spotObject.taggedIDs = selectedUsers.map({$0.id ?? ""})
            spotObject.postLat = postLocation.latitude
            spotObject.postLong = postLocation.longitude
            spotObject.spotLat = spotCoordinate.latitude
            spotObject.spotLong = spotCoordinate.longitude
            spotObject.images = NSSet(array: imageObjects)
            spotObject.spotID = UUID().uuidString
            spotObject.privacyLevel = self.submitPublic ? "friends" : self.postPrivacy ?? "friends"
            spotObject.inviteList = inviteList
            spotObject.uid = uid
            spotObject.phone = postType == .postToPOI ? self.poi.phone : ""
            spotObject.submitPublic = submitPublic
            spotObject.postToPOI = postType == .postToPOI
            spotObject.hideFromFeed = hideFromFeed
            spotObject.frameIndexes = frameIndexes
            spotObject.gif = imageFromCamera && selectedImages.count > 1
            
            let timestamp = postDate == nil ? Date().timeIntervalSince1970 : postDate!.timeIntervalSince1970
            let seconds = Int64(timestamp)
            spotObject.timestamp = seconds

        default:

            let spotID = spotObject.id!
            
            let spotCoordinate = CLLocationCoordinate2D(latitude: spotObject.spotLat, longitude: spotObject.spotLong)
            let createdBy = spotObject.founderID
            let spotPrivacy = spotObject == nil ? "" : postType == .newSpot ? postPrivacy : spotObject.privacyLevel
            let adjustedPostPrivacy = self.submitPublic ? "friends" : self.postPrivacy ?? "friends"
            let visitorList = spotObject == nil ? [] : spotObject.visitorList
            
            let postObject = PostDraft(context: managedContext)
            postObject.caption = caption ?? ""
            postObject.city = self.postCity
            postObject.createdBy = createdBy
            postObject.privacyLevel = adjustedPostPrivacy
            postObject.spotPrivacy = spotPrivacy
            postObject.spotID = spotID
            postObject.inviteList = inviteList
            postObject.postLat = postLocation.latitude
            postObject.postLong = postLocation.longitude
            postObject.spotLat = spotCoordinate.latitude
            postObject.spotLong = spotCoordinate.longitude
            postObject.spotName = spotName ?? ""
            postObject.taggedUsers = selectedUsers.map({$0.username})
            postObject.images = NSSet(array: imageObjects)
            postObject.uid = uid
            postObject.isFirst = false
            postObject.visitorList = visitorList
            postObject.hideFromFeed = hideFromFeed
            postObject.frameIndexes = frameIndexes
            postObject.gif = imageFromCamera && selectedImages.count > 1
            
            let timestamp = postDate == nil ? Date().timeIntervalSince1970 : postDate!.timeIntervalSince1970
            let seconds = Int64(timestamp)
            postObject.timestamp = seconds
        }
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }
    
    func saveToPhotos(images: [UIImage]) {        
        /// check for access to gallery
        if PHPhotoLibrary.authorizationStatus() != .authorized { return }
        
        /// save still
        if images.count == 1 {
            SpotPhotoAlbum.sharedInstance.save(image: images.first ?? UIImage())
            return
        }
        
        /// save GIF
        var videoImages = images
        var i = videoImages.count - 1
        var goingDown = true
        var loops = 0
        while loops <= 5 {
            videoImages.append(images[i])
            if goingDown {
                if i == 1 {
                    goingDown = false
                }
                i -= 1
            } else {
                if i == images.count - 2 {
                    loops += 1
                    goingDown = true
                }
                i += 1
            }
        }
        
        let imageAnimator = ImageAnimator(renderSettings: RenderSettings.init(), images: videoImages)
        imageAnimator.render(completion: nil)
    }
    
    
    
}

class PaddedTextField: UITextField {
    
    let padding = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 5)
    
    override open func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    
    override open func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    
    override open func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
}
/// https://stackoverflow.com/questions/25367502/create-space-at-the-beginning-of-a-uitextfield

class ShowOnFeedCell: UITableViewCell {
     
    var label: UILabel!
    var toggle: UIButton!
    var hide = false
    
    func setUp(hide: Bool) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        self.hide = hide
        
        if label != nil { label.text = "" }
        label = UILabel(frame: CGRect(x: 14, y: 5, width: 150, height: 18))
        label.text = "Post to friends feed"
        label.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        label.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        label.sizeToFit()
        contentView.addSubview(label)
                
        if toggle != nil { toggle.setImage(UIImage(), for: .normal) }
        toggle = UIButton(frame: CGRect(x: 9, y: label.frame.maxY + 5, width: 64, height: 41))
        let image = hide ? UIImage(named: "HideToggleOff") : UIImage(named: "HideToggleOn")
        toggle.setImage(image, for: .normal)
        toggle.addTarget(self, action: #selector(toggle(_:)), for: .touchUpInside)
        contentView.addSubview(toggle)
    }
    
    @objc func toggle(_ sender: UIButton) {
        hide = !hide
        let image = hide ? UIImage(named: "HideToggleOff") : UIImage(named: "HideToggleOn")
        toggle.setImage(image, for: .normal)

        guard let parentVC = viewContainingController() as? UploadPostController else { return }
        parentVC.hideFromFeed = hide
        
        let event = hide ? "HideToggleOff" : "HideToggleOn"
        Mixpanel.mainInstance().track(event: event)
    }
}

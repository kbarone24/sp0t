//
//  ShareToViewController.swift
//  Spot
//
//  Created by Kenny Barone on 5/25/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase

class ShareToController: UIViewController {
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore = Firestore.firestore()
    
    var friendsButton: UIButton!
    var publicButton: UIButton!
    var shareButton: UIButton!
    
    var progressBar: UIView!
    var progressFill: UIView!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
            
        addButtons()
        addMapTable()
        addProgressBar()
        print("ct", UploadPostModel.shared.postObject.postImage.count)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
        view.backgroundColor = UIColor(red: 0.922, green: 0.922, blue: 0.922, alpha: 1)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func setUpNavBar() {

        navigationItem.title = "Share to"
        
        /// set title to black
        if let appearance = navigationController?.navigationBar.standardAppearance {
            appearance.titleTextAttributes[.foregroundColor] = UIColor.black
            navigationItem.standardAppearance = appearance
            navigationItem.scrollEdgeAppearance = appearance
        }
        
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.removeBackgroundImage()
        navigationController?.navigationBar.removeShadow()
        
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.tintColor = .black
        navigationController?.navigationBar.barTintColor = .clear
        
        self.navigationController?.navigationBar.topItem?.backBarButtonItem = UIBarButtonItem(title: "Preview", style: .plain, target: nil, action: nil)
    }
    
    func addButtons() {
        /// work bottom to top laying out views
        shareButton = UIButton(frame: CGRect(x: (UIScreen.main.bounds.width - 240)/2, y: UIScreen.main.bounds.height - 120, width: 240, height: 60))
        shareButton.setImage(UIImage(named: "ShareButton"), for: .normal)
        shareButton.addTarget(self, action: #selector(shareTap(_:)), for: .touchUpInside)
        shareButton.isEnabled = false
        view.addSubview(shareButton)

        let spotPrivacy = UploadPostModel.shared.spotObject == nil ? "public" : UploadPostModel.shared.spotObject.privacyLevel
        let buttonCount = spotPrivacy == "public" ? 2 : 1
        let viewHeight: CGFloat = buttonCount == 2 ? 152 : 77
        
        let buttonView = UIView(frame: CGRect(x: 0, y: shareButton.frame.minY - viewHeight - 46, width: UIScreen.main.bounds.width, height: viewHeight))
        view.addSubview(buttonView)
        
        if buttonCount == 2 {
            publicButton = UIButton(frame: CGRect(x: 17, y: 87, width: UIScreen.main.bounds.width - 42, height: 65))
            publicButton.backgroundColor = nil
            publicButton.setImage(UIImage(named: "PublicMapUnselected"), for: .normal)
            publicButton.setImage(UIImage(named: "PublicMapUnselected"), for: .highlighted)
            publicButton.addTarget(self, action: #selector(publicTap(_:)), for: .touchUpInside)
            publicButton.tag = 0
            buttonView.addSubview(publicButton)
        }
        
        friendsButton = UIButton(frame: CGRect(x: 17, y: 12, width: UIScreen.main.bounds.width - 42, height: 65))
        friendsButton.backgroundColor = nil
        friendsButton.setImage(UIImage(named: "FriendsMapUnselected"), for: .normal)
        friendsButton.setImage(UIImage(named: "FriendsMapUnselected"), for: .highlighted)
        friendsButton.addTarget(self, action: #selector(friendsTap(_:)), for: .touchUpInside)
        friendsButton.tag = 0
        buttonView.addSubview(friendsButton)
    }
    
    func addMapTable() {
        
    }
    
    func addProgressBar() {
        progressBar = UIView(frame: CGRect(x: 50, y: UIScreen.main.bounds.height - 150, width: UIScreen.main.bounds.width - 100, height: 18))
        progressBar.backgroundColor = UIColor(named: "SpotGreen")?.withAlphaComponent(0.22)
        progressBar.layer.cornerRadius = 6
        progressBar.layer.borderWidth = 2
        progressBar.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        progressBar.isHidden = true
        view.addSubview(progressBar)
        
        progressFill = UIView(frame: CGRect(x: 1, y: 1, width: 0, height: 16))
        progressFill.backgroundColor = UIColor(named: "SpotGreen")
        progressFill.layer.cornerRadius = 6
        progressBar.addSubview(progressFill)
    }
    
    @objc func friendsTap(_ sender: UIButton) {
        friendsButton.tag = friendsButton.tag == 0 ? 1 : 0
        setFriendsValues()
    }
    
    func setFriendsValues() {
        let image = friendsButton.tag == 0 ? UIImage(named: "FriendsMapUnselected") : UIImage(named: "FriendsMapSelected")
        friendsButton.setImage(image, for: .normal)
                
        shareButton.isEnabled = friendsButton.tag == 1 /// friends always enabled when public is so only need to check if friends selected
        friendsButton.isEnabled = !(publicButton != nil && publicButton.tag == 1)
    }
    
    @objc func publicTap(_ sender: UIButton) {
    
        publicButton.tag = publicButton.tag == 0 ? 1 : 0
        setPublicValues()
        setFriendsValues()
    }
    
    func setPublicValues() {
        let image = publicButton.tag == 0 ? UIImage(named: "PublicMapUnselected") : UIImage(named: "PublicMapSelected")
        publicButton.setImage(image, for: .normal)

        friendsButton.tag = publicButton.tag
    }
        
    @objc func shareTap(_ sender: UIButton) {
        
        shareButton.isEnabled = false
        navigationController?.navigationBar.isUserInteractionEnabled = false

        /// make sure all post values are set for upload
        /// make sure there is a spot object attached to this post if posting to a spot
        /// need to enable create new spot
        setPostValues()

        let post = UploadPostModel.shared.postObject!
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.uploadPostImage(post.postImage, postID: post.id!, progressFill: self.progressFill) { [weak self] imageURLs, failed in
                guard let self = self else { return }
                
                if imageURLs.isEmpty && failed {
                    self.runFailedUpload()
                    return
                }
                
                
                UploadPostModel.shared.postObject.imageURLs = imageURLs
                let post = UploadPostModel.shared.postObject!
                self.uploadPost(post: post)

                if UploadPostModel.shared.spotObject != nil {
                    let spot = UploadPostModel.shared.spotObject!
                    UploadPostModel.shared.spotObject.imageURL = imageURLs.first ?? ""
                    self.uploadSpot(post: post, spot: spot, submitPublic: false)
                    
                } else {
                    /// set user values called through upload spot if there's a spot atatched to this post
                    self.setUserValues(poster: self.uid, post: post, spotID: "", visitorList: [])
                }
                
                self.popToMap()
                UploadPostModel.shared.destroy()
            }
        }
    }
    
    func setPostValues() {
        
        var taggedProfiles: [UserProfile] = []

        let word = UploadPostModel.shared.postObject.caption.split(separator: " ")
        
        for w in word {
            let username = String(w.dropFirst())
            if w.hasPrefix("@") {
                if let f = UserDataModel.shared.friendsList.first(where: {$0.username == username}) {
                    UploadPostModel.shared.postObject.taggedUsers!.append(username)
                    UploadPostModel.shared.postObject.taggedUserIDs.append(f.id!)
                    taggedProfiles.append(f)
                }
            }
        }
        
        var postFriends = UploadPostModel.shared.postObject.hideFromFeed! ? [] : UploadPostModel.shared.postObject.privacyLevel == "invite" ? UploadPostModel.shared.spotObject.inviteList!.filter(UserDataModel.shared.friendIDs.contains) : UserDataModel.shared.friendIDs
        if !postFriends.contains(uid) { postFriends.append(uid) }
        UploadPostModel.shared.postObject.friendsList = postFriends
        UploadPostModel.shared.postObject.isFirst = (UploadPostModel.shared.postType == .newSpot || UploadPostModel.shared.postType == .postToPOI)
        UploadPostModel.shared.postObject.privacyLevel = publicButton.tag == 1 ? "public" : "friends"
    }
    
    func runFailedUpload() {
        showFailAlert()
        /// save to drafts
    }
    
    func showFailAlert() {
        let alert = UIAlertController(title: "Upload failed", message: "Spot saved to your drafts", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            switch action.style{
            case .default:
                self.popToMap()
            case .cancel:
                self.popToMap()
            case .destructive:
                self.popToMap()
            @unknown default:
                fatalError()
            }}))
        present(alert, animated: true, completion: nil)
    }

    func popToMap() {
        DispatchQueue.main.async {
            self.navigationController?.popToRootViewController(animated: true)
        }
    }
}


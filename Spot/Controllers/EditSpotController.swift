//
//  EditSpotController.swift
//  Spot
//
//  Created by kbarone on 9/19/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Geofirestore
import Photos
import Mixpanel
import FirebaseUI

class EditSpotController: UIViewController {
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var spotObject: MapSpot!
    var spotPrivacy = "friends"
    
    unowned var mapVC: MapViewController!
    weak var spotVC: SpotViewController!
    
    var tableView: UITableView!
    var privacyMask: UIView!
    
    var submitPublic = false
    var active = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.isScrollEnabled = UIScreen.main.bounds.height < 600 /// only need scroll for SE
        tableView.register(EditOverviewCell.self, forCellReuseIdentifier: "EditOverviewCell")
//        tableView.register(SpotTagCell.self, forCellReuseIdentifier: "SpotTagCell")
//        tableView.register(SpotPrivacyCell.self, forCellReuseIdentifier: "SpotPrivacyCell")
        tableView.register(EditSpotHeader.self, forHeaderFooterViewReuseIdentifier: "EditSpotHeader")
        view.addSubview(tableView)
        
        if tableView.isScrollEnabled {
            tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        }
        
        spotPrivacy = spotObject.privacyLevel
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if tableView != nil { tableView.reloadData() }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        active = false
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("TagSelect"), object: nil)
    }
    
    func privacyTap() {
        spotPrivacy == "invite" ? launchFriendsPicker() : presentPrivacyPicker()
    }
    
    func presentPrivacyPicker() {
        
        privacyMask = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        privacyMask.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        privacyMask.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closePrivacyPicker(_:))))
        view.addSubview(privacyMask)
        
        let pickerView = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 361, width: UIScreen.main.bounds.width, height: 361))
        pickerView.backgroundColor = UIColor(named: "SpotBlack")
        privacyMask.addSubview(pickerView)
        
        let titleLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 100, y: 10, width: 200, height: 20))
        titleLabel.text = "Who can see this?"
        titleLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        titleLabel.font = UIFont(name: "SFCamera-Semibold", size: 15)
        titleLabel.textAlignment = .center
        pickerView.addSubview(titleLabel)
        
        let publicButton = UIButton(frame: CGRect(x: 14, y: 55, width: 171, height: 54))
        publicButton.setImage(UIImage(named: "PublicButton"), for: .normal)
        publicButton.layer.cornerRadius = 7.5
        publicButton.tag = 0
        publicButton.addTarget(self, action: #selector(privacyTap(_:)), for: .touchUpInside)
        if spotObject.privacyLevel == "public" {
            publicButton.layer.borderWidth = 1
            publicButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        }
        pickerView.addSubview(publicButton)
        
        let friendsButton = UIButton(frame: CGRect(x: 14, y: publicButton.frame.maxY + 10, width: 171, height: 54))
        friendsButton.setImage(UIImage(named: "FriendsButton"), for: .normal)
        friendsButton.layer.cornerRadius = 7.5
        friendsButton.tag = 1
        friendsButton.addTarget(self, action: #selector(privacyTap(_:)), for: .touchUpInside)
        if spotObject.privacyLevel == "friends" {
            friendsButton.layer.borderWidth = 1
            friendsButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        }
        pickerView.addSubview(friendsButton)
        
        let inviteButton = UIButton(frame: CGRect(x: 14, y: friendsButton.frame.maxY + 10, width: 171, height: 54))
        inviteButton.setImage(UIImage(named: "InviteButton"), for: .normal)
        inviteButton.layer.cornerRadius = 7.5
        inviteButton.tag = 2
        inviteButton.addTarget(self, action: #selector(privacyTap(_:)), for: .touchUpInside)
        if spotObject.privacyLevel == "invite" {
            inviteButton.layer.borderWidth = 1
            inviteButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        }
        pickerView.addSubview(inviteButton)
    }
        
    @objc func privacyTap(_ sender: UIButton) {
        
        for subview in privacyMask.subviews { subview.removeFromSuperview() }

        switch sender.tag {
        
        case 0:
            spotObject.privacyLevel = "friends" /// privacy will change on public submission confirm
            spotObject.inviteList = []
            launchSubmitPublic()
            return
            
        case 1:
            spotObject.privacyLevel = "friends"
            spotObject.inviteList = []
            
        default:
            launchFriendsPicker()
        }
        
        privacyMask.removeFromSuperview()
        tableView.reloadData()
    }
    
    @objc func closePrivacyPicker(_ sender: UIButton) {
        for subview in privacyMask.subviews { subview.removeFromSuperview() }
        privacyMask.removeFromSuperview()
    }
    
    func launchSubmitPublic() {
        
        let infoView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 116, y: UIScreen.main.bounds.height/2 - 140, width: 232, height: 180))
        infoView.backgroundColor = UIColor(named: "SpotBlack")
        infoView.layer.cornerRadius = 7.5
        infoView.clipsToBounds = true
        infoView.tag = 2
        privacyMask.addSubview(infoView)
        
        let botPic = UIImageView(frame: CGRect(x: 21, y: 22, width: 30, height: 34.44))
        botPic.image = UIImage(named: "OnboardB0t")
        infoView.addSubview(botPic)
        
        let botName = UILabel(frame: CGRect(x: botPic.frame.maxX + 8, y: 37, width: 80, height: 20))
        botName.text = "sp0tb0t"
        botName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        botName.font = UIFont(name: "SFcamera-Semibold", size: 12.5)
        infoView.addSubview(botName)
        
        let botComment = UILabel(frame: CGRect(x: 22, y: botPic.frame.maxY + 21, width: 196, height: 15))
        botComment.text = "You can submit your spot for approval on the public map."
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
        cancelButton.addTarget(self, action: #selector(closePrivacyPicker(_:)), for: .touchUpInside)
        cancelButton.tag = 5
        infoView.addSubview(cancelButton)
    }
    
    @objc func submitPublicTap(_ sender: UIButton) {
        
        submitSpot()
        
        guard let infoView = privacyMask.subviews.first(where: {$0.tag == 2}) else { return }
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
        okButton.addTarget(self, action: #selector(closePrivacyPicker(_:)), for: .touchUpInside)
        infoView.addSubview(okButton)
    }
    
    func submitSpot() {
        
        let ref = Firestore.firestore().collection("submissions")
        let spotID = spotObject.id ?? ""
        ref.document(spotID).setData(["spotID" : spotID])
        
        submitPublic = true
        spotObject.privacyLevel = "public"
        tableView.reloadData()
    }
        
    func launchFriendsPicker() {
        if let inviteVC = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "InviteFriends") as? InviteFriendsController {
            
            inviteVC.editVC = self
            
            var noBotList = UserDataModel.shared.friendsList
            noBotList.removeAll(where: {$0.id == "T4KMLe3XlQaPBJvtZVArqXQvaNT2"})
            
            inviteVC.friendsList = noBotList
            inviteVC.queryFriends = noBotList
            
            for invite in spotObject.inviteList ?? [] {
                if let friend = UserDataModel.shared.friendsList.first(where: {$0.id == invite}) {
                    inviteVC.selectedFriends.append(friend)
                }
            }
            
            for visitor in spotObject.visitorList {
                if let friend = UserDataModel.shared.friendsList.first(where: {$0.id == visitor}) {
                    if !inviteVC.selectedFriends.contains(where: {$0.id == friend.id}) { inviteVC.selectedFriends.append(friend) }
                }
            }
            
            self.present(inviteVC, animated: true, completion: nil)
        }
    }
}

extension EditSpotController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        

       // switch indexPath.row {
        
      //  case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "EditOverviewCell") as! EditOverviewCell
            cell.setUp(spot: spotObject, editVC: self)
            return cell
    /*
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SpotTagCell") as! SpotTagCell
            let spotTags: [String] = spotObject.privacyLevel == "public" ? spotObject.tags : []
            let tagsHeight: CGFloat = UserDataModel.shared.largeScreen == 0 ? 315 : UserDataModel.shared.largeScreen == 1 ? 230 : 240
            cell.setUp(selectedTags: spotObject.tags, spotTags: spotTags, collectionHeight: tagsHeight - 30)
            return cell
            
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SpotPrivacyCell") as! SpotPrivacyCell
            let postType: UploadPostController.PostType = .newSpot
            cell.setUp(type: postType, postPrivacy: spotObject.privacyLevel, spotPrivacy: spotPrivacy, inviteList: spotObject.inviteList ?? [], uploadPost: false, spotNameEmpty: false, visitorList: spotObject.visitorList)
            return cell */
    }
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        switch indexPath.row {
        
        case 0:
            return UserDataModel.shared.screenSize == 2 ? 290 : 280
            
        case 1:
            let tagsHeight: CGFloat = UserDataModel.shared.screenSize == 0 ? 315 : UserDataModel.shared.screenSize == 1 ? 230 : 240
            return tagsHeight
            
        default:
            return 60
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "EditSpotHeader") as! EditSpotHeader
        header.setUp()
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
}

class EditSpotHeader: UITableViewHeaderFooterView {
    
    var cancelButton: UIButton!
    var titleLabel: UILabel!
    var saveButton: UIButton!
    
    func setUp() {
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView
        
        resetView()
        
        cancelButton = UIButton(frame: CGRect(x: 12, y: 26, width: 60, height: 24))
        cancelButton.titleEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1), for: .normal)
        cancelButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        cancelButton.addTarget(self, action: #selector(backTapped(_:)), for: .touchUpInside)
        self.addSubview(cancelButton)
        
        titleLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 60, y: 26, width: 120, height: 20))
        titleLabel.text = "Edit Spot"
        titleLabel.textAlignment = .center
        titleLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        titleLabel.font = UIFont(name: "SFCamera-Regular", size: 16)
        self.addSubview(titleLabel)
        
        saveButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 60, y: 27, width: 50, height: 18))
        saveButton.titleEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        saveButton.setTitle("Save", for: .normal)
        saveButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        saveButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
        saveButton.addTarget(self, action: #selector(saveTap(_:)), for: .touchUpInside)
        self.addSubview(saveButton)
    }
    
    func resetView() {
        if cancelButton != nil { cancelButton.setImage(UIImage(), for: .normal)}
        if titleLabel != nil { titleLabel.text = "" }
        if saveButton != nil { saveButton.setImage(UIImage(), for: .normal)}
    }
    
    @objc func backTapped(_ sender: UIButton) {
        if let editVC = viewContainingController() as? EditSpotController {
            editVC.dismiss(animated: true, completion: nil)
        }
    }
    
    @objc func saveTap(_ sender: UIButton) {
        
        Mixpanel.mainInstance().track(event: "EditSpotSaveTap")

        if let editVC = viewContainingController() as? EditSpotController {
            let originalCoordinate = CLLocationCoordinate2D(latitude: editVC.spotObject.spotLat, longitude: editVC.spotObject.spotLong)
            let originalInvites = editVC.spotVC.spotObject.inviteList ?? []
            
            var taggedUsernames: [String] = []
            var selectedUsers: [UserProfile] = []
            
            ///for tagging users on comment post
            let words = editVC.spotObject.spotDescription.components(separatedBy: .whitespacesAndNewlines)
            
            for w in words {
                let username = String(w.dropFirst())
                if w.hasPrefix("@") {
                    if let f = UserDataModel.shared.friendsList.first(where: {$0.username == username}) {
                        selectedUsers.append(f)
                    }
                }
            }
            
            taggedUsernames = selectedUsers.map({$0.username})
            
            /// don't remember why not using resetView on spotvc here but that's essentially what this is doing
            editVC.spotObject.taggedUsers = taggedUsernames
            if editVC.submitPublic { editVC.spotObject.privacyLevel = "friends" }
            editVC.spotVC.spotObject = editVC.spotObject
            editVC.spotVC.setUpNavBar()
            editVC.spotVC.resetAnnos()
            editVC.spotVC.memberList.removeAll()
            editVC.spotVC.getVisitorInfo(refresh: true)
            
            editVC.spotVC.tableView.reloadData()
            
            NotificationCenter.default.post(Notification(name: Notification.Name("EditSpot"), object: nil, userInfo: ["spot" : editVC.spotObject as Any]))
            
            /// update spot values in db + send notifications to new invitees
            saveSpotToDB(spot: editVC.spotObject, originalCoordinate: originalCoordinate, originalInvites: originalInvites)
            
            /// update posts in "posts" to have updated spot level info
            updatePostValues(spot: editVC.spotObject)
            editVC.dismiss(animated: true, completion: nil)
        }
    }
    
    func saveSpotToDB(spot: MapSpot, originalCoordinate: CLLocationCoordinate2D, originalInvites: [String]) {
        
        let db = Firestore.firestore()
        guard let editVC = viewContainingController() as? EditSpotController else { return }
                
        let selectedUsernames = editVC.spotObject.taggedUsers
        let lowercaseName = spot.spotName.lowercased()
        let keywords = lowercaseName.getKeywordArray()
        
        let values : [String : Any] = ["spotName": spot.spotName,
                                       "lowercaseName" : lowercaseName,
                                       "description" : spot.spotDescription,
                                       "tags" : spot.tags,
                                       "spotLat": spot.spotLat,
                                       "spotLong" : spot.spotLong,
                                       "privacyLevel": spot.privacyLevel,
                                       "taggedUsers": selectedUsernames as Any,
                                       "inviteList": spot.inviteList as Any,
                                       "searchKeywords": keywords] 
        
        db.collection("spots").document(spot.id!).updateData(values)
        
        updateSpotCoordinate(spotID: spot.id!, location: CLLocation(latitude: spot.spotLat, longitude: spot.spotLong))
        
        // update city if necessary
        if spot.spotLong != originalCoordinate.longitude || spot.spotLat != originalCoordinate.latitude {
            editVC.reverseGeocodeFromCoordinate(numberOfFields: 2, location: CLLocation(latitude: spot.spotLat, longitude: spot.spotLong)) { [weak self] address  in
                if self == nil { return }
                db.collection("spots").document(spot.id!).updateData(["city" : address])
            }
        }
        
        // upload spot image if necessary
        
        if editVC.spotVC.editedImage {
            self.uploadSpotImage(image: spot.spotImage) { (url) in
                if url != "" {
                    db.collection("spots").document(spot.id!).updateData(["imageURL" : url])
                    if editVC.spotVC != nil { editVC.spotVC.editedImage = false }
                }
            }
        }
        
        /// send invites to newly invited users, remove invite notis from old users in case this was sent recently
        let firstPostID = editVC.spotVC.postsList.last?.id ?? "" /// first post is last sorted by timestamp
        updateNotificationsList(oldList: originalInvites, newList: editVC.spotObject.inviteList ?? [], user: UserDataModel.shared.userInfo, spot: editVC.spotObject, firstPostID: firstPostID, city: editVC.spotObject.city ?? "")
        
    }
    
    func updateSpotCoordinate(spotID: String, location: CLLocation) {
        
        let db = Firestore.firestore()
        let coordinate = location.coordinate
        
        db.collection("spots").document(spotID).updateData(["spotLat" : coordinate.latitude, "spotLong": coordinate.longitude])
                
        GeoFirestore(collectionRef: Firestore.firestore().collection("spots")).setLocation(location: location, forDocumentWithID: spotID) { (error) in
            if (error != nil) {
                print("An error occured: \(String(describing: error))")
            } else {
                print("Saved location successfully!")
            }
        }
    }

    
    func updatePostValues(spot: MapSpot) {
        
        let db = Firestore.firestore()
        ///update post values, post privacy only changes if spot becomes private
        var postValues = ["spotName": spot.spotName, "inviteList": spot.inviteList ?? [], "spotPrivacy": spot.privacyLevel, "spotLat": spot.spotLat, "spotLong": spot.spotLong] as [String : Any]
        if spot.privacyLevel == "invite" {
            postValues["privacyLevel"] = "invite"
        }
        
        for post in spot.postIDs {
            db.collection("posts").document(post).updateData(postValues)
            var notiValues = postValues
            notiValues["postID"] = post
            NotificationCenter.default.post(Notification(name: Notification.Name("EditPost"), object: nil, userInfo: postValues))
        }
    }
    
    func uploadSpotImage(image: UIImage, completion: @escaping ((_ url: String) -> ())){
        
        let imageID = UUID().uuidString
        let storageRef = Storage.storage().reference().child("spotPics-dev").child("\(imageID)")
        guard var imageData = image.jpegData(compressionQuality: 0.5) else { completion(""); return }
        if imageData.count > 1000000 {
            imageData = image.jpegData(compressionQuality: 0.3)!
        }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        storageRef.putData(imageData, metadata: metadata){metadata, error in
            if error != nil { completion("") }
            storageRef.downloadURL { (url, err) in
                if error != nil { completion("") }
                let urlString = url!.absoluteString
                completion(urlString)
            }
        }
    }
    
    func updateNotificationsList(oldList: [String], newList: [String], user: UserProfile, spot: MapSpot, firstPostID: String, city: String) {
        
        let newUsers = newList.filter({!oldList.contains($0)})
        let oldUsers = oldList.filter({!newList.contains($0)})
                
        let db = Firestore.firestore()
        let interval = NSDate().timeIntervalSince1970
        let timestamp = NSDate(timeIntervalSince1970: TimeInterval(interval))
        
        if firstPostID != "" {
            for newUser in newUsers {
                db.collection("users").document(newUser).collection("spotsList").document(spot.id!).setData(["spotID" : spot.id!, "checkInTime" : timestamp, "postsList" : [], "city": city], merge: true)

                let notiID = UUID().uuidString
                let notificationRef = db.collection("users").document(newUser).collection("notifications")
                let acceptRef = notificationRef.document(notiID)
                
                let notiValues = ["seen" : false, "timestamp" : timestamp, "senderID": user.id!, "type": "invite", "spotID": spot.id!, "postID" : firstPostID, "imageURL": spot.imageURL, "spotName": spot.spotName] as [String : Any]
                
                acceptRef.setData(notiValues)
                
                let sender = PushNotificationSender()
                var token: String!
                
                db.collection("users").document(newUser).getDocument { (tokenSnap, err) in
                    
                    if (tokenSnap == nil) {
                        return
                    } else {
                        token = tokenSnap?.get("notificationToken") as? String
                    }
                    if (token != nil && token != "") {
                        sender.sendPushNotification(token: token, title: "", body: "\(user.username) added you to a spot")
                    }
                }
            }
        }
        
        //delete all notis from this spot for uninvited users
        for oldUser in oldUsers {
            print("old user", oldUser)
            let notiRef = db.collection("users").document(oldUser).collection("notifications")
            let query = notiRef.whereField("spotID", isEqualTo: spot.id!)
            query.getDocuments { (querysnapshot, err) in
                for doc in querysnapshot!.documents {
                    doc.reference.delete()
                }
            }
        }
    }
}

class EditOverviewCell: UITableViewCell, UITextFieldDelegate {
    var spot: MapSpot!
    
    weak var editVC: EditSpotController!
    
    var address: String!
    var overviewImage: UIImageView!
    var editImage: UIImageView!
    var editPhotoLabel: UILabel!
    var spotNameField: UITextField!
    var locationLabel: UILabel!
    var addressButton: UIButton!
    var editAddressButton: UIButton!
    
    func setUp(spot: MapSpot, editVC: EditSpotController) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        self.editVC = editVC
        self.spot = spot
        
        resetCell()
        
        overviewImage = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 40.5, y: 30, width: 81, height: 112))
        overviewImage.contentMode = .scaleAspectFill
        overviewImage.clipsToBounds = true
        overviewImage.layer.cornerRadius = 3
        self.addSubview(overviewImage)
        
        let url = spot.imageURL

        if spot.spotImage != UIImage() {
            overviewImage.image = spot.spotImage
        } else if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 300, height: 300), scaleMode: .aspectFill)
            overviewImage.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }
        
        editImage = UIImageView(frame: CGRect(x: 8, y: overviewImage.frame.height/2 - 20, width: overviewImage.frame.width - 16, height: 40))
        editImage.image = UIImage(named: "EditCoverPhoto")
        editImage.contentMode = .scaleAspectFit
        overviewImage.addSubview(editImage)
        
        let imageButton = UIButton(frame: overviewImage.frame)
        imageButton.backgroundColor = nil
        imageButton.addTarget(self, action: #selector(editImage(_:)), for: .touchUpInside)
        self.addSubview(imageButton)
        
        spotNameField = UITextField(frame: CGRect(x: UIScreen.main.bounds.width/2 - 125, y: overviewImage.frame.maxY + 17, width: 251, height: 33))
        spotNameField.text = spot.spotName
        spotNameField.textAlignment = .center
        spotNameField.textColor = UIColor(named: "SpotGreen")
        spotNameField.font = UIFont(name: "SFCamera-Regular", size: 14)
        spotNameField.backgroundColor = .black
        spotNameField.layer.cornerRadius = 6
        spotNameField.layer.borderWidth = 1.5
        spotNameField.layer.borderColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1).cgColor
        spotNameField.delegate = self
        self.addSubview(spotNameField)

        locationLabel = UILabel(frame: CGRect(x: 14, y: spotNameField.frame.maxY + 25, width: 60, height: 20))
        locationLabel.text = "Location"
        locationLabel.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        locationLabel.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        self.addSubview(locationLabel)
        
        addressButton = UIButton(frame: CGRect(x: 14, y: locationLabel.frame.maxY, width: UIScreen.main.bounds.width - 60, height: 20))
        addressButton.titleLabel?.lineBreakMode = .byTruncatingTail
        addressButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 12.5)
        addressButton.setTitleColor(UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1), for: .normal)
        self.addSubview(addressButton)
        
        getAddress(location: CLLocation(latitude: spot.spotLat, longitude: spot.spotLong)) {  [weak self] (address) in
            
            guard let self = self else { return }
            self.address = address
            self.addressButton.setTitle(address, for: .normal)
            self.addressButton.sizeToFit()
            
            self.editAddressButton = UIButton(frame: CGRect(x: self.addressButton.frame.maxX + 2, y: self.addressButton.frame.minY, width: 27, height: 27))
            self.editAddressButton.setImage(UIImage(named: "EditPost"), for: .normal)
            self.editAddressButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            self.editAddressButton.addTarget(self, action: #selector(self.editAddress(_:)), for: .touchUpInside)
            self.addSubview(self.editAddressButton)
        }
    }
    
    func getAddress(location: CLLocation, completion: @escaping (_ address: String) -> Void) {
        /// store address to avoid blinking on refresh
        if address != nil { completion(address); return }
        
        reverseGeocodeFromCoordinate(numberOfFields: 4, location: CLLocation(latitude: spot.spotLat, longitude: spot.spotLong)) { (address) in
            completion(address)
        }
    }
    
    @objc func editAddress(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "LocationPicker") as? LocationPickerController {
            
            vc.selectedImages = [spot.spotImage]
            vc.passedLocation = CLLocation(latitude: spot.spotLat, longitude: spot.spotLong)
            vc.passedAddress = addressButton.titleLabel?.text ?? ""
            vc.spotObject = editVC.spotObject
            
            editVC.mapVC.navigationController?.pushViewController(vc, animated: true)
            editVC.spotVC.editedSpot = editVC.spotObject
            editVC.dismiss(animated: false)
        }
    }
    
    @objc func editImage(_ sender: UIButton) {
        if let photosVC = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "PhotosContainer") as? PhotosContainerController {
            
            photosVC.editSpotMode = true
            
            self.editVC.spotVC.editedSpot = self.editVC.spotObject
            self.editVC.mapVC.navigationController?.setNavigationBarHidden(false, animated: false)
            
            DispatchQueue.main.async {
                self.editVC.mapVC.navigationController?.pushViewController(photosVC, animated: true)
                self.editVC.dismiss(animated: false)
            }
        }
    }
    
    func resetCell() {
        if overviewImage != nil { overviewImage.image = UIImage() }
        if editImage != nil { editImage.image = UIImage() }
        if editPhotoLabel != nil { editPhotoLabel.text = "" }
        if spotNameField != nil { spotNameField.text = "" }
        if locationLabel != nil { locationLabel.text = "" }
        if addressButton != nil { addressButton.setTitle("", for: .normal) }
        if editAddressButton != nil { editAddressButton.setImage(UIImage(), for: .normal)}
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        
        if let editVC = self.viewContainingController() as? EditSpotController {
            if updatedText.count <= 60 { editVC.spotObject.spotName = updatedText }
        }
        
        return updatedText.count <= 60
        
    }
}


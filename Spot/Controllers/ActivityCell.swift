//
//  ActivityCell.swift
//  Spot
//
//  Created by Shay Gyawali on 6/26/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel
import FirebaseUI
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth
import FirebaseMessaging
import Geofirestore

class ActivityCell: UITableViewCell {
    
    weak var delegate: delegateProtocol?
    var username: UILabel!
    var detail: UILabel!
    var timestamp: UILabel!
    var profilePicButton: UIButton!
    var profilePic: UIImageView!
    var userAvatar: UIImageView!
    var postImageButton: UIButton!
    var postImage: UIImageView!
    var imageURLs: [String] = []
    
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?){
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func printThis(int: Int){
        delegate?.printThis(myInt: int)
    }
    
    func showProfile(){
        delegate?.showProfile()
    }
    
    func set(notification: UserNotification){
        
        print("activity CELLLL")
        
        self.resetCell()
        
        let profilePicButton = UIButton()
        contentView.addSubview(profilePicButton)
        profilePicButton.addTarget(self, action: #selector(profileTap(_:)), for: .touchUpInside)

        
        profilePicButton.snp.makeConstraints{
            $0.centerY.equalToSuperview()
            $0.leading.equalToSuperview().offset(16)
            $0.height.width.equalTo(50)
        }
        
        
        profilePic = UIImageView {
            $0.frame = CGRect(x: 65, y: 27.5, width: 50, height: 50)
            $0.layer.masksToBounds = false
            $0.layer.cornerRadius = $0.frame.height/2
            $0.clipsToBounds = true
            $0.contentMode = UIView.ContentMode.scaleAspectFill
            $0.isHidden = false
            $0.translatesAutoresizingMaskIntoConstraints = true
            profilePicButton.addSubview($0)
            let url = notification.userInfo!.imageURL
            if url != "" {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
                $0.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer]) } else {print("profilePic not found")}
        }
        
        profilePic.snp.makeConstraints{
            $0.centerY.equalToSuperview()
            $0.centerX.equalToSuperview()
            $0.height.width.equalTo(50)
        }

        if(notification.userInfo?.avatarURL != ""){

            userAvatar = UIImageView{
                $0.frame = CGRect(x: 65, y: 27.5, width: 71, height: 71)
                $0.layer.masksToBounds = false
                $0.contentMode = UIView.ContentMode.scaleAspectFill
                $0.isHidden = false
                var url = notification.userInfo!.avatarURL!
                if url != "" {
                    let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
                    $0.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
                } else {print("🙈 NOOOOOOO")}
                $0.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview($0)
            }
            
            userAvatar.snp.makeConstraints{
                $0.leading.equalTo(profilePic.snp.leading).offset(-3)
                $0.bottom.equalTo(profilePic.snp.bottom).offset(3)
                $0.height.equalTo(33)
                $0.width.equalTo(25.14)
            }
        }
        
       username = UILabel{
            $0.text = notification.senderUsername
            $0.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.postTap(_:)))
            $0.addGestureRecognizer(tap)
            $0.numberOfLines = 0
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        username.snp.makeConstraints{
            $0.top.equalToSuperview().offset(15)
            $0.leading.equalTo(profilePic.snp.trailing).offset(8)
        }
        
        detail = UILabel {
            let notiType = notification.type
            switch notiType {
            case "like":
                $0.text = "liked your post"
            case "comment":
                $0.text = "commented on your post"
            case "friendRequest":
                $0.text = "accepted your friend request!"
            case "commentTag":
                $0.text = "mentioned you in a comment"
            case "commentLike":
                $0.text = "liked your comment"
            case "commentComment":
                var notifText = "commented on "
                notifText += notification.originalPoster!
                notifText += "'s post"
                $0.text = notifText
            case "commentOnAdd":
                var notifText = "commented on "
                notifText += notification.originalPoster!
                notifText += "'s post"
                $0.text = notifText
            case "likeOnAdd":
                var notifText = "liked "
                notifText += notification.originalPoster!
                notifText += "'s post"
                $0.text = notifText
            case "mapInvite":
                $0.text = "invited you to a map!"
            case "mapPost":
                var notifText = "posted to "
                notifText += notification.postInfo!.mapName!
                $0.text = notifText
            case "post":
                var notifText = "posted at "
                notifText += notification.postInfo!.spotName!
                $0.text = notifText
            case "postAdd":
                $0.text = "added you to a post"
            case "publicSpotAccepted":
                $0.text = "Your public submission was approved!"
            default:
                $0.text = notification.type
            }
            $0.numberOfLines = 0
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Regular", size: 14.5)
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        detail.snp.makeConstraints{
            $0.top.equalTo(username.snp.bottom)
            $0.leading.equalTo(profilePic.snp.trailing).offset(8)
        }
        
        timestamp = UILabel{
            $0.text = notification.timeString
            $0.font = UIFont(name: "SFCompactText-Regular", size: 14.5)
            $0.textColor = UIColor(red: 0.696, green: 0.696, blue: 0.696, alpha: 1)
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        timestamp.snp.makeConstraints{
            $0.leading.equalTo(detail.snp.trailing).offset(8)
            $0.top.equalTo(detail.snp.top)
        }
        
        let postImageButton = UIButton()
        contentView.addSubview(postImageButton)
        postImageButton.addTarget(self, action: #selector(profileTap(_:)), for: .touchUpInside)
        
        postImageButton.snp.makeConstraints{            $0.trailing.equalToSuperview().offset(-14)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(44)
            $0.height.equalTo(52)
        }
    
        postImage = UIImageView {
            $0.frame = CGRect(x: 0, y: 0, width: 44, height: 52)
            $0.layer.masksToBounds = false
            $0.clipsToBounds = true
            $0.contentMode = UIView.ContentMode.scaleAspectFill
            $0.isHidden = false
            $0.translatesAutoresizingMaskIntoConstraints = true
            postImageButton.addSubview($0)
            
            if(notification.postInfo != nil){
                imageURLs = notification.postInfo!.imageURLs
            }
            if(imageURLs.count > 0){
                $0.layer.cornerRadius = 5
                let transformer = SDImageResizingTransformer(size: CGSize(width: 88, height: 102), scaleMode: .aspectFill)
                $0.sd_setImage(with: URL(string: imageURLs[0]), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
                
            } else {
                let notiType = notification.type
                switch notiType {
                case "friendRequest":
                    $0.image =  UIImage(named: "AcceptedYourFriendRequest")
                    $0.layer.cornerRadius = 0
                case "mapInvite":
                    $0.image =  UIImage(named: "AddedToMap")
                default:
                    $0.image = UIImage(named: "XFriendRequest")
                }
            }
        }

            print("🤢", postImage)
        
        postImage.snp.makeConstraints{
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview()
            let notiType = notification.type
            switch notiType {
            case "friendRequest":
                $0.width.equalTo(33)
                $0.height.equalTo(24)
            case "mapInvite":
                $0.width.equalTo(31.3)
                $0.height.equalTo(30)
            default:
                $0.width.equalTo(44)
                $0.height.equalTo(52)
            }
        }
        
    }
        
    
    
    @objc func profileTap(_ sender: Any){
        print("testing")
        printThis(int: 10)
        showProfile()
       /* let profileVC = ProfileViewController()
        sheetView = DrawerView(present: profileVC, drawerConrnerRadius: 22, detentsInAscending: [.Middle, .Top], closeAction: {
            self.sheetView = nil
        })
        sheetView?.swipeDownToDismiss = true
        sheetView?.present(to: .Middle)*/
    }
    
    @objc func postTap(_ sender: Any){
        //SHOW POST INSTEAD ONCE YOU CAN
        print("post Tapped!")
        showProfile()
    }
    
    func resetCell() {
        if profilePic != nil {
            print("profPicNull")
            profilePic.image = UIImage() }
        if postImage != nil {
            print("postImageNull")
            postImage.image = UIImage() }
        if userAvatar != nil {
            print("userAvaterNull")
            userAvatar.image = UIImage() }
        if username != nil {username.text=""}
        if detail != nil {detail.text = ""}
        if timestamp != nil {timestamp.text = ""}
        if imageURLs.count != 0 {imageURLs = []}
    }
    
       override func prepareForReuse() {
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
        if userAvatar != nil { userAvatar.sd_cancelCurrentImageLoad() }
        // Remove Subviews Or Layers That Were Added Just For This Cell
    }
    
}
    


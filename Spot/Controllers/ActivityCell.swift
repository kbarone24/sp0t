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
    
    weak var notificationControllerDelegate: notificationDelegateProtocol?
    var username: UILabel!
    var detail: UILabel!
    var timestamp: UILabel!
    var profilePicButton: UIButton!
    var profilePic: UIImageView!
    var userAvatar: UIImageView!
    var postImageButton: UIButton!
    var postImage: UIImageView!
    var imageURLs: [String] = []
    var notification: UserNotification!
    var detailOriginalWidth: CGFloat!
    var detailOriginalHeight: CGFloat!
    

    
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?){
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    // MARK: setting up views
    func set(notification: UserNotification){
        self.resetCell()
        
        self.notification = notification
        
        if (notification.type == "friendRequest" && notification.status == "accepted" && notification.seen == false) ||  notification.type == "mapInvite" && notification.seen == false{
            self.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 0.2)
        } else { self.backgroundColor = .white }
        
        self.selectionStyle = .none
        
        let profilePicButton = UIButton()
        contentView.addSubview(profilePicButton)
        profilePicButton.addTarget(self, action: #selector(profileTap(_:)), for: .touchUpInside)

        
        profilePicButton.snp.makeConstraints{
            $0.centerY.equalToSuperview()
            $0.leading.equalToSuperview().offset(16)
            $0.height.width.equalTo(50)
        }
        
        
        profilePic = UIImageView {
            $0.layer.masksToBounds = false
            $0.layer.cornerRadius = 25
            $0.clipsToBounds = true
            $0.contentMode = UIView.ContentMode.scaleAspectFill
            $0.isHidden = false
            $0.translatesAutoresizingMaskIntoConstraints = true
            profilePicButton.addSubview($0)
            let url = notification.userInfo!.imageURL
            if url != "" {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
                $0.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer]) } else {print("profilePic not found")}
        }
        
        profilePic.snp.makeConstraints{
            $0.centerY.equalToSuperview()
            $0.centerX.equalToSuperview()
            $0.height.width.equalTo(50)
        }

        if (notification.userInfo?.avatarURL ?? "") != "" {
            userAvatar = UIImageView{
                $0.layer.masksToBounds = false
                $0.contentMode = UIView.ContentMode.scaleAspectFill
                $0.isHidden = false
                let url = notification.userInfo!.avatarURL!
                if url != "" {
                    let transformer = SDImageResizingTransformer(size: CGSize(width: 50.24, height: 66), scaleMode: .aspectFit)
                    $0.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
                } else { print("Avatar not found") }
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
        
        let postImageButton = UIButton()
        contentView.addSubview(postImageButton)
        postImageButton.addTarget(self, action: #selector(postTap(_:)), for: .touchUpInside)
        
        postImageButton.snp.makeConstraints{
            $0.trailing.equalToSuperview().offset(-14)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(44)
            $0.height.equalTo(52)
        }
    
        postImage = UIImageView {
            $0.layer.masksToBounds = false
            $0.clipsToBounds = true
            $0.contentMode = UIView.ContentMode.scaleAspectFill
            $0.isHidden = false
            $0.translatesAutoresizingMaskIntoConstraints = true
            postImageButton.addSubview($0)
            
            if(notification.postInfo != nil){
                imageURLs = notification.postInfo!.imageURLs
            }
            
            let notiType = notification.type
            switch notiType {
            case "friendRequest":
                $0.image =  UIImage(named: "AcceptedYourFriendRequest")
                $0.layer.cornerRadius = 0
            case "mapInvite":
                $0.image =  UIImage(named: "AddedToMap")
            default:
                if(imageURLs.count > 0){
                    $0.layer.cornerRadius = 5
                    let transformer = SDImageResizingTransformer(size: CGSize(width: 88, height: 102), scaleMode: .aspectFill)
                    $0.sd_setImage(with: URL(string: imageURLs[0]), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
                }
            }
            
        }
        
        postImage.snp.makeConstraints{
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview()
            let notiType = notification.type
            switch notiType {
            case "friendRequest":
                $0.width.equalTo(33)
                $0.height.equalTo(27)
            case "mapInvite":
                $0.width.equalTo(45.07)
                $0.height.equalTo(30.04)
            default:
                $0.width.equalTo(44)
                $0.height.equalTo(52)
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
                
        timestamp = UILabel{
            $0.text = notification.timeString
            $0.font = UIFont(name: "SFCompactText-Regular", size: 14.5)
            $0.textColor = UIColor(red: 0.696, green: 0.696, blue: 0.696, alpha: 1)
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        //timestamp constraints set later because they rely on detail constraints
        
        var detailWidth = 0.0

        if(timestamp.intrinsicContentSize.width < 20){
            detailWidth = 215 + 20
        } else if (timestamp.intrinsicContentSize.width < 30){
            detailWidth = 215 + 10
        } else { detailWidth = 215 }
        

        detail = UILabel {
            let notiType = notification.type
            switch notiType {
            case "like":
                $0.text = "liked your post"
            case "comment":
                $0.text = "commented on your post"
            case "friendRequest":
                $0.text = "you are now friends!"
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
            case "cityPost":
                var notifText = "posted in "
                notifText += notification.postInfo!.spotName!
                $0.text = notifText
            default:
                $0.text = notification.type
            }

            $0.numberOfLines = 2
            $0.lineBreakMode = NSLineBreakMode.byWordWrapping
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Regular", size: 14.5)
            $0.translatesAutoresizingMaskIntoConstraints = false
            detailOriginalWidth = $0.intrinsicContentSize.width
            $0.preferredMaxLayoutWidth = detailWidth
            contentView.addSubview($0)
        }
        
        detailOriginalHeight = detail.intrinsicContentSize.height
        
        username.snp.makeConstraints{
            $0.leading.equalTo(profilePic.snp.trailing).offset(8)
            $0.centerY.equalToSuperview().offset((-1*detailOriginalHeight)/2)
        }
        
        
                 
        detail.snp.makeConstraints{
            $0.top.equalTo(username.snp.bottom)
            $0.leading.equalTo(profilePic.snp.trailing).offset(7)
            $0.width.lessThanOrEqualTo(detailWidth)
        }
        
        
        timestamp.snp.makeConstraints{
            $0.bottom.equalTo(detail.snp.bottom)
            var timeLeading = detail.intrinsicContentSize.width
            if(timeLeading < detailOriginalWidth){
                timeLeading = detailOriginalWidth - detail.intrinsicContentSize.width
            }
            $0.leading.equalTo(detail.snp.leading).offset(timeLeading + 6)
        }
        
    }
        
    @objc func profileTap(_ sender: Any){
        notificationControllerDelegate?.getProfile(userProfile: notification.userInfo!)
    }
    
    @objc func postTap(_ sender: Any){
        //SHOW POST INSTEAD ONCE YOU CAN
        print("post tapped")
        notificationControllerDelegate?.deleteFriend(friendID: (notification.userInfo?.id!)!)
    }
    
    func resetCell() {
        if self.contentView.subviews.isEmpty == false {
            for subview in self.contentView.subviews {
                subview.removeFromSuperview()
            }
        }
         
    }
    
       override func prepareForReuse() {
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
        if userAvatar != nil { userAvatar.sd_cancelCurrentImageLoad() }
        // Remove Subviews Or Layers That Were Added Just For This Cell
    }
    
}

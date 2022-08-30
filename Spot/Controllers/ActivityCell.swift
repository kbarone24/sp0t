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
    var subtitle: String!
    var time: String!
    var timestamp: UILabel!
    var profilePic: UIImageView!
    var userAvatar: UIImageView!
    var postImage: UIImageView!
    var imageURLs: [String] = []
    
    var notification: UserNotification!
    var detailOriginalWidth: CGFloat!
    var detailOriginalHeight: CGFloat!
    
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?){
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
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
        
        profilePic = UIImageView {
            $0.layer.masksToBounds = false
            $0.layer.cornerRadius = 25
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFill
            $0.isHidden = false
            $0.translatesAutoresizingMaskIntoConstraints = true
            $0.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(profileTap))
            $0.addGestureRecognizer(tap)
            contentView.addSubview($0)
            let url = notification.userInfo!.imageURL
            if url != "" {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
                $0.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer]) } else {print("profilePic not found")}
        }
        profilePic.snp.makeConstraints{
            $0.centerY.equalToSuperview()
            $0.leading.equalToSuperview().offset(16)
            $0.height.width.equalTo(50)
        }
        
        if (notification.userInfo?.avatarURL ?? "") != "" {
            userAvatar = UIImageView{
                $0.layer.masksToBounds = false
                $0.contentMode = .scaleAspectFill
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
        
        postImage = UIImageView {
            $0.layer.masksToBounds = false
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFill
            $0.isHidden = false
            $0.translatesAutoresizingMaskIntoConstraints = true
            contentView.addSubview($0)
            
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
        
        postImage.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            let notiType = notification.type
            switch notiType {
            case "friendRequest":
                $0.width.equalTo(33)
                $0.height.equalTo(27)
                $0.trailing.equalToSuperview().offset(-22)
            case "mapInvite":
                $0.width.equalTo(45.07)
                $0.height.equalTo(30.04)
                $0.trailing.equalToSuperview().offset(-13.5)
            default:
                $0.width.equalTo(44)
                $0.height.equalTo(52)
                $0.trailing.equalToSuperview().offset(-14)
            }
        }
        
        username = UILabel {
            $0.text = notification.userInfo?.username ?? ""
            $0.isUserInteractionEnabled = true
            $0.numberOfLines = 0
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
            $0.translatesAutoresizingMaskIntoConstraints = false
            let tap = UITapGestureRecognizer(target: self, action: #selector(profileTap))
            $0.addGestureRecognizer(tap)
            contentView.addSubview($0)
        }

        //timestamp constraints set later because they rely on detail constraints

        let notiType = notification.type
        switch notiType {
        case "like":
            subtitle = "liked your post"
        case "comment":
            subtitle = "commented on your post"
        case "friendRequest":
            subtitle = "you are now friends!"
        case "commentTag":
            subtitle = "mentioned you in a comment"
        case "commentLike":
            subtitle = "liked your comment"
        case "commentComment":
            var notifText = "commented on "
            notifText += notification.originalPoster!
            notifText += "'s post"
            subtitle = notifText
        case "commentOnAdd":
            var notifText = "commented on "
            notifText += notification.originalPoster!
            notifText += "'s post"
            subtitle = notifText
        case "likeOnAdd":
            var notifText = "liked "
            notifText += notification.originalPoster!
            notifText += "'s post"
            subtitle = notifText
        case "mapInvite":
            subtitle = "invited you to a map!"
        case "mapPost":
            var notifText = "posted to "
            notifText += notification.postInfo!.mapName!
            subtitle = notifText
        case "post":
            var notifText = "posted at "
            notifText += notification.postInfo!.spotName!
            subtitle = notifText
        case "postAdd":
            subtitle = "added you to a post"
        case "publicSpotAccepted":
            subtitle = "Your public submission was approved!"
        case "cityPost":
            var notifText = "posted in "
            notifText += notification.postInfo!.spotName!
            subtitle = notifText
        default:
            subtitle = notification.type
        }
        
        timestamp = UILabel {
            $0.toTimeString(timestamp: notification.timestamp)
        }
        
        time = timestamp.text
        let combined = subtitle + "  " + time
        let attributedString = NSMutableAttributedString(string: combined)
        let detailRange = NSRange(location: 0, length: attributedString.length - time.count)
        let timeRange = NSRange(location: attributedString.length - time.count, length: time.count)
        
        attributedString.addAttribute(.font, value: UIFont(name: "SFCompactText-Regular", size: 14.5)!, range: detailRange)
        attributedString.addAttribute(.foregroundColor, value: UIColor.black, range: detailRange)
        
        attributedString.addAttribute(.font, value: UIFont(name: "SFCompactText-Regular", size: 14.5)!, range: timeRange)
        attributedString.addAttribute(.foregroundColor, value: UIColor(red: 0.696, green: 0.696, blue: 0.696, alpha: 1), range: timeRange)
        
        let detailWidth = 230.0
                
        detail = UILabel {
            $0.attributedText = attributedString
            $0.numberOfLines = 2
            $0.lineBreakMode = NSLineBreakMode.byWordWrapping
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.sizeToFit()
            detailOriginalWidth = $0.intrinsicContentSize.width
            $0.preferredMaxLayoutWidth = detailWidth
            contentView.addSubview($0)
        }
                        
        username.snp.makeConstraints{
            $0.leading.equalTo(profilePic.snp.trailing).offset(8)
            $0.centerY.equalToSuperview()
        }
        
        detail.snp.makeConstraints{
            $0.top.equalTo(username.snp.bottom)
            $0.leading.equalTo(profilePic.snp.trailing).offset(7)
            $0.trailing.equalTo(postImage.snp.leading).offset(-10)
        }
        
        detailOriginalHeight = detail.intrinsicContentSize.height
        username.snp.updateConstraints{
            $0.centerY.equalToSuperview().offset((-1*detailOriginalHeight)/2)
        }

    }
    
    func lines(label: UILabel) -> Int {
        let textSize = CGSize(width: label.frame.size.width, height: CGFloat(Float.infinity))
        let rHeight = lroundf(Float(label.sizeThatFits(textSize).height))
        let charSize = lroundf(Float(label.font.lineHeight))
        let lineCount = rHeight/charSize
        return lineCount
    }
    
    @objc func profileTap() {
        Mixpanel.mainInstance().track(event: "ActivityCellFriendTap")
        notificationControllerDelegate?.getProfile(userProfile: notification.userInfo!)
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

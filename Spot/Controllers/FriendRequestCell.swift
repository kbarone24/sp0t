//
//  FriendRequestCell.swift
//  Spot
//
//  Created by Shay Gyawali on 6/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import FirebaseUI
import Mixpanel

class FriendRequestCell: UICollectionViewCell {
    
    var friendRequest: UserNotification!
    var confirmedView: UIView!
    var profilePic: UIImageView! //imageView
    var userAvatar: UIImageView!
    var senderView: UIView!
    var closeButton: UIButton!
    var acceptButton: UIButton! //acceptButton
    var aliveToggle: UIButton!
    var senderUsername: UILabel!
    var senderName: UILabel!
    var timestamp: UILabel!
    
    var checkMark: UIImageView!
    var confirmed: UILabel!
    
    weak var collectionDelegate: friendRequestCollectionCellDelegate!
    weak var notificationControllerDelegate: notificationDelegateProtocol?

    // variables for activity indicator that will be used later
    lazy var activityIndicator = UIActivityIndicatorView()
    var globalRow = 0
    
    var directionUp = true
    var animationIndex = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
       // initialize what is needed
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    func setUp(notification: UserNotification) {
        
        
        self.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
        self.layer.cornerRadius = 11.31
        
        resetCell()
        
        self.friendRequest = notification
        
        /*senderView = UIView {
            $0.frame = CGRect(x: 65, y: 27.5, width: 71, height: 71)
            contentView.addSubview($0)
        } ///might use later for avatarShadow
        
        senderView.snp.makeConstraints{
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().offset(15)
            $0.height.width.equalTo(71)
        }*/
        
        let profilePicButton = UIButton()
        contentView.addSubview(profilePicButton)
        profilePicButton.addTarget(self, action: #selector(profileTap(_:)), for: .touchUpInside)

        
        profilePicButton.snp.makeConstraints{
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().offset(15)
            $0.height.width.equalTo(71)
        }
            
        profilePic = UIImageView{
            $0.frame = CGRect(x: 65, y: 27.5, width: 71, height: 71)
            $0.layer.masksToBounds = false
            $0.layer.cornerRadius = $0.frame.height/2
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFill
            $0.isHidden = false
            profilePicButton.addSubview($0)
            let url = friendRequest.userInfo!.imageURL
            if url != "" {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
                $0.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
            } else {print("profilePic not found")}
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        profilePic.snp.makeConstraints{
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().offset(15)
            $0.height.width.equalTo(71)
        }
        
        if(friendRequest.userInfo?.avatarURL != ""){
            userAvatar = UIImageView{
                $0.frame = CGRect(x: 65, y: 27.5, width: 71, height: 71)
                $0.layer.masksToBounds = false
                $0.contentMode = UIView.ContentMode.scaleAspectFill
                $0.isHidden = false
                let url = friendRequest.userInfo!.avatarURL!
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
                $0.height.equalTo(39)
                $0.width.equalTo(30)
            }
        }
        
        
        senderName = UILabel{
            $0.text = friendRequest.userInfo?.name
            $0.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.profileTap(_:)))
            $0.addGestureRecognizer(tap)
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 16.5)
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        senderName.snp.makeConstraints{
            $0.centerX.equalToSuperview()
            $0.top.equalTo(profilePic.snp.bottom).offset(10)
        }

    
        senderUsername = UILabel{
            $0.text = friendRequest.senderUsername
            $0.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.profileTap(_:)))
            $0.addGestureRecognizer(tap)
            $0.textColor = UIColor(red: 0.675, green: 0.675, blue: 0.675, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 14.5)
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        senderUsername.snp.makeConstraints{
            $0.centerX.equalToSuperview()
            $0.top.equalTo(senderName.snp.bottom).offset(1)
            
        }
        
        confirmedView = UIView{
            $0.frame = CGRect(x: 0, y: 0, width: 141, height: 37)
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        confirmedView.snp.makeConstraints{
            $0.centerX.equalToSuperview()
            $0.top.equalTo(senderUsername.snp.bottom).offset(10)
            $0.height.equalTo(37)
            $0.width.equalTo(115)
        }
        
        checkMark = UIImageView{
            $0.frame = CGRect(x: 0, y: 0, width: 23, height: 23)
            $0.layer.masksToBounds = true
            $0.clipsToBounds = true
            $0.contentMode = UIView.ContentMode.scaleAspectFit
            $0.isHidden = false
            $0.image = UIImage(named: "AcceptedTheirFriendRequest")
            $0.translatesAutoresizingMaskIntoConstraints = false
            confirmedView.addSubview($0)
        }
        
        confirmed = UILabel{
            $0.text = "Confirmed"
            $0.textColor = UIColor(red: 0, green: 0.591, blue: 0.629, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 16)
            $0.isHidden = false
            $0.translatesAutoresizingMaskIntoConstraints = false
            confirmedView.addSubview($0)
        }

        
        checkMark.snp.makeConstraints{
            $0.leading.equalToSuperview()
            $0.centerY.equalToSuperview()
            $0.height.equalTo(23)
            $0.width.equalTo(23)
        }
        
        confirmed.snp.makeConstraints{
            $0.leading.equalTo(checkMark.snp.trailing).offset(5)
            $0.centerY.equalToSuperview()
        }
        

        acceptButton = UIButton{
            $0.frame = CGRect(x: 0, y: 0, width: 141, height: 37)
            $0.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            $0.layer.cornerRadius = 11.31
            $0.layer.borderWidth = 1
            $0.layer.borderColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1).cgColor
            let customButtonTitle = NSMutableAttributedString(string: "Accept", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
                //NSAttributedString.Key.backgroundColor: UIColor.red,
                NSAttributedString.Key.foregroundColor: UIColor.black
            ])
            $0.setAttributedTitle(customButtonTitle, for: .normal)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.addTarget(self, action: #selector(acceptTap(_:)), for: .touchUpInside)
            $0.isHidden = false
            contentView.addSubview($0)
        }
        
        acceptButton.snp.makeConstraints{
            $0.centerX.equalToSuperview()
            $0.top.equalTo(senderUsername.snp.bottom).offset(10)
            $0.height.equalTo(37)
            $0.width.equalTo(141)
        }

        closeButton = UIButton {
            $0.frame = CGRect(x: 0, y: 0, width: 33, height: 33)
            $0.setImage(UIImage(named: "XFriendRequest"), for: .normal)
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        closeButton.snp.makeConstraints{
            $0.leading.equalToSuperview()
            $0.top.equalToSuperview()
            $0.width.height.equalTo(32)
        }
        
        timestamp = UILabel{
            $0.text = friendRequest.timeString
            $0.font = UIFont(name: "SFCompactText-Regular", size: 14.5)
            $0.textColor = UIColor(red: 0.696, green: 0.696, blue: 0.696, alpha: 1)
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        timestamp.snp.makeConstraints{
            $0.trailing.equalToSuperview().offset(-5)
            $0.top.equalToSuperview().offset(5)
        }
    }
        
    func resetCell() {
        ///keeping this here in case not having it causes problems during QA
        ///
       /* if confirmed != nil {confirmed = UILabel()}
        if checkMark != nil {checkMark.image = UIImage()}
        if confirmedView != nil {confirmedView = UIView()}
        if profilePic != nil { profilePic.image = UIImage() }
        if userAvatar != nil { userAvatar.image = UIImage() }
        if closeButton != nil { closeButton.setImage(UIImage(), for: .normal) }
        if acceptButton != nil {acceptButton = UIButton()}
        if senderUsername != nil {senderUsername = UILabel()}
        if senderName != nil {senderName = UILabel()}
        if timestamp != nil {timestamp = UILabel()}*/
        
        if self.contentView.subviews.isEmpty == false {
            for subview in self.contentView.subviews {
                subview.removeFromSuperview()
            }
        }
    }
    
    @objc func profileTap(_ sender: Any){
        notificationControllerDelegate?.getProfile()
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        //handle cancel tap
        Mixpanel.mainInstance().track(event: "NotificationsFriendRequestRemoved")
        collectionDelegate?.deleteFriendRequest(sender: self)
    }
    
    @objc func acceptTap(_ sender: UIButton){
        Mixpanel.mainInstance().track(event: "NotificationsFriendRequestAccepted")
        print("Accept button clicked")
        acceptButton.isHidden = true
        collectionDelegate?.acceptFriend(sender: self)
    }
    
    override func prepareForReuse() {
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
        if userAvatar != nil { userAvatar.sd_cancelCurrentImageLoad() }
    }
    
    func addActivityIndicator() {
        bringSubviewToFront(activityIndicator)
        activityIndicator.startAnimating()
    }
    
    func removeActivityIndicator() {
        activityIndicator.stopAnimating()
    }

}

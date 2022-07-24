//
//  CustomMapHeaderCell.swift
//  Spot
//
//  Created by Arnold on 7/24/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SnapKit
import Firebase
import Mixpanel

class CustomMapHeaderCell: UICollectionViewCell {
    
    private var mapCoverImage: UIImageView!
    private var mapName: UILabel!
    private var mapCreaterProfileImage1: UIImageView!
    private var mapCreaterProfileImage2: UIImageView!
    private var mapCreaterProfileImage3: UIImageView!
    private var mapCreaterProfileImage4: UIImageView!
    private var mapCreaterCount: UILabel!
    private var mapInfo: UILabel!
    public var actionButton: UIButton!
    private var mapBio: UILabel!
    
    private var profile: UserProfile!
    private var relation: ProfileRelation!
    private var pendingFriendNotiID: String?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        
    }
    
    public func cellSetup(userProfile: UserProfile, relation: ProfileRelation) {
        self.profile = userProfile
        self.relation = relation
        switch relation {
        case .myself:
            actionButton.setTitle("Edit profile", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
        case .friend:
            actionButton.setImage(UIImage(named: "FriendsIcon"), for: .normal)
            actionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
            actionButton.setTitle("Friends", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
        case .pending:
            actionButton.setImage(UIImage(named: "FriendsPendingIcon"), for: .normal)
            actionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
            actionButton.setTitle("Pending", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
        case .stranger, .received:
            actionButton.setImage(UIImage(named: "AddFriendIcon"), for: .normal)
            actionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
            actionButton.setTitle(relation == .stranger ? "Add friend" : "Accept friend request", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
        }
        actionButton.addTarget(self, action: #selector(actionButtonAction), for: .touchUpInside)
        actionButton.setTitleColor(.black, for: .normal)
    }
}

extension CustomMapHeaderCell {
    private func viewSetup() {
        contentView.backgroundColor = .white
        
        mapCoverImage = UIImageView {
            $0.image = UserDataModel.shared.userInfo.profilePic
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            contentView.addSubview($0)
        }
        mapCoverImage.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.equalToSuperview().offset(15)
            $0.width.height.equalTo(84)
        }
        mapCoverImage.layer.cornerRadius = 19
        
        mapName = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = UIImage(named: "SecretMap")
            imageAttachment.bounds = CGRect(x: 0, y: 0, width: imageAttachment.image!.size.width, height: imageAttachment.image!.size.height)
            let attachmentString = NSAttributedString(attachment: imageAttachment)
            let completeText = NSMutableAttributedString(string: "")
            completeText.append(attachmentString)
            completeText.append(NSAttributedString(string: " "))
            completeText.append(NSAttributedString(string: "Arnold"))
            $0.attributedText = completeText
            $0.adjustsFontSizeToFitWidth = true
            contentView.addSubview($0)
        }
        mapName.snp.makeConstraints {
            $0.leading.equalTo(mapCoverImage.snp.trailing).offset(12)
            $0.top.equalTo(mapCoverImage).offset(4)
            $0.height.equalTo(23)
            $0.trailing.equalToSuperview().inset(14)
        }
        
        mapCreaterProfileImage1 = UIImageView {
            $0.image = UserDataModel.shared.userInfo.profilePic
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.layer.borderWidth = 1.5
            $0.layer.borderColor = UIColor.white.cgColor
            contentView.addSubview($0)
        }
        mapCreaterProfileImage1.snp.makeConstraints {
            $0.top.equalTo(mapName.snp.bottom).offset(7)
            $0.leading.equalTo(mapName)
            $0.width.height.equalTo(22)
        }
        mapCreaterProfileImage1.layer.cornerRadius = 11
        
        mapCreaterProfileImage2 = UIImageView {
            $0.image = UserDataModel.shared.userInfo.profilePic
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.layer.borderWidth = 1.5
            $0.layer.borderColor = UIColor.white.cgColor
            contentView.insertSubview($0, belowSubview: mapCreaterProfileImage1)
        }
        mapCreaterProfileImage2.snp.makeConstraints {
            $0.top.equalTo(mapCreaterProfileImage1)
            $0.leading.equalTo(mapCreaterProfileImage1).offset(15)
            $0.width.height.equalTo(22)
        }
        mapCreaterProfileImage2.layer.cornerRadius = 11
        
        mapCreaterProfileImage3 = UIImageView {
            $0.image = UserDataModel.shared.userInfo.profilePic
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.layer.borderWidth = 1.5
            $0.layer.borderColor = UIColor.white.cgColor
            contentView.insertSubview($0, belowSubview: mapCreaterProfileImage2)
        }
        mapCreaterProfileImage3.snp.makeConstraints {
            $0.top.equalTo(mapCreaterProfileImage1)
            $0.leading.equalTo(mapCreaterProfileImage2).offset(15)
            $0.width.height.equalTo(22)
        }
        mapCreaterProfileImage3.layer.cornerRadius = 11
        
        mapCreaterProfileImage4 = UIImageView {
            $0.image = UserDataModel.shared.userInfo.profilePic
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.layer.borderWidth = 1.5
            $0.layer.borderColor = UIColor.white.cgColor
            contentView.insertSubview($0, belowSubview: mapCreaterProfileImage3)
        }
        mapCreaterProfileImage4.snp.makeConstraints {
            $0.top.equalTo(mapCreaterProfileImage1)
            $0.leading.equalTo(mapCreaterProfileImage3).offset(15)
            $0.width.height.equalTo(22)
        }
        mapCreaterProfileImage4.layer.cornerRadius = 11
        
        mapCreaterCount = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
            $0.text = "arnold"
            $0.adjustsFontSizeToFitWidth = true
            contentView.addSubview($0)
        }
        mapCreaterCount.snp.makeConstraints {
            $0.leading.equalTo(mapCreaterProfileImage4.snp.trailing).offset(4)
            $0.centerY.equalTo(mapCreaterProfileImage1)
            $0.trailing.lessThanOrEqualToSuperview().inset(14)
        }
        
        mapInfo = UILabel {
            $0.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
            $0.text = "Arnold"
            $0.adjustsFontSizeToFitWidth = true
            contentView.addSubview($0)
        }
        mapInfo.snp.makeConstraints {
            $0.leading.equalTo(mapName)
            $0.top.equalTo(mapCreaterProfileImage1.snp.bottom).offset(8)
            $0.trailing.lessThanOrEqualToSuperview().inset(14)
        }

        actionButton = UIButton {
            $0.setTitle("Edit map", for: .normal)
            $0.setTitleColor(.black, for: .normal)
            $0.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
            contentView.addSubview($0)
        }
        actionButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(14)
            $0.height.equalTo(37)
            $0.top.equalTo(mapCoverImage.snp.bottom).offset(15)
        }
        actionButton.layer.cornerRadius = 37 / 2
        
        mapBio = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Medium", size: 14.5)
            $0.text = "Arnold"
            $0.adjustsFontSizeToFitWidth = true
            contentView.addSubview($0)
        }
        mapBio.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(15)
            $0.top.equalTo(actionButton.snp.bottom).offset(16)
        }
    }
    
    @objc func actionButtonAction() {
        switch relation {
        case .myself:
            // Action is set in ProfileViewController
            Mixpanel.mainInstance().track(event: "EditButtonAction")
        case .friend:
            // No Action
            Mixpanel.mainInstance().track(event: "ProfileFriendButton")
            return
        case .pending, .received:
            if pendingFriendNotiID != nil {

                if relation == .pending {
                    Mixpanel.mainInstance().track(event: "ProfilePendingButton")
                    let alert = UIAlertController(title: "Remove friend request?", message: "", preferredStyle: .alert)
                    let removeAction = UIAlertAction(title: "Remove", style: .default) { action in
                        self.removeFriendRequest(friendID: self.profile.id!, notificationID: self.pendingFriendNotiID!)
                    }
                    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
                    alert.addAction(cancelAction)
                    alert.addAction(removeAction)
                    let containerVC = UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.rootViewController ?? UIViewController()
                    containerVC.present(alert, animated: true)
                } else {
                    Mixpanel.mainInstance().track(event: "ProfileAcceptButton")
                    getNotiIDAndAcceptFriendRequest()
                }
                actionButton.setImage(UIImage(named: "FriendsIcon"), for: .normal)
                actionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
                actionButton.setTitle("Friends", for: .normal)
                actionButton.setTitleColor(.black, for: .normal)
                actionButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            }
        case .stranger:
            Mixpanel.mainInstance().track(event: "ProfileAddFriendButton")
            addFriend(senderProfile: UserDataModel.shared.userInfo, receiverID: profile.id!)
            actionButton.setImage(UIImage(named: "FriendsPendingIcon"), for: .normal)
            actionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
            actionButton.setTitle("Pending", for: .normal)
            actionButton.setTitleColor(.black, for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
        case .none:
            return
        }
        UIView.animate(withDuration: 0.15) {
            self.actionButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { (Bool) in
            UIView.animate(withDuration: 0.15) {
                self.actionButton.transform = .identity
            }
        }
    }
    
    @objc func locationButtonAction() {
        Mixpanel.mainInstance().track(event: "LocationButtonAction")
    }
    
    private func getNotiIDAndAcceptFriendRequest() {
        let db = Firestore.firestore()
        let query = db.collection("users").document(UserDataModel.shared.userInfo.id!).collection("notifications").whereField("type", isEqualTo: "friendRequest").whereField("status", isEqualTo: "pending")
        query.getDocuments { (snap, err) in
            if err != nil  { return }
            for doc in snap!.documents {
                do {
                    let unwrappedInfo = try doc.data(as: UserNotification.self)
                    guard let notification = unwrappedInfo else { return }
                    if notification.senderID == self.profile!.id {
                        self.pendingFriendNotiID = notification.id
                        self.acceptFriendRequest(friendID: self.profile.id!, notificationID: self.pendingFriendNotiID!)
                        let notiID:[String: String?] = ["notiID": self.pendingFriendNotiID]
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "AcceptedFriendRequest"), object: nil, userInfo: notiID as [AnyHashable : Any])
                        break
                    }
                } catch let parseError {
                    print("JSON Error \(parseError.localizedDescription)")
                }
            }
        }
    }
}

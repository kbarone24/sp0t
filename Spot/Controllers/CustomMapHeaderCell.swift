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
import FirebaseUI

class CustomMapHeaderCell: UICollectionViewCell {
    private var mapCoverImage: UIImageView!
    private var mapName: UILabel!
    private var mapCreatorProfileImage1: UIImageView!
    private var mapCreatorProfileImage2: UIImageView!
    private var mapCreatorProfileImage3: UIImageView!
    private var mapCreatorProfileImage4: UIImageView!
    private var userButton: UIButton!
    private var mapCreatorCount: UILabel!
    private var mapInfo: UILabel!
    public var actionButton: UIButton!
    private var mapBio: UILabel!
    
    private var mapData: CustomMap!
    private var fourMapMemberProfile: [UserProfile] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        mapCoverImage.sd_cancelCurrentImageLoad()
        mapCreatorProfileImage1.sd_cancelCurrentImageLoad()
        mapCreatorProfileImage2.sd_cancelCurrentImageLoad()
        mapCreatorProfileImage3.sd_cancelCurrentImageLoad()
        mapCreatorProfileImage4.sd_cancelCurrentImageLoad()
    }
    
    public func cellSetup(mapData: CustomMap?, fourMapMemberProfile: [UserProfile]) {
        guard mapData != nil else { return }
        self.mapData = mapData
        self.fourMapMemberProfile = fourMapMemberProfile
        
        setMapName()
        setMapInfo()
        setMapMemberInfo()
        setActionButton()
        
        if mapData!.mapDescription != nil || mapData!.mapDescription != "" {
            mapBio.text = mapData!.mapDescription
        }
    }
}

extension CustomMapHeaderCell {
    private func viewSetup() {
        contentView.backgroundColor = .white
        
        mapCoverImage = UIImageView {
            $0.image = UIImage()
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            contentView.addSubview($0)
        }
        mapCoverImage.snp.makeConstraints {
            $0.top.equalToSuperview().offset(-10)
            $0.leading.equalTo(15)
            $0.width.height.equalTo(84)
        }
        mapCoverImage.layer.cornerRadius = 19
        
        mapName = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
            $0.adjustsFontSizeToFitWidth = true
            $0.text = ""
            contentView.addSubview($0)
        }
        mapName.snp.makeConstraints {
            $0.leading.equalTo(mapCoverImage.snp.trailing).offset(12)
            $0.top.equalTo(mapCoverImage).offset(4)
            $0.trailing.equalToSuperview().inset(14)
        }
        
        mapCreatorProfileImage1 = UIImageView {
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.layer.borderWidth = 1.5
            $0.layer.cornerRadius = 11
            $0.layer.borderColor = UIColor.white.cgColor
            contentView.addSubview($0)
        }
        mapCreatorProfileImage1.snp.makeConstraints {
            $0.top.equalTo(mapName.snp.bottom).offset(7)
            $0.leading.equalTo(mapName)
            $0.width.height.equalTo(22)
        }
        
        mapCreatorProfileImage2 = UIImageView {
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.layer.borderWidth = 1.5
            $0.layer.cornerRadius = 11
            $0.layer.borderColor = UIColor.white.cgColor
            contentView.insertSubview($0, belowSubview: mapCreatorProfileImage1)
        }
        mapCreatorProfileImage2.snp.makeConstraints {
            $0.top.equalTo(mapCreatorProfileImage1)
            $0.leading.equalTo(mapCreatorProfileImage1).offset(15)
            $0.width.height.equalTo(22)
        }
        
        mapCreatorProfileImage3 = UIImageView {
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.layer.borderWidth = 1.5
            $0.layer.cornerRadius = 11
            $0.layer.borderColor = UIColor.white.cgColor
            contentView.insertSubview($0, belowSubview: mapCreatorProfileImage2)
        }
        mapCreatorProfileImage3.snp.makeConstraints {
            $0.top.equalTo(mapCreatorProfileImage1)
            $0.leading.equalTo(mapCreatorProfileImage2).offset(15)
            $0.width.height.equalTo(22)
        }
        
        mapCreatorProfileImage4 = UIImageView {
            $0.image = UIImage()
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.layer.borderWidth = 1.5
            $0.layer.cornerRadius = 11
            $0.layer.borderColor = UIColor.white.cgColor
            contentView.insertSubview($0, belowSubview: mapCreatorProfileImage3)
        }
        mapCreatorProfileImage4.snp.makeConstraints {
            $0.top.equalTo(mapCreatorProfileImage1)
            $0.leading.equalTo(mapCreatorProfileImage3).offset(15)
            $0.width.height.equalTo(22)
        }
        
        mapCreatorCount = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
            $0.text = ""
            $0.adjustsFontSizeToFitWidth = true
            contentView.addSubview($0)
        }
         
        mapInfo = UILabel {
            $0.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
            $0.text = ""
            $0.adjustsFontSizeToFitWidth = true
            contentView.addSubview($0)
        }
        mapInfo.snp.makeConstraints {
            $0.leading.equalTo(mapName)
            $0.top.equalTo(mapCreatorProfileImage1.snp.bottom).offset(8)
            $0.trailing.lessThanOrEqualToSuperview().inset(14)
        }
        
        actionButton = UIButton {
            $0.setTitle("Follow map", for: .normal)
            $0.setTitleColor(.black, for: .normal)
            $0.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
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
            $0.text = ""
            $0.adjustsFontSizeToFitWidth = true
            contentView.addSubview($0)
        }
        mapBio.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(15)
            $0.top.equalTo(actionButton.snp.bottom).offset(16)
        }
        
        userButton = UIButton {
            $0.addTarget(self, action: #selector(userTap), for: .touchUpInside)
            contentView.addSubview($0)
        }
    }
    
    private func setMapName() {
        if mapData!.secret {
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = UIImage(named: "SecretMap")
            imageAttachment.bounds = CGRect(x: 0, y: 0, width: imageAttachment.image!.size.width, height: imageAttachment.image!.size.height)
            let attachmentString = NSAttributedString(attachment: imageAttachment)
            let completeText = NSMutableAttributedString(string: "")
            completeText.append(attachmentString)
            completeText.append(NSAttributedString(string: " "))
            completeText.append(NSAttributedString(string: mapData!.mapName))
            mapName.attributedText = completeText
        } else {
            mapName.text = mapData!.mapName
        }
        let transformer = SDImageResizingTransformer(size: CGSize(width: 150, height: 150), scaleMode: .aspectFill)
        mapCoverImage.sd_setImage(with: URL(string: mapData!.imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
    }
    
    private func setMapInfo() {
        mapInfo.text = mapData!.spotIDs.count > 1 ? "\(mapData!.spotIDs.count) spots" : mapData!.spotIDs.count > 0 ? "\(mapData!.spotIDs.count) spot" : ""
    }
    
    private func setMapMemberInfo() {
        guard fourMapMemberProfile.count != 0 else { return }
        
        let communityMap = mapData.communityMap ?? false
        mapCreatorCount.text = communityMap ? "+ \(mapData.memberIDs.count - 4)" : "\(fourMapMemberProfile[0].username) + \(mapData.memberIDs.count - 1)"
        
        let userTransformer = SDImageResizingTransformer(size: CGSize(width: 50, height: 50), scaleMode: .aspectFill)
        mapCreatorProfileImage1.sd_setImage(with: URL(string: fourMapMemberProfile[0].imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
        
        switch fourMapMemberProfile.count {
        case 1:
            if !communityMap { mapCreatorCount.text = "\(fourMapMemberProfile[0].username)" }
        case 2:
            if !communityMap { mapCreatorCount.text = "\(fourMapMemberProfile[0].username) & \(fourMapMemberProfile[1].username)" }
            mapCreatorProfileImage2.sd_setImage(with: URL(string: fourMapMemberProfile[1].imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
        case 3:
            mapCreatorProfileImage2.sd_setImage(with: URL(string: fourMapMemberProfile[1].imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
            mapCreatorProfileImage3.sd_setImage(with: URL(string: fourMapMemberProfile[2].imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
        case 4:
            mapCreatorProfileImage2.sd_setImage(with: URL(string: fourMapMemberProfile[1].imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
            mapCreatorProfileImage3.sd_setImage(with: URL(string: fourMapMemberProfile[2].imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
            mapCreatorProfileImage4.sd_setImage(with: URL(string: fourMapMemberProfile[3].imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
        default:
            return
        }
        makeMapNameConstraints()
    }
    
    private func makeMapNameConstraints() {
        mapCreatorCount.snp.removeConstraints()
        userButton.snp.removeConstraints()

        mapCreatorProfileImage2.isHidden = fourMapMemberProfile.count < 2
        mapCreatorProfileImage3.isHidden = fourMapMemberProfile.count < 3
        mapCreatorProfileImage4.isHidden = fourMapMemberProfile.count < 4
        
        mapCreatorCount.snp.makeConstraints {
            $0.centerY.equalTo(mapCreatorProfileImage1)
            $0.trailing.lessThanOrEqualToSuperview().inset(14)
            switch fourMapMemberProfile.count {
            case 1: $0.leading.equalTo(mapCreatorProfileImage1.snp.trailing).offset(4)
            case 2: $0.leading.equalTo(mapCreatorProfileImage2.snp.trailing).offset(4)
            case 3: $0.leading.equalTo(mapCreatorProfileImage3.snp.trailing).offset(4)
            case 4: $0.leading.equalTo(mapCreatorProfileImage4.snp.trailing).offset(4)
            default: return
            }
        }
        userButton.snp.makeConstraints {
            $0.leading.equalTo(mapCoverImage.snp.trailing).offset(5)
            $0.top.equalTo(mapName.snp.bottom).offset(4)
            $0.height.equalTo(28)
            $0.trailing.equalTo(mapCreatorCount.snp.trailing)
        }
    }
    
    private func setActionButton() {
        if mapData!.communityMap ?? false {
            if mapData!.memberIDs.contains(UserDataModel.shared.uid) {
                actionButton.setTitle("Joined", for: .normal)
                actionButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            } else {
                actionButton.setTitle("Join", for: .normal)
                actionButton.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            }
        } else if mapData!.memberIDs.contains(UserDataModel.shared.uid) {
            actionButton.setTitle("Edit map", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
        } else if mapData!.likers.contains(UserDataModel.shared.uid) {
            actionButton.setTitle("Following", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
        } else if !mapData!.secret {
            actionButton.setTitle("Follow map", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
        }

        actionButton.addTarget(self, action: #selector(actionButtonAction), for: .touchUpInside)
    }
    
    @objc func actionButtonAction() {
        UIView.animate(withDuration: 0.15) {
            self.actionButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { (Bool) in
            UIView.animate(withDuration: 0.15) {
                self.actionButton.transform = .identity
            }
        }
        
        let db = Firestore.firestore()
        switch actionButton.titleLabel?.text {
        case "Follow map", "Join" :
            Mixpanel.mainInstance().track(event: "CustomMapFollowMap")
            mapData.likers.append(UserDataModel.shared.uid)
            UserDataModel.shared.userInfo.mapsList.append(mapData!)
            setMapInfo()
            
            let userInfo = ["mapLikers": self.mapData.likers, "mapID": self.mapData.id!] as [String : Any]
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MapLikersChanged"), object: nil, userInfo: userInfo)
            
            var values: [String: Any] = ["likers": FieldValue.arrayUnion([UserDataModel.shared.uid])]
            if mapData.communityMap ?? false { values["memberIDs"] = FieldValue.arrayUnion([UserDataModel.shared.uid]) }
            db.collection("maps").document(mapData.id!).updateData(values)
            
            let title = mapData.communityMap ?? false ? "Joined" : "Following"
            self.actionButton.setTitle(title, for: .normal)
            self.actionButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
        case "Following":
            let alert = UIAlertController(title: "Are you sure you want to unfollow?", message: "", preferredStyle: .alert)
            alert.overrideUserInterfaceStyle = .light
            let unfollowAction = UIAlertAction(title: "Unfollow", style: .default) { action in
                Mixpanel.mainInstance().track(event: "CustomMapUnfollow")
                guard let userIndex = self.mapData.likers.firstIndex(of: UserDataModel.shared.uid) else { return }
                self.mapData.likers.remove(at: userIndex)
                UserDataModel.shared.userInfo.mapsList.removeAll(where: {$0.id == self.mapData!.id!})
                self.setMapInfo()

                let userInfo = ["mapLikers": self.mapData.likers, "mapID": self.mapData.id!] as [String : Any]
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "MapLikersChanged"), object: nil, userInfo: userInfo)
                
                var values: [String: Any] = ["likers": FieldValue.arrayRemove([UserDataModel.shared.uid])]
                if self.mapData.communityMap ?? false { values["memberIDs"] = FieldValue.arrayRemove([UserDataModel.shared.uid]) }
                db.collection("maps").document(self.mapData.id!).updateData(values)

                self.actionButton.setTitle("Follow map", for: .normal)
                self.actionButton.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
            alert.addAction(unfollowAction)
            alert.addAction(cancelAction)
            let containerVC = UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.rootViewController ?? UIViewController()
            containerVC.present(alert, animated: true)
        default:
            return
        }
    }
    
    @objc func userTap() {
        Mixpanel.mainInstance().track(event: "CustomMapMembersTap")
        guard let customMapVC = viewContainingController() as? CustomMapController else { return }
        let friendListVC = FriendsListController(fromVC: customMapVC, allowsSelection: false, showsSearchBar: false, friendIDs: mapData.memberIDs, friendsList: [], confirmedIDs: [], sentFrom: .CustomMap, presentedWithDrawerView: customMapVC.containerDrawerView!)
        customMapVC.present(friendListVC, animated: true)
    }
}


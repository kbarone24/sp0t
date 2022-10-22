//
//  CustomMapHeaderCell.swift
//  Spot
//
//  Created by Arnold on 7/24/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseUI
import Mixpanel
import SnapKit
import UIKit

class CustomMapHeaderCell: UICollectionViewCell {
    private var mapCoverImage: UIImageView!
    private var mapName: UILabel!
    private var joinedIcon: UIImageView!
    private var mapCreatorProfileImage1: UIImageView!
    private var mapCreatorProfileImage2: UIImageView!
    private var mapCreatorProfileImage3: UIImageView!
    private var mapCreatorProfileImage4: UIImageView!
    private var userButton: UIButton!
    private var mapCreatorCount: UILabel!
    private var mapInfo: UILabel!

    public var actionButton: UIButton!
    private var editButton: UIButton!
    private var addFriendsButton: UIButton!
    private var mapBio: UILabel!

    var mapData: CustomMap!
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
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 22)
            $0.text = ""
            $0.numberOfLines = 2
            $0.adjustsFontSizeToFitWidth = true
         //   $0.lineBreakMode = .byWordWrapping
            contentView.addSubview($0)
        }
        mapName.snp.makeConstraints {
            $0.leading.equalTo(mapCoverImage.snp.trailing).offset(12)
            $0.top.equalTo(mapCoverImage).offset(4)
            $0.trailing.equalToSuperview().inset(14)
        }
        /// show when >7 users at a map
        joinedIcon = UIImageView {
            $0.image = UIImage(named: "FriendsIcon")
            $0.isHidden = true
            contentView.addSubview($0)
        }
        joinedIcon.snp.makeConstraints {
            $0.leading.equalTo(mapName)
            $0.top.equalTo(mapName.snp.bottom).offset(7)
            $0.width.equalTo(18.66)
            $0.height.equalTo(14)
        }

        mapCreatorProfileImage1 = UIImageView {
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.layer.borderWidth = 2
            $0.layer.cornerRadius = 34 / 2
            $0.layer.borderColor = UIColor.white.cgColor
            contentView.addSubview($0)
        }
        mapCreatorProfileImage1.snp.makeConstraints {
            $0.top.equalTo(mapName.snp.bottom).offset(7)
            $0.leading.equalTo(mapName)
            $0.width.height.equalTo(34)
        }

        mapCreatorProfileImage2 = UIImageView {
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.layer.borderWidth = 2
            $0.layer.cornerRadius = 34 / 2
            $0.layer.borderColor = UIColor.white.cgColor
            contentView.insertSubview($0, belowSubview: mapCreatorProfileImage1)
        }
        mapCreatorProfileImage2.snp.makeConstraints {
            $0.top.equalTo(mapCreatorProfileImage1)
            $0.leading.equalTo(mapCreatorProfileImage1).offset(22)
            $0.width.height.equalTo(34)
        }

        mapCreatorProfileImage3 = UIImageView {
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.layer.borderWidth = 2
            $0.layer.cornerRadius = 34 / 2
            $0.layer.borderColor = UIColor.white.cgColor
            contentView.insertSubview($0, belowSubview: mapCreatorProfileImage2)
        }
        mapCreatorProfileImage3.snp.makeConstraints {
            $0.top.equalTo(mapCreatorProfileImage1)
            $0.leading.equalTo(mapCreatorProfileImage2).offset(22)
            $0.width.height.equalTo(34)
        }

        mapCreatorProfileImage4 = UIImageView {
            $0.image = UIImage()
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.layer.borderWidth = 2
            $0.layer.cornerRadius = 34 / 2
            $0.layer.borderColor = UIColor.white.cgColor
            contentView.insertSubview($0, belowSubview: mapCreatorProfileImage3)
        }
        mapCreatorProfileImage4.snp.makeConstraints {
            $0.top.equalTo(mapCreatorProfileImage1)
            $0.leading.equalTo(mapCreatorProfileImage3).offset(22)
            $0.width.height.equalTo(34)
        }

        mapCreatorCount = UILabel {
            $0.textColor = UIColor(red: 0.292, green: 0.292, blue: 0.292, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
            $0.text = ""
            $0.adjustsFontSizeToFitWidth = true
            contentView.addSubview($0)
        }

        actionButton = UIButton {
            $0.setTitle("Follow map", for: .normal)
            $0.setTitleColor(.black, for: .normal)
            $0.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
            $0.layer.cornerRadius = 37 / 2
            $0.isHidden = true
            $0.addTarget(self, action: #selector(actionButtonAction), for: .touchUpInside)
            contentView.addSubview($0)
        }
        actionButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(14)
            $0.height.equalTo(37)
            $0.bottom.equalToSuperview().inset(12)
        }

        editButton = UIButton {
            $0.setTitle("Edit Map", for: .normal)
            $0.setTitleColor(.black, for: .normal)
            $0.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
            $0.layer.cornerRadius = 18
            $0.isHidden = true
            $0.addTarget(self, action: #selector(editTap), for: .touchUpInside)
            contentView.addSubview($0)
        }
        let spacing: CGFloat = 18 + 14 + 6
        editButton.snp.makeConstraints {
            $0.leading.bottom.height.equalTo(actionButton)
            $0.width.equalTo((UIScreen.main.bounds.width - spacing) * 0.42)
        }

        addFriendsButton = PillButtonWithImage {
            $0.setUp(image: UIImage(named: "ProfileAddFriendsIcon")!, str: "Add Friends")
            $0.layer.cornerRadius = 18
            $0.isHidden = true
            $0.addTarget(self, action: #selector(addFriendsTap), for: .touchUpInside)
            contentView.addSubview($0)
        }
        addFriendsButton.snp.makeConstraints {
            $0.leading.equalTo(editButton.snp.trailing).offset(6)
            $0.top.height.equalTo(actionButton)
            $0.width.equalTo((UIScreen.main.bounds.width - spacing) * 0.58)
        }

        mapBio = UILabel {
            $0.textColor = UIColor(red: 0.292, green: 0.292, blue: 0.292, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
            $0.text = ""
            $0.numberOfLines = 0
            $0.lineBreakMode = .byWordWrapping
            contentView.addSubview($0)
        }
        mapBio.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(19)
            $0.top.equalTo(mapCoverImage.snp.bottom).offset(12)
        }

        userButton = UIButton {
            $0.addTarget(self, action: #selector(userTap), for: .touchUpInside)
            contentView.addSubview($0)
        }
    }

    private func setMapName() {
        if mapData!.secret {
            mapName.attributedText = getAttributedStringWithImage(str: mapData!.mapName, image: UIImage(named: "SecretMap")!)
        } else {
            mapName.text = mapData!.mapName
            mapName.sizeToFit()
        }
        let transformer = SDImageResizingTransformer(size: CGSize(width: 150, height: 150), scaleMode: .aspectFill)
        mapCoverImage.sd_setImage(with: URL(string: mapData!.imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
    }

    private func setMapMemberInfo() {
        guard fourMapMemberProfile.count != 0 || mapData.memberIDs.count > 7 else { return }
        let communityMap = mapData.communityMap ?? false

        if mapData.memberIDs.count < 7 {
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
                mapCreatorCount.text = communityMap ? "" : "\(fourMapMemberProfile[0].username) + \(mapData.memberIDs.count - 1)"
            case 4:
                mapCreatorProfileImage2.sd_setImage(with: URL(string: fourMapMemberProfile[1].imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
                mapCreatorProfileImage3.sd_setImage(with: URL(string: fourMapMemberProfile[2].imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
                mapCreatorProfileImage4.sd_setImage(with: URL(string: fourMapMemberProfile[3].imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
                mapCreatorCount.text = communityMap ? mapData.memberIDs.count > 4 ? "+ \(mapData.memberIDs.count - 4)" : "" : "\(fourMapMemberProfile[0].username) + \(mapData.memberIDs.count - 1)"
            default:
                return
            }
        } else {
            /// show joined icon if >7 members
            mapCreatorCount.text = "\(mapData.memberIDs.count) joined"
            joinedIcon.isHidden = false
        }
        makeMapNameConstraints()
    }

    private func makeMapNameConstraints() {
        mapCreatorCount.snp.removeConstraints()
        userButton.snp.removeConstraints()
        let joinedShowing = mapData.memberIDs.count > 6

        mapCreatorProfileImage1.isHidden = joinedShowing
        mapCreatorProfileImage2.isHidden = joinedShowing || fourMapMemberProfile.count < 2
        mapCreatorProfileImage3.isHidden = joinedShowing || fourMapMemberProfile.count < 3
        mapCreatorProfileImage4.isHidden = joinedShowing || fourMapMemberProfile.count < 4

        mapCreatorCount.snp.makeConstraints {
            $0.trailing.lessThanOrEqualToSuperview().inset(14)
            if joinedShowing {
                $0.centerY.equalTo(joinedIcon)
                $0.leading.equalTo(joinedIcon.snp.trailing).offset(4)
            } else {
                $0.centerY.equalTo(mapCreatorProfileImage1)
                switch fourMapMemberProfile.count {
                case 1: $0.leading.equalTo(mapCreatorProfileImage1.snp.trailing).offset(3)
                case 2: $0.leading.equalTo(mapCreatorProfileImage2.snp.trailing).offset(3)
                case 3: $0.leading.equalTo(mapCreatorProfileImage3.snp.trailing).offset(3)
                case 4: $0.leading.equalTo(mapCreatorProfileImage4.snp.trailing).offset(3)
                default: return
                }
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
        if mapData!.memberIDs.contains(UserDataModel.shared.uid) {
            /// show 2 button view
            actionButton.isHidden = true
            editButton.isHidden = false
            editButton.tag = 0
            addFriendsButton.isHidden = false
            /// only show edit button if user is founder
            if (mapData!.communityMap ?? false) || UserDataModel.shared.uid != mapData!.founderID {
                editButton.tag = 1
                editButton.setTitle("Joined", for: .normal)
                editButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            }

        } else {
            /// show singular action button
            actionButton.isHidden = false
            editButton.isHidden = true
            addFriendsButton.isHidden = true

            if mapData!.communityMap ?? false {
                actionButton.setTitle("Join", for: .normal)
                actionButton.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            } else if mapData!.likers.contains(UserDataModel.shared.uid) {
                actionButton.setTitle("Following", for: .normal)
                actionButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            } else if !mapData!.secret {
                actionButton.setTitle("Follow map", for: .normal)
                actionButton.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            }
        }
    }

    @objc func editTap() {
        if editButton.tag == 0 {
            guard let vc = viewContainingController() as? CustomMapController else { return }
            vc.setDrawerValuesForViewAppear()
            let editVC = EditMapController(mapData: mapData!)
            editVC.customMapVC = vc
            editVC.modalPresentationStyle = .fullScreen
            vc.present(editVC, animated: true)
        } else {
            addActionSheet()
        }
    }

    @objc func addFriendsTap() {
        guard let vc = viewContainingController() as? CustomMapController else { return }
        let friendsList = UserDataModel.shared.userInfo.getSelectedFriends(memberIDs: self.mapData!.memberIDs)
        let friendsVC = FriendsListController(fromVC: nil, allowsSelection: true, showsSearchBar: true, friendIDs: UserDataModel.shared.userInfo.friendIDs, friendsList: friendsList, confirmedIDs: self.mapData!.memberIDs, sentFrom: .EditMap)
        friendsVC.delegate = self
        friendsVC.sentFrom = .EditMap
        vc.present(friendsVC, animated: true)
    }

    @objc func actionButtonAction() {
        switch actionButton.titleLabel?.text {
        case "Follow map", "Join":
            /// prompt user to enter email if heels map
            let heelsMapID = "9ECABEF9-0036-4082-A06A-C8943428FFF4"
            if mapData!.id == heelsMapID {
                presentHeelsMap()
            } else {
                followMap()
            }

        case "Following", "Joined":
            addActionSheet()

        default:
            return
        }
    }

    func followMap() {
        Mixpanel.mainInstance().track(event: "CustomMapFollowMap")
        mapData.likers.append(UserDataModel.shared.uid)
        if mapData?.communityMap ?? false {
            mapData.memberIDs.append(UserDataModel.shared.uid)
        }

        UserDataModel.shared.userInfo.mapsList.append(mapData!)
        addNewUsersInDB()
    }

    @objc func userTap() {
        Mixpanel.mainInstance().track(event: "CustomMapMembersTap")
        guard let customMapVC = viewContainingController() as? CustomMapController else { return }
        let friendListVC = FriendsListController(fromVC: customMapVC, allowsSelection: false, showsSearchBar: false, friendIDs: mapData.memberIDs, friendsList: [], confirmedIDs: [], sentFrom: .CustomMap, presentedWithDrawerView: customMapVC.containerDrawerView!)
        customMapVC.present(friendListVC, animated: true)
    }

    func presentHeelsMap() {
        guard let customMapVC = viewContainingController() as? CustomMapController else { return }
        let vc = HeelsMapPopUpController()
        vc.delegate = self
        DispatchQueue.main.async { customMapVC.present(vc, animated: true) }
    }

    func addNewUsersInDB() {
        let db = Firestore.firestore()
        let mapsRef = db.collection("maps").document(mapData!.id!)
        mapsRef.updateData(["likers": FieldValue.arrayUnion(mapData!.likers), "memberIDs": FieldValue.arrayUnion(mapData!.memberIDs), "updateUserID": UserDataModel.shared.uid])
        sendEditNotification()
    }

    func sendEditNotification() {
        if mapData!.secret { self.updatePostInviteLists(mapID: mapData!.id!, inviteList: mapData!.memberIDs) }
        NotificationCenter.default.post(Notification(name: Notification.Name("EditMap"), object: nil, userInfo: ["map": mapData as Any]))
    }
}

extension CustomMapHeaderCell: MapCodeDelegate, FriendsListDelegate {
    func finishPassing(selectedUsers: [UserProfile]) {
        Mixpanel.mainInstance().track(event: "CustomMapInviteFriendsComplete")
        for user in selectedUsers {
            if !mapData!.memberIDs.contains(where: { $0 == user.id! }) {
                mapData!.memberIDs.append(user.id!)
            }
            if !mapData!.likers.contains(where: { $0 == user.id }) { mapData!.likers.append(user.id!) }
        }
        addNewUsersInDB()
    }

    func finishPassing(newMapID: String) {
        followMap()
    }
}

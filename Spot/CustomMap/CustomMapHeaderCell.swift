//
//  CustomMapHeaderCell.swift
//  Spot
//
//  Created by Arnold on 7/24/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import Mixpanel
import SnapKit
import UIKit
import SDWebImage

final class CustomMapHeaderCell: UICollectionViewCell {
    var mapData: CustomMap?
    private var memberProfiles: [UserProfile] = []

    private lazy var mapCoverImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 19
        imageView.layer.masksToBounds = true
        return imageView
    }()

    private lazy var mapName: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Heavy", size: 22)
        label.text = ""
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        return label
    }()

    private lazy var joinedIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "FriendsIcon")
        imageView.isHidden = true
        return imageView
    }()
    
    lazy var mapPostService: MapPostServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.mapPostService)
        return service
    }()

    private lazy var mapCreatorProfileImage1 = MapCreatorProfileImage(frame: .zero)
    private lazy var mapCreatorProfileImage2 = MapCreatorProfileImage(frame: .zero)
    private lazy var mapCreatorProfileImage3 = MapCreatorProfileImage(frame: .zero)
    private lazy var mapCreatorProfileImage4 = MapCreatorProfileImage(frame: .zero)

    private lazy var mapCreatorCount: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.292, green: 0.292, blue: 0.292, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
        label.text = ""
        label.adjustsFontSizeToFitWidth = true
        return label
    }()

    private lazy var userButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(userTap), for: .touchUpInside)
        return button
    }()

    lazy var actionButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
        button.layer.cornerRadius = 37 / 2
        button.isHidden = true
        button.addTarget(self, action: #selector(actionButtonAction), for: .touchUpInside)
        return button
    }()

    private lazy var addFriendsButton: UIButton = {
        let button = PillButtonWithImage()
        button.setUp(image: UIImage(named: "ProfileAddFriendsIcon") ?? UIImage(), str: "Add Friends", cornerRadius: 18)
        button.isHidden = true
        button.addTarget(self, action: #selector(addFriendsTap), for: .touchUpInside)
        return button
    }()

    private lazy var editButton: UIButton = {
        let button = UIButton()
        button.setTitle("Edit Map", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
        button.layer.cornerRadius = 18
        button.isHidden = true
        button.addTarget(self, action: #selector(editTap), for: .touchUpInside)
        return button
    }()

    private lazy var mapBio: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.292, green: 0.292, blue: 0.292, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
        label.text = ""
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        mapCoverImage.sd_cancelCurrentImageLoad()
        mapCreatorProfileImage1.sd_cancelCurrentImageLoad()
        mapCreatorProfileImage2.sd_cancelCurrentImageLoad()
        mapCreatorProfileImage3.sd_cancelCurrentImageLoad()
        mapCreatorProfileImage4.sd_cancelCurrentImageLoad()
    }

    public func cellSetup(mapData: CustomMap?, memberProfiles: [UserProfile]) {
        guard mapData != nil else { return }
        self.mapData = mapData
        self.memberProfiles = memberProfiles

        setMapName()
        setMapMemberInfo()
        setActionButton()

        mapBio.text = mapData?.mapDescription ?? ""
    }
}

extension CustomMapHeaderCell {
    private func viewSetup() {
        contentView.backgroundColor = .white

        contentView.addSubview(mapCoverImage)
        mapCoverImage.snp.makeConstraints {
            $0.top.equalToSuperview().offset(-10)
            $0.leading.equalTo(15)
            $0.width.height.equalTo(84)
        }

        contentView.addSubview(mapName)
        mapName.snp.makeConstraints {
            $0.leading.equalTo(mapCoverImage.snp.trailing).offset(12)
            $0.top.equalTo(mapCoverImage).offset(4)
            $0.trailing.equalToSuperview().inset(14)
        }

        // show when >7 users at a map
        contentView.addSubview(joinedIcon)
        joinedIcon.snp.makeConstraints {
            $0.leading.equalTo(mapName)
            $0.top.equalTo(mapName.snp.bottom).offset(7)
            $0.width.equalTo(18.66)
            $0.height.equalTo(14)
        }

        contentView.addSubview(mapCreatorProfileImage1)
        mapCreatorProfileImage1.snp.makeConstraints {
            $0.top.equalTo(mapName.snp.bottom).offset(7)
            $0.leading.equalTo(mapName)
            $0.width.height.equalTo(34)
        }

        contentView.addSubview(mapCreatorProfileImage2)
        mapCreatorProfileImage2.snp.makeConstraints {
            $0.top.equalTo(mapCreatorProfileImage1)
            $0.leading.equalTo(mapCreatorProfileImage1).offset(22)
            $0.width.height.equalTo(34)
        }

        contentView.addSubview(mapCreatorProfileImage3)
        mapCreatorProfileImage3.snp.makeConstraints {
            $0.top.equalTo(mapCreatorProfileImage1)
            $0.leading.equalTo(mapCreatorProfileImage2).offset(22)
            $0.width.height.equalTo(34)
        }

        contentView.addSubview(mapCreatorProfileImage4)
        mapCreatorProfileImage4.snp.makeConstraints {
            $0.top.equalTo(mapCreatorProfileImage1)
            $0.leading.equalTo(mapCreatorProfileImage3).offset(22)
            $0.width.height.equalTo(34)
        }

        contentView.addSubview(mapCreatorCount)

        contentView.addSubview(actionButton)
        actionButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(14)
            $0.height.equalTo(37)
            $0.bottom.equalToSuperview().inset(12)
        }

        contentView.addSubview(editButton)
        let spacing: CGFloat = 18 + 14 + 6
        editButton.snp.makeConstraints {
            $0.leading.bottom.height.equalTo(actionButton)
            $0.width.equalTo((UIScreen.main.bounds.width - spacing) * 0.42)
        }

        contentView.addSubview(addFriendsButton)
        addFriendsButton.snp.makeConstraints {
            $0.leading.equalTo(editButton.snp.trailing).offset(6)
            $0.top.height.equalTo(actionButton)
            $0.width.equalTo((UIScreen.main.bounds.width - spacing) * 0.58)
        }

        contentView.addSubview(mapBio)
        mapBio.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(19)
            $0.top.equalTo(mapCoverImage.snp.bottom).offset(12)
        }

        contentView.addSubview(userButton)
    }

    private func setMapName() {
        guard let mapData = mapData else { return }
        if mapData.secret {
            let str = mapData.mapName
            mapName.attributedText = str.getAttributedStringWithImage(image: UIImage(named: "SecretMap") ?? UIImage())
        } else {
            mapName.text = mapData.mapName
            mapName.sizeToFit()
        }
        let transformer = SDImageResizingTransformer(size: CGSize(width: 150, height: 150), scaleMode: .aspectFill)
        mapCoverImage.sd_setImage(with: URL(string: mapData.imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
    }

    private func setMapMemberInfo() {
        guard let mapData = mapData else { return }
        let communityMap = mapData.communityMap ?? false

        if mapData.memberIDs.count < 7 && !communityMap {
            if memberProfiles.isEmpty { return }
            let userTransformer = SDImageResizingTransformer(size: CGSize(width: 50, height: 50), scaleMode: .aspectFill)
            mapCreatorProfileImage1.sd_setImage(with: URL(string: memberProfiles[0].imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])

            switch memberProfiles.count {
            case 1:
                mapCreatorCount.text = "\(memberProfiles[0].username)"
            case 2:
                mapCreatorCount.text = "\(memberProfiles[0].username) & \(memberProfiles[1].username)"
                mapCreatorProfileImage2.sd_setImage(with: URL(string: memberProfiles[1].imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
            case 3:
                mapCreatorProfileImage2.sd_setImage(with: URL(string: memberProfiles[1].imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
                mapCreatorProfileImage3.sd_setImage(with: URL(string: memberProfiles[2].imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
                mapCreatorCount.text = "\(memberProfiles[0].username) + \(mapData.memberIDs.count - 1)"
            case 4:
                mapCreatorProfileImage2.sd_setImage(with: URL(string: memberProfiles[1].imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
                mapCreatorProfileImage3.sd_setImage(with: URL(string: memberProfiles[2].imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
                mapCreatorProfileImage4.sd_setImage(with: URL(string: memberProfiles[3].imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])

                mapCreatorCount.text = "\(memberProfiles[0].username) + \(mapData.memberIDs.count - 1)"
            default:
                return
            }
        } else {
            // show joined icon if >7 members
            mapCreatorCount.text = "\(mapData.memberIDs.count) joined"
            joinedIcon.isHidden = false
        }
        makeMapNameConstraints()
    }

    private func makeMapNameConstraints() {
        mapCreatorCount.snp.removeConstraints()
        userButton.snp.removeConstraints()
        let joinedShowing = mapData?.memberIDs.count ?? 0 > 6 || mapData?.communityMap ?? false

        mapCreatorProfileImage1.isHidden = joinedShowing
        mapCreatorProfileImage2.isHidden = joinedShowing || memberProfiles.count < 2
        mapCreatorProfileImage3.isHidden = joinedShowing || memberProfiles.count < 3
        mapCreatorProfileImage4.isHidden = joinedShowing || memberProfiles.count < 4

        mapCreatorCount.snp.makeConstraints {
            $0.trailing.lessThanOrEqualToSuperview().inset(14)
            if joinedShowing {
                $0.centerY.equalTo(joinedIcon)
                $0.leading.equalTo(joinedIcon.snp.trailing).offset(4)
            } else {
                $0.centerY.equalTo(mapCreatorProfileImage1)
                switch memberProfiles.count {
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
        guard let mapData = mapData else { return }
        if mapData.memberIDs.contains(UserDataModel.shared.uid) {
            // show 2 button view
            actionButton.isHidden = true
            editButton.isHidden = false
            editButton.tag = 0
            addFriendsButton.isHidden = false
            /// only show edit button if user is founder
            if (mapData.communityMap ?? false) || UserDataModel.shared.uid != mapData.founderID {
                editButton.tag = 1
                editButton.setTitle("Joined", for: .normal)
                editButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            }

        } else {
            // show singular action button
            actionButton.isHidden = false
            editButton.isHidden = true
            addFriendsButton.isHidden = true

            if mapData.communityMap ?? false {
                actionButton.setTitle("Join", for: .normal)
                actionButton.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            } else if mapData.likers.contains(UserDataModel.shared.uid) {
                actionButton.setTitle("Following", for: .normal)
                actionButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            } else if !mapData.secret {
                actionButton.setTitle("Follow map", for: .normal)
                actionButton.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            }
        }
    }

    @objc func editTap() {
        if editButton.tag == 0 {
            guard let mapData = mapData else { return }
            guard let vc = viewContainingController() as? CustomMapController else { return }
            vc.setDrawerValuesForViewAppear()
            let editVC = EditMapController(mapData: mapData)
            editVC.customMapVC = vc
            editVC.modalPresentationStyle = .fullScreen
            vc.present(editVC, animated: true)
        } else {
            addActionSheet()
        }
    }

    @objc func addFriendsTap() {
        guard let vc = viewContainingController() as? CustomMapController else { return }
        guard let mapData = mapData else { return }
        let friendsList = UserDataModel.shared.userInfo.getSelectedFriends(memberIDs: mapData.memberIDs)
        let friendsVC = FriendsListController(
            allowsSelection: true,
            showsSearchBar: true,
            friendIDs: UserDataModel.shared.userInfo.friendIDs,
            friendsList: friendsList,
            confirmedIDs: mapData.memberIDs
        )
        
        friendsVC.delegate = self
        vc.present(friendsVC, animated: true)
    }

    @objc func actionButtonAction() {
        switch actionButton.titleLabel?.text {
        case "Follow map", "Join":
            followMap()
        case "Following", "Joined":
            addActionSheet()
        default:
            return
        }
    }

    func followMap() {
        Mixpanel.mainInstance().track(event: "CustomMapFollowMap")
        mapData?.likers.append(UserDataModel.shared.uid)
        if mapData?.communityMap ?? false {
            mapData?.memberIDs.append(UserDataModel.shared.uid)
        }

        if let mapData = mapData { UserDataModel.shared.userInfo.mapsList.append(mapData) }
        addNewUsersInDB(addedUsers: [UserDataModel.shared.uid])
    }

    @objc func userTap() {
        Mixpanel.mainInstance().track(event: "CustomMapMembersTap")
        guard let customMapVC = viewContainingController() as? CustomMapController else { return }

        let friendListVC = FriendsListController(
            allowsSelection: false,
            showsSearchBar: false,
            friendIDs: mapData?.memberIDs ?? [],
            friendsList: [],
            confirmedIDs: [])
        friendListVC.delegate = self
        customMapVC.present(friendListVC, animated: true)
    }

    func addNewUsersInDB(addedUsers: [String]) {
        guard let mapData = mapData else { return }
        let db = Firestore.firestore()
        let mapsRef = db.collection("maps").document(mapData.id ?? "")
        mapsRef.updateData(["likers": FieldValue.arrayUnion(mapData.likers), "memberIDs": FieldValue.arrayUnion(mapData.memberIDs), "updateUserID": UserDataModel.shared.uid])
        mapPostService?.updatePostInviteLists(mapID: mapData.id ?? "", inviteList: mapData.memberIDs, completion: nil)
        sendEditNotification()
        // cancel on map join
        if addedUsers.first == UserDataModel.shared.uid { return }
        let functions = Functions.functions()
        functions.httpsCallable("sendMapInviteNotifications").call([
            "imageURL": mapData.imageURL,
            "mapID": mapData.id ?? "",
            "mapName": mapData.mapName,
            "postID": mapData.postIDs.first ?? "",
            "receiverIDs": addedUsers,
            "senderID": UserDataModel.shared.uid,
            "senderUsername": UserDataModel.shared.userInfo.username]) { result, error in
            print(result?.data as Any, error as Any)
        }
    }

    func sendEditNotification() {
        guard let mapData = mapData else { return }
        NotificationCenter.default.post(Notification(name: Notification.Name("EditMap"), object: nil, userInfo: ["map": mapData as Any]))
    }
}

extension CustomMapHeaderCell: MapCodeDelegate, FriendsListDelegate {
    func finishPassing(openProfile: UserProfile) {
        guard let containerVC = viewContainingController() as? CustomMapController else { return }
        let profileVC = ProfileViewController(userProfile: openProfile, presentedDrawerView: containerVC.containerDrawerView)
        containerVC.navigationController?.pushViewController(profileVC, animated: true)
    }

    func finishPassing(selectedUsers: [UserProfile]) {
        Mixpanel.mainInstance().track(event: "CustomMapInviteFriendsComplete")
        var addedUserIDs: [String] = []
        for user in selectedUsers {
            if !(mapData?.memberIDs.contains(where: { $0 == user.id ?? "_" }) ?? false) {
                mapData?.memberIDs.append(user.id ?? "")
                addedUserIDs.append(user.id ?? "")
            }
            if !(mapData?.likers.contains(where: { $0 == user.id ?? "_" }) ?? false) { mapData?.likers.append(user.id ?? "") }
        }
        addNewUsersInDB(addedUsers: addedUserIDs)
    }

    func finishPassing(newMapID: String) {
        followMap()
    }
}

class MapCreatorProfileImage: UIImageView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentMode = .scaleAspectFill
        layer.masksToBounds = true
        layer.borderWidth = 2
        layer.cornerRadius = 34 / 2
        layer.borderColor = UIColor.white.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

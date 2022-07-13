//
//  ProfileHeaderCell.swift
//  Spot
//
//  Created by Arnold on 6/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SnapKit

enum ProfileRelation {
    case myself
    case friend
    case pending
    case stranger
}

class ProfileHeaderCell: UICollectionViewCell {
    
    var profileImage: UIImageView!
    var profileAvatar: UIImageView!
    var profileName: UILabel!
    var profileAccount: UILabel!
    var locationButton: UIButton!
    var friendListButton: UIButton!
    var editButton: UIButton!
    private var profileID: String = ""
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        
    }
    
    public func cellSetup(profileID: String, profileURL: String, avatarURL: String, name: String, account: String, location: String, friendsCount: Int, relation: ProfileRelation) {
        self.profileID = profileID
        profileImage.sd_setImage(with: URL(string: profileURL))
        profileAvatar.sd_setImage(with: URL(string: avatarURL)) { image, Error, cache, url  in
            self.profileAvatar.image = image?.withHorizontallyFlippedOrientation()
        }
        profileName.text = name
        profileAccount.text = account
        locationButton.setTitle(location, for: .normal)
        if location == "" {
            locationButton.setImage(UIImage(), for: .normal)
            friendListButton.snp.updateConstraints {
                $0.leading.equalTo(locationButton.snp.trailing)
            }
        }
        friendListButton.setTitle("\(friendsCount) friends", for: .normal)
        switch relation {
        case .myself:
            editButton.setTitle("Edit profile", for: .normal)
            editButton.setTitleColor(.black, for: .normal)
            editButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            editButton.addTarget(self, action: #selector(editButtonAction), for: .touchUpInside)
        case .friend:
            editButton.setImage(UIImage(named: "FriendsIcon"), for: .normal)
            editButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
            editButton.setTitle("Friends", for: .normal)
            editButton.setTitleColor(.black, for: .normal)
            editButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            editButton.addTarget(self, action: #selector(friendsAction), for: .touchUpInside)
        case .pending:
            editButton.setImage(UIImage(named: "FriendsPendingIcon"), for: .normal)
            editButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
            editButton.setTitle("Pending", for: .normal)
            editButton.setTitleColor(.black, for: .normal)
            editButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            editButton.addTarget(self, action: #selector(friendsPendingAction), for: .touchUpInside)
        case .stranger:
            editButton.setImage(UIImage(named: "AddFriendIcon"), for: .normal)
            editButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
            editButton.setTitle("Add friend", for: .normal)
            editButton.setTitleColor(.black, for: .normal)
            editButton.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            editButton.addTarget(self, action: #selector(addFriendAction), for: .touchUpInside)
        }
    }
}

extension ProfileHeaderCell {
    private func viewSetup() {
        contentView.backgroundColor = .white
        
        profileImage = UIImageView {
            $0.image = UIImage()
            $0.contentMode = .scaleAspectFit
            $0.layer.masksToBounds = true
            $0.backgroundColor = .gray
            contentView.addSubview($0)
        }
        profileImage.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.equalToSuperview().offset(28)
            $0.width.height.equalTo(84)
        }
        profileImage.layer.cornerRadius = 84 / 2

        profileAvatar = UIImageView {
            $0.image = UIImage()
            $0.contentMode = .scaleAspectFit
            contentView.addSubview($0)
        }
        profileAvatar.snp.makeConstraints {
            $0.leading.equalTo(profileImage).inset(-14)
            $0.bottom.equalTo(profileImage).inset(-8.24)
            $0.height.equalTo(47.25)
            $0.width.equalTo(36)
        }
        
        profileName = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
            $0.text = ""
            $0.adjustsFontSizeToFitWidth = true
            contentView.addSubview($0)
        }
        profileName.snp.makeConstraints {
            $0.leading.equalTo(profileImage.snp.trailing).offset(15)
            $0.top.equalTo(profileImage).offset(7)
            $0.height.equalTo(23)
            $0.trailing.equalToSuperview().inset(29)
        }
        
        profileAccount = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
            $0.text = ""
            $0.adjustsFontSizeToFitWidth = true
            contentView.addSubview($0)
        }
        profileAccount.snp.makeConstraints {
            $0.leading.equalTo(profileName).offset(2)
            $0.top.equalTo(profileName.snp.bottom).offset(2)
            $0.height.equalTo(19)
            $0.width.equalTo(113)
        }
        
        locationButton = UIButton {
            $0.setImage(UIImage(named: "ProfileLocation"), for: .normal)
            $0.setTitle("", for: .normal)
            $0.titleLabel?.adjustsFontSizeToFitWidth = true
            $0.setTitleColor(UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1), for: .normal)
            $0.titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: -5)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 13)
            $0.addTarget(self, action: #selector(locationButtonAction), for: .touchUpInside)
            contentView.addSubview($0)
        }
        locationButton.snp.makeConstraints {
            $0.leading.equalTo(profileAccount)
            $0.top.equalTo(profileAccount.snp.bottom).offset(1)
            $0.height.equalTo(38)
        }
        
        friendListButton = UIButton {
            $0.setImage(UIImage(named: "Friends"), for: .normal)
            $0.setTitle("", for: .normal)
            $0.titleLabel?.adjustsFontSizeToFitWidth = true
            $0.setTitleColor(UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1), for: .normal)
            $0.titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: -5)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 13)
            $0.addTarget(self, action: #selector(friendListButtonAction), for: .touchUpInside)
            contentView.addSubview($0)
        }
        friendListButton.snp.makeConstraints {
            $0.leading.equalTo(locationButton.snp.trailing).offset(15)
            $0.top.equalTo(locationButton)
            $0.trailing.lessThanOrEqualToSuperview()
            $0.height.equalTo(38)
        }
        
        editButton = UIButton {
            $0.setTitle("Edit profile", for: .normal)
            $0.setTitleColor(.black, for: .normal)
            $0.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
            contentView.addSubview($0)
        }
        editButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(14)
            $0.height.equalTo(37)
            $0.top.equalTo(profileImage.snp.bottom).offset(16)
        }
        editButton.layer.cornerRadius = 37 / 2
    }
    
    @objc func locationButtonAction() {
    }
    
    @objc func friendListButtonAction() {
    }
    
    @objc func editButtonAction() {
        UIView.animate(withDuration: 0.15) {
            self.editButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { (Bool) in
            UIView.animate(withDuration: 0.15) {
                self.editButton.transform = .identity
            }
        }
    }
    
    @objc func friendsAction() {
        
    }
    
    @objc func friendsPendingAction() {
        
    }
    
    @objc func addFriendAction() {
        addFriend(senderProfile: UserDataModel.shared.userInfo, receiverID: profileID)
        editButton.setImage(UIImage(named: "FriendsPendingIcon"), for: .normal)
        editButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
        editButton.setTitle("Pending", for: .normal)
        editButton.setTitleColor(.black, for: .normal)
        editButton.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
    }
}

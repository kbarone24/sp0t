//
//  ProfileHeaderCell.swift
//  Spot
//
//  Created by Arnold on 6/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

class ProfileHeaderCell: UICollectionViewCell {
    
    lazy var profileImage = UIImageView {
        $0.image = R.image.theB0t()
        $0.backgroundColor = .gray
        $0.contentMode = .scaleAspectFit
    }
    lazy var profileAvatar = UIImageView {
        $0.image = R.image.pig()
        $0.contentMode = .scaleAspectFit
    }
    lazy var profileName = UILabel {
        $0.textColor = .black
        $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
        $0.text = "Profile Name"
    }
    lazy var profileAccount = UILabel {
        $0.textColor = .black
        $0.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
        $0.text = "Profile Account"
    }
    lazy var locationButton = UIButton {
        $0.setImage(R.image.locationIcon()?.withRenderingMode(.alwaysTemplate), for: .normal)
        $0.tintColor = .gray
        $0.setTitle("Joseph, OR", for: .normal)
        $0.setTitleColor(.lightGray, for: .normal)
        $0.imageEdgeInsets = UIEdgeInsets(top: 0, left: -15, bottom: 0, right: 0)
        $0.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 13)
        $0.addTarget(self, action: #selector(locationButtonAction), for: .touchUpInside)
    }
    lazy var friendListButton = UIButton {
        $0.setImage(R.image.friendNotification()?.withRenderingMode(.alwaysTemplate), for: .normal)
        $0.tintColor = .gray
        $0.setTitle("6 friends", for: .normal)
        $0.setTitleColor(.lightGray, for: .normal)
        $0.imageEdgeInsets = UIEdgeInsets(top: 0, left: -15, bottom: 0, right: 0)
        $0.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 13)
        $0.addTarget(self, action: #selector(friendListButtonAction), for: .touchUpInside)
    }
    
    @objc func locationButtonAction() {
    }
    
    @objc func friendListButtonAction() {
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        
    }
}

extension ProfileHeaderCell {
    private func viewSetup() {
        contentView.backgroundColor = .white
        
        contentView.addSubview(profileImage)
        profileImage.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.equalToSuperview().offset(28)
            $0.width.height.equalTo(84)
        }
        profileImage.layer.cornerRadius = 42
        profileImage.layer.masksToBounds = true
        
        contentView.addSubview(profileAvatar)
        profileAvatar.snp.makeConstraints {
            $0.leading.equalTo(profileImage).inset(-14)
            $0.bottom.equalTo(profileImage).inset(-8.24)
            $0.height.equalTo(47.25)
            $0.width.equalTo(36)
        }
        
        contentView.addSubview(profileName)
        profileName.snp.makeConstraints {
            $0.leading.equalTo(profileImage.snp.trailing).offset(15)
            $0.top.equalTo(profileImage).offset(7)
            $0.height.equalTo(23)
            $0.trailing.equalToSuperview().inset(29)
        }
        
        contentView.addSubview(profileAccount)
        profileAccount.snp.makeConstraints {
            $0.leading.equalTo(profileName).offset(2)
            $0.top.equalTo(profileName.snp.bottom).offset(2)
            $0.height.equalTo(19)
            $0.width.equalTo(113)
        }
        
        contentView.addSubview(locationButton)
        locationButton.snp.makeConstraints {
            $0.leading.equalTo(profileAccount)
            $0.top.equalTo(profileAccount.snp.bottom).offset(1)
            $0.height.equalTo(38)
            $0.width.equalTo(100)
        }
        
        contentView.addSubview(friendListButton)
        friendListButton.snp.makeConstraints {
            $0.leading.equalTo(locationButton.snp.trailing).inset(5)
            $0.top.equalTo(locationButton)
            $0.height.equalTo(38)
            $0.width.equalTo(100)
        }
    }
}

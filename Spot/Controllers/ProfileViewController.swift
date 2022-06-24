//
//  ProfileViewController.swift
//  Spot
//
//  Created by Kenny Barone on 6/6/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SnapKit

class ProfileViewController: UIViewController {
    
    private lazy var profileImage = UIImageView {
        $0.image = R.image.theB0t()
        $0.backgroundColor = .gray
        $0.contentMode = .scaleAspectFit
    }
    private lazy var profileAvatar = UIImageView {
        $0.image = R.image.pig()
        $0.contentMode = .scaleAspectFit
    }
    private lazy var profileName = UILabel {
        $0.textColor = .black
        $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
        $0.text = "Profile Name"
    }
    private lazy var profileAccount = UILabel {
        $0.textColor = .black
        $0.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
        $0.text = "Profile Account"
    }
    private lazy var locationButton = UIButton {
        $0.setImage(R.image.locationIcon()?.withRenderingMode(.alwaysTemplate), for: .normal)
        $0.tintColor = .gray
        $0.setTitle("Joseph, OR", for: .normal)
        $0.setTitleColor(.lightGray, for: .normal)
        $0.imageEdgeInsets = UIEdgeInsets(top: 0, left: -15, bottom: 0, right: 0)
        $0.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 13)
    }
    private lazy var friendListButton = UIButton {
        $0.setImage(R.image.friendNotification()?.withRenderingMode(.alwaysTemplate), for: .normal)
        $0.tintColor = .gray
        $0.setTitle("6 friends", for: .normal)
        $0.setTitleColor(.lightGray, for: .normal)
        $0.imageEdgeInsets = UIEdgeInsets(top: 0, left: -15, bottom: 0, right: 0)
        $0.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 13)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewSetup()
    }
}

extension ProfileViewController {
    
    private func viewSetup() {
        view.backgroundColor = .white
        
        view.addSubview(profileImage)
        profileImage.snp.makeConstraints {
            $0.top.equalToSuperview().offset(45)
            $0.leading.equalToSuperview().offset(28)
            $0.width.height.equalTo(84)
        }
        profileImage.layer.cornerRadius = 42
        profileImage.layer.masksToBounds = true
        
        view.addSubview(profileAvatar)
        profileAvatar.snp.makeConstraints {
            $0.leading.equalTo(profileImage).inset(-14)
            $0.bottom.equalTo(profileImage).inset(-8.24)
            $0.height.equalTo(47.25)
            $0.width.equalTo(36)
        }
        
        view.addSubview(profileName)
        profileName.snp.makeConstraints {
            $0.leading.equalTo(profileImage.snp.trailing).offset(15)
            $0.top.equalTo(profileImage).offset(7)
            $0.height.equalTo(23)
            $0.trailing.equalToSuperview().inset(29)
        }
        
        view.addSubview(profileAccount)
        profileAccount.snp.makeConstraints {
            $0.leading.equalTo(profileName).offset(2)
            $0.top.equalTo(profileName.snp.bottom).offset(2)
            $0.height.equalTo(19)
            $0.width.equalTo(113)
        }
        
        view.addSubview(locationButton)
        locationButton.snp.makeConstraints {
            $0.leading.equalTo(profileAccount)
            $0.top.equalTo(profileAccount.snp.bottom).offset(1)
            $0.height.equalTo(38)
            $0.width.equalTo(100)
        }
        
        view.addSubview(friendListButton)
        friendListButton.snp.makeConstraints {
            $0.leading.equalTo(locationButton.snp.trailing).inset(5)
            $0.top.equalTo(locationButton)
            $0.height.equalTo(38)
            $0.width.equalTo(100)
        }
    }
}

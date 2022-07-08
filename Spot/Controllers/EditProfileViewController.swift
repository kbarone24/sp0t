//
//  EditProfileViewController.swift
//  Spot
//
//  Created by Arnold on 7/8/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

class EditProfileViewController: UIViewController {
    
    private var editLabel: UILabel!
    private var backButton: UIButton!
    private var profileImage: UIImageView!
    private var profilePicSelectionButton: UIButton!
    private var avatarLabel: UILabel!
    private var avatarImage: UIImageView!
    private var avatarEditButton: UIButton!
    private var nameLabel: UILabel!
    private var nameTextfield: UITextField!
    private var locationLabel: UILabel!
    private var locationTextfield: UITextField!
    
    
    private var privateLabel: UILabel!
    private var privateDescription: UILabel!
    private var privateSelection: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewSetup()
    }
    
    @objc func dismissAction() {
        UIView.animate(withDuration: 0.15) {
            self.backButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { (Bool) in
            UIView.animate(withDuration: 0.15) {
                self.backButton.transform = .identity
            }
        }
        dismiss(animated: true)
    }
    
    @objc func profilePicSelectionAction() {
    }
    
    @objc func avatarEditAction() {
    }
}

extension EditProfileViewController {
    private func viewSetup() {
        view.backgroundColor = .white
        
        editLabel = UILabel {
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
            $0.text = "Edit profile"
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            $0.textAlignment = .center
            view.addSubview($0)
        }
        editLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(55)
            $0.leading.trailing.equalToSuperview()
        }
        
        backButton = UIButton {
            $0.setImage(UIImage(named: "BackArrow-1"), for: .normal)
            $0.setTitle("", for: .normal)
            $0.addTarget(self, action: #selector(dismissAction), for: .touchUpInside)
            view.addSubview($0)
        }
        backButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(22)
            $0.top.equalTo(editLabel)
        }
        
        profileImage = UIImageView {
            $0.layer.cornerRadius = 51.5
            $0.layer.masksToBounds = true
            $0.image = UserDataModel.shared.userInfo.profilePic
            view.addSubview($0)
        }
        profileImage.snp.makeConstraints {
            $0.width.height.equalTo(103)
            $0.top.equalTo(editLabel.snp.bottom).offset(21)
            $0.centerX.equalToSuperview()
        }
        
        profilePicSelectionButton = UIButton {
            $0.setImage(UIImage(named: "EditProfilePicture"), for: .normal)
            $0.setTitle("", for: .normal)
            $0.addTarget(self, action: #selector(profilePicSelectionAction), for: .touchUpInside)
            view.addSubview($0)
        }
        profilePicSelectionButton.snp.makeConstraints {
            $0.width.height.equalTo(42)
            $0.trailing.equalTo(profileImage).offset(5)
            $0.bottom.equalTo(profileImage).offset(3)
        }
        
        avatarLabel = UILabel {
            $0.text = "Avatar"
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            view.addSubview($0)
        }
        avatarLabel.snp.makeConstraints {
            $0.top.equalTo(profileImage.snp.bottom).offset(6)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
        
        avatarImage = UIImageView {
            $0.image = UserDataModel.shared.userInfo.avatarPic.withHorizontallyFlippedOrientation()
            $0.contentMode = .scaleAspectFit
            view.addSubview($0)
        }
        avatarImage.snp.makeConstraints {
            $0.top.equalTo(avatarLabel.snp.bottom).offset(2)
            $0.leading.equalToSuperview().offset(16)
            $0.width.equalTo(43)
            $0.height.equalTo(56.5)
        }
        
        avatarEditButton = UIButton {
            $0.setImage(UIImage(named: "EditAvatar"), for: .normal)
            $0.setTitle("", for: .normal)
            $0.addTarget(self, action: #selector(avatarEditAction), for: .touchUpInside)
            view.addSubview($0)
        }
        avatarEditButton.snp.makeConstraints {
            $0.leading.equalTo(avatarImage.snp.trailing).offset(1)
            $0.centerY.equalTo(avatarImage)
            $0.width.height.equalTo(22)
        }
        
        nameLabel = UILabel {
            $0.text = "Name"
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            view.addSubview($0)
        }
        nameLabel.snp.makeConstraints {
            $0.top.equalTo(avatarImage.snp.bottom).offset(18.56)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
        
        nameTextfield = UITextField {
            $0.text = UserDataModel.shared.userInfo.name
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            $0.layer.cornerRadius = 11
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 16)
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            $0.setLeftPaddingPoints(8)
            $0.setRightPaddingPoints(8)
            view.addSubview($0)
        }
        nameTextfield.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(1)
            $0.leading.equalToSuperview().offset(14)
            $0.trailing.equalToSuperview().inset(63)
            $0.height.equalTo(36)
        }
        
        locationLabel = UILabel {
            $0.text = "Location"
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            view.addSubview($0)
        }
        locationLabel.snp.makeConstraints {
            $0.top.equalTo(nameTextfield.snp.bottom).offset(18)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
        
        locationTextfield = UITextField {
            $0.text = UserDataModel.shared.userInfo.currentLocation
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            $0.layer.cornerRadius = 11
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 16)
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            $0.setLeftPaddingPoints(8)
            $0.setRightPaddingPoints(8)
            view.addSubview($0)
        }
        locationTextfield.snp.makeConstraints {
            $0.top.equalTo(locationLabel.snp.bottom).offset(1)
            $0.leading.equalToSuperview().offset(14)
            $0.trailing.equalToSuperview().inset(63)
            $0.height.equalTo(36)
        }
    }
}

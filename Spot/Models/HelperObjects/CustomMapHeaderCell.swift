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
    
    private var mapData: CustomMap!
    private var memberList: [UserProfile] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        
    }
    
    public func cellSetup(userProfile: UserProfile, mapData: CustomMap?) {
        guard mapData != nil else { return }
        self.mapData = mapData
        mapCoverImage.sd_setImage(with: URL(string: mapData!.imageURL))
        
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
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.getMemberAndSetView()
        }
        
        mapInfo.text = mapData!.likers.count == 0 ? "\(mapData!.spotIDs.count) spots • \(mapData!.postIDs.count) posts" : "\(mapData!.likers.count) followers • \(mapData!.spotIDs.count) spots • \(mapData!.postIDs.count) posts"
        
        if mapData!.memberIDs.contains(userProfile.id!) == false && mapData!.likers.contains(userProfile.id!) == false {
            actionButton.setTitle("Follow map", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
        } else if mapData!.likers.contains(userProfile.id!) {
            actionButton.setTitle("Following", for: .normal)
        } else if mapData!.memberIDs.contains(userProfile.id!) {
            actionButton.setTitle("Edit map", for: .normal)
        }
        actionButton.addTarget(self, action: #selector(actionButtonAction), for: .touchUpInside)

        if mapData!.mapDescription != nil {
            mapBio.text = mapData!.mapDescription
        }
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
            $0.image = UIImage()
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
            $0.image = UIImage()
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
            $0.image = UIImage()
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
            $0.image = UIImage()
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
            $0.text = ""
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
            $0.text = ""
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
            $0.text = ""
            $0.adjustsFontSizeToFitWidth = true
            contentView.addSubview($0)
        }
        mapBio.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(15)
            $0.top.equalTo(actionButton.snp.bottom).offset(16)
        }
    }
    
    private func getMemberAndSetView() {
        let db: Firestore = Firestore.firestore()
        let dispatch = DispatchGroup()
        memberList.removeAll()
        for id in mapData.memberIDs {
            dispatch.enter()
            db.collection("users").document(id).getDocument { [weak self] snap, err in
                do {
                    guard let self = self else { return }
                    let unwrappedInfo = try snap?.data(as: UserProfile.self)
                    guard var userInfo = unwrappedInfo else { dispatch.leave(); return }
                    userInfo.id = id
                    self.memberList.append(userInfo)
                    dispatch.leave()
                } catch let parseError {
                    print("JSON Error \(parseError.localizedDescription)")
                    dispatch.leave()
                }
            }
        }
        dispatch.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            var mapFounderProfile: UserProfile!
            for index in 0..<self.memberList.count {
                if self.memberList[index].id == self.mapData.founderID {
                    mapFounderProfile = self.memberList[index]
                    self.memberList.remove(at: index)
                    break
                }
            }
            
            self.mapCreaterCount.text = "\(mapFounderProfile.username) + \(self.mapData.memberIDs.count - 1)"
            self.mapCreaterProfileImage1.sd_setImage(with: URL(string: mapFounderProfile.imageURL))
            switch self.mapData.memberIDs.count {
            case 1:
                self.mapCreaterCount.text = "\(mapFounderProfile.username)"
                self.mapCreaterProfileImage4.snp.updateConstraints {
                    $0.leading.equalTo(self.mapCreaterProfileImage1)
                }
                self.mapCreaterProfileImage3.snp.updateConstraints {
                    $0.leading.equalTo(self.mapCreaterProfileImage1)
                }
                self.mapCreaterProfileImage2.snp.updateConstraints {
                    $0.leading.equalTo(self.mapCreaterProfileImage1)
                }
            case 2:
                self.mapCreaterProfileImage2.sd_setImage(with: URL(string: self.memberList[0].imageURL))
                self.mapCreaterProfileImage4.snp.updateConstraints {
                    $0.leading.equalTo(self.mapCreaterProfileImage1)
                }
                self.mapCreaterProfileImage3.snp.updateConstraints {
                    $0.leading.equalTo(self.mapCreaterProfileImage1)
                }
            case 3:
                self.mapCreaterProfileImage2.sd_setImage(with: URL(string: self.memberList[0].imageURL))
                self.mapCreaterProfileImage3.sd_setImage(with: URL(string: self.memberList[1].imageURL))
                self.mapCreaterProfileImage4.snp.updateConstraints {
                    $0.leading.equalTo(self.mapCreaterProfileImage1)
                }
            default:
                self.mapCreaterProfileImage2.sd_setImage(with: URL(string: self.memberList[0].imageURL))
                self.mapCreaterProfileImage3.sd_setImage(with: URL(string: self.memberList[1].imageURL))
                self.mapCreaterProfileImage4.sd_setImage(with: URL(string: self.memberList[2].imageURL))
                return
            }
        }
    }
    
    @objc func actionButtonAction() {
        UIView.animate(withDuration: 0.15) {
            self.actionButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { (Bool) in
            UIView.animate(withDuration: 0.15) {
                self.actionButton.transform = .identity
            }
        }
    }
}

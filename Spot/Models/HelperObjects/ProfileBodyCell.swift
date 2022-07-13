//
//  ProfileBodyCell.swift
//  Spot
//
//  Created by Arnold Lee on 2022/6/27.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

class ProfileBodyCell: UICollectionViewCell {
    var mapImage: UIImageView!
    var mapName: UILabel!
    var friendsCount: UILabel!
    private var friendsIcon: UIImageView!
    var likesCount: UILabel!
    var postsCount: UILabel!
    var privateIcon: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        if mapImage.image != nil { mapImage.sd_cancelCurrentImageLoad() }
    }
    
    public func cellSetup(imageURL: String, mapName: String, isPrivate: Bool, friendsCount: Int, likesCount: Int, postsCount: Int) {
        mapImage.sd_setImage(with: URL(string: imageURL))
        self.mapName.text = mapName
        privateIcon.isHidden = !isPrivate
        self.friendsCount.text = friendsCount == 1 ? "" : "\(friendsCount)"
        self.friendsIcon.snp.updateConstraints {
            $0.width.equalTo(friendsCount == 1 ? 0 : 13.33)
        }
        self.friendsIcon.isHidden = friendsCount == 1
        self.likesCount.text = likesCount != 0 ? (friendsCount == 1 ? "\(likesCount) likes" : " • \(likesCount) likes") : ""
        self.postsCount.text = postsCount != 0 ? ((friendsCount == 1 && likesCount == 0) ? "\(postsCount) posts" : " • \(postsCount) posts") : ""
    }
}

extension ProfileBodyCell {
    private func viewSetup() {
        contentView.backgroundColor = .white
        
        mapImage = UIImageView {
            $0.image = R.image.signuplogo()
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.layer.cornerRadius = 14
            contentView.addSubview($0)
        }
        mapImage.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(contentView.frame.width).multipliedBy(182/195)
        }
        
        privateIcon = UIImageView {
            $0.image = UIImage(named: "PrivateMap")
            $0.contentMode = .scaleAspectFit
            $0.layer.masksToBounds = true
            mapImage.addSubview($0)
        }
        privateIcon.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.height.width.equalTo(42)
        }
        
        mapName = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 16)
            $0.text = ""
            contentView.addSubview($0)
        }
        mapName.snp.makeConstraints {
            $0.leading.trailing.equalTo(mapImage)
            $0.top.equalTo(mapImage.snp.bottom).offset(6)
        }
        
        friendsCount = UILabel {
            $0.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
            $0.text = ""
            contentView.addSubview($0)
        }
        friendsCount.snp.makeConstraints {
            $0.leading.equalTo(mapImage)
            $0.top.equalTo(mapName.snp.bottom).offset(2)
            $0.trailing.lessThanOrEqualToSuperview()
        }
        
        friendsIcon = UIImageView {
            $0.image = UIImage(named: "Friends")?.withRenderingMode(.alwaysTemplate)
            $0.tintColor = UIColor(red: 0.658, green: 0.658, blue: 0.658, alpha: 1)
            $0.contentMode = .scaleAspectFit
            $0.layer.masksToBounds = true
            contentView.addSubview($0)
        }
        friendsIcon.snp.makeConstraints {
            $0.leading.equalTo(friendsCount.snp.trailing).offset(3)
            $0.top.equalTo(friendsCount).offset(3)
            $0.width.equalTo(13.33)
            $0.height.equalTo(10)
        }
        
        likesCount = UILabel {
            $0.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
            $0.text = ""
            contentView.addSubview($0)
        }
        likesCount.snp.makeConstraints {
            $0.leading.equalTo(friendsIcon.snp.trailing)
            $0.top.equalTo(friendsCount)
            $0.trailing.lessThanOrEqualToSuperview()
        }
        
        postsCount = UILabel {
            $0.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
            $0.text = ""
            contentView.addSubview($0)
        }
        postsCount.snp.makeConstraints {
            $0.leading.equalTo(likesCount.snp.trailing)
            $0.top.equalTo(friendsCount)
            $0.trailing.lessThanOrEqualToSuperview()
        }
    }
}

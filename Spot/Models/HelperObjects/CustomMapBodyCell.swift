//
//  CustomMapBodyCell.swift
//  Spot
//
//  Created by Arnold on 7/24/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

class CustomMapBodyCell: UICollectionViewCell {
    
    private var postImage: UIImageView!
    private var postLocation: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
    }
    
    public func cellSetup(imageURL: String, mapName: String, isPrivate: Bool, friendsCount: Int, likesCount: Int, postsCount: Int) {
    }
}

extension CustomMapBodyCell {
    private func viewSetup() {
        contentView.backgroundColor = .white
        
        postImage = UIImageView {
            $0.image = UserDataModel.shared.userInfo.profilePic
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.layer.cornerRadius = 2
            contentView.addSubview($0)
        }
        postImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        postLocation = UILabel {
            $0.textColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
            $0.alpha = 0.96
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = UIImage(named: "Vector")
            imageAttachment.bounds = CGRect(x: 0, y: -2.5, width: imageAttachment.image!.size.width, height: imageAttachment.image!.size.height)
            let attachmentString = NSAttributedString(attachment: imageAttachment)
            let completeText = NSMutableAttributedString(string: "")
            completeText.append(attachmentString)
            completeText.append(NSAttributedString(string: " "))
            completeText.append(NSAttributedString(string: "Arnold"))
            $0.attributedText = completeText
            contentView.addSubview($0)
        }
        postLocation.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(8)
            $0.bottom.equalToSuperview().inset(9)
        }
    }
}

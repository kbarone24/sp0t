//
//  CustomMapUploadCell.swift
//  Spot
//
//  Created by Kenny Barone on 8/30/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import FirebaseUI

class CustomMapUploadCell: UITableViewCell {
    var mapImage: UIImageView!
    var nameLabel: UILabel!
    var selectedImage: UIImageView!
    var bottomLine: UIView!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?){
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUpView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp(map: CustomMap, selected: Bool, beginningCell: Bool, endCell: Bool) {
        let url = map.imageURL
        if map.coverImage != UIImage () {
            mapImage.image = map.coverImage
        } else if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            mapImage.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
        }
        
        let buttonImage = selected ? UIImage(named: "MapToggleOn") : UIImage(named: "MapToggleOff")
        selectedImage.image = buttonImage
        
        if map.secret {
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = UIImage(named: "SecretMap")
            imageAttachment.bounds = CGRect(x: 0, y: 0, width: imageAttachment.image!.size.width, height: imageAttachment.image!.size.height)
            let attachmentString = NSAttributedString(attachment: imageAttachment)
            let completeText = NSMutableAttributedString(string: "")
            completeText.append(attachmentString)
            completeText.append(NSAttributedString(string: " \(map.mapName)"))
            self.nameLabel.attributedText = completeText
        } else {
            nameLabel.attributedText = NSAttributedString(string: map.mapName)
        }
    }

    func setUpView() {
        backgroundColor = .white
        selectionStyle = .none
        
        mapImage = UIImageView {
            $0.layer.cornerRadius = 9
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFill
            contentView.addSubview($0)
        }
        mapImage.snp.makeConstraints {
            $0.leading.equalTo(14)
            $0.height.width.equalTo(49)
            $0.centerY.equalToSuperview()
        }
        
        selectedImage = UIImageView {
            contentView.addSubview($0)
        }
        selectedImage.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(21)
            $0.height.width.equalTo(33)
            $0.centerY.equalToSuperview()
        }

        nameLabel = UILabel {
            $0.textColor = .black
            $0.lineBreakMode = .byTruncatingTail
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 18)
            contentView.addSubview($0)
        }
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(mapImage.snp.trailing).offset(10)
            $0.trailing.lessThanOrEqualTo(selectedImage.snp.leading).offset(-8)
            $0.centerY.equalToSuperview()
        }

        bottomLine = UIView {
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            contentView.addSubview($0)
        }
        bottomLine.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.trailing.equalToSuperview().inset(25)
            $0.height.equalTo(1)
            $0.bottom.equalToSuperview()
        }
    }
}



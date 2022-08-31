//
//  ProfileBodyCell.swift
//  Spot
//
//  Created by Arnold Lee on 2022/6/27.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import FirebaseUI

class ProfileBodyCell: UICollectionViewCell {
    private var mapImage: UIImageView!
    private var mapName: UILabel!
    private var spotsLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        if mapImage != nil { mapImage.sd_cancelCurrentImageLoad() }
    }
    
    public func cellSetup(mapData: CustomMap, userID: String) {
        var urlString = mapData.imageURL
        if let i = mapData.posterIDs.lastIndex(where: {$0 == userID}) {
            urlString = mapData.postImageURLs[safe: i] ?? ""
        }
        let transformer = SDImageResizingTransformer(size: CGSize(width: 200, height: 200), scaleMode: .aspectFill)
        mapImage.sd_setImage(with: URL(string: urlString), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        
        if mapData.secret {
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = UIImage(named: "SecretMap")
            imageAttachment.bounds = CGRect(x: 0, y: 0, width: imageAttachment.image!.size.width, height: imageAttachment.image!.size.height)
            let attachmentString = NSAttributedString(attachment: imageAttachment)
            let completeText = NSMutableAttributedString(string: "")
            completeText.append(attachmentString)
            completeText.append(NSAttributedString(string: " \(mapData.mapName)"))
            self.mapName.attributedText = completeText
        } else {
            self.mapName.attributedText = NSAttributedString(string: mapData.mapName) 
        }
        
        spotsLabel.text = mapData.spotIDs.count > 1 ? "\(mapData.spotIDs.count) spots" : ""
    }
}

extension ProfileBodyCell {
    private func viewSetup() {
        contentView.backgroundColor = .white
        
        mapImage = UIImageView {
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.layer.cornerRadius = 14
            contentView.addSubview($0)
        }
        mapImage.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(contentView.frame.width).multipliedBy(182/195)
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
        
        spotsLabel = UILabel {
            $0.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
            contentView.addSubview($0)
        }
        spotsLabel.snp.makeConstraints {
            $0.leading.equalTo(mapImage)
            $0.top.equalTo(mapName.snp.bottom).offset(1)
            $0.trailing.lessThanOrEqualToSuperview()
        }
    }
}

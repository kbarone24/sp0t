//
//  CustomMapBodyCell.swift
//  Spot
//
//  Created by Arnold on 7/24/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SDWebImage

class CustomMapBodyCell: UICollectionViewCell {
    
    private var postImage: UIImageView!
    private var postLocation: UILabel!
    private var postData: MapPost?
    private lazy var fetching = false
    private lazy var imageManager = SDWebImageManager()
        
    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        if postImage != nil {
            postImage.image = UIImage()
            postLocation.text = ""
        }
    }
    
    public func cellSetup(postData: MapPost) {
        self.postData = postData
        
        let transformer = SDImageResizingTransformer(size: CGSize(width: UIScreen.main.bounds.width * 2/3, height: (UIScreen.main.bounds.width * 2/3) * 1.5), scaleMode: .aspectFill)
        postImage.sd_setImage(with: URL(string: postData.imageURLs.first ?? ""), placeholderImage: UIImage(color: UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)), options: .highPriority, context: [.imageTransformer: transformer])
        
        if postData.spotName != "" {
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = UIImage(named: "Vector")
            imageAttachment.bounds = CGRect(x: 0, y: -2.5, width: imageAttachment.image!.size.width, height: imageAttachment.image!.size.height)
            let attachmentString = NSAttributedString(attachment: imageAttachment)
            let completeText = NSMutableAttributedString(string: "")
            completeText.append(attachmentString)
            completeText.append(NSAttributedString(string: " "))
            completeText.append(NSAttributedString(string: postData.spotName!))
            self.postLocation.attributedText = completeText
        }
    }
}

extension CustomMapBodyCell {
    private func viewSetup() {
        contentView.backgroundColor = .white
        
        postImage = UIImageView {
            $0.image = UIImage()
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
            $0.lineBreakMode = .byTruncatingTail
            contentView.addSubview($0)
        }
        postLocation.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(8)
            $0.bottom.equalToSuperview().inset(9)
        }
    }
}

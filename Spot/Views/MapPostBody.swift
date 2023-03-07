//
//  MapPostBody.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/25/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import SDWebImage
import UIKit

final class MapPostBody: UIView {
    private lazy var postImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = 2
        imageView.image = UIImage()
        return imageView
    }()
    
    private lazy var postLocation: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
        label.alpha = 0.96
        label.numberOfLines = 0
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(postImage)
        addSubview(postLocation)
        
        postImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        postLocation.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(8)
            $0.bottom.equalToSuperview().inset(9)
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(data: MapPost) {
        let transformer = SDImageResizingTransformer(
            size: CGSize(width: UIScreen.main.bounds.width * 2 / 3, height: (UIScreen.main.bounds.width * 2 / 3) * 1.5),
            scaleMode: .aspectFill
        )
        
        postImage.image = UIImage()
        postImage.sd_cancelCurrentImageLoad()
        postImage.sd_setImage(
            with: URL(string: data.imageURLs.first ?? ""),
            placeholderImage: UIImage(color: .darkGray),
            options: .highPriority,
            context: [
                .imageTransformer: transformer
            ]
        )
        
        guard let spotName = data.spotName, !spotName.isEmpty else { return }
        
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(named: "Vector")
        
        if let imageWidth = imageAttachment.image?.size.width,
           let imageHeight = imageAttachment.image?.size.height {
            imageAttachment.bounds = CGRect(x: 0, y: -2.5, width: imageWidth, height: imageHeight)
        }

        let attachmentString = NSAttributedString(attachment: imageAttachment)
        let completeText = NSMutableAttributedString(string: "")
        completeText.append(attachmentString)
        completeText.append(NSAttributedString(string: " "))
        completeText.append(NSAttributedString(string: spotName))
        
        postLocation.attributedText = completeText
        
        layoutIfNeeded()
    }
    
    func reset() {
        postImage.sd_cancelCurrentImageLoad()
        postLocation.text = ""
    }
}

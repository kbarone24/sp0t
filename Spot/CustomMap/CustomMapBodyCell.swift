//
//  CustomMapBodyCell.swift
//  Spot
//
//  Created by Arnold on 7/24/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import SDWebImage
import UIKit

class CustomMapBodyCell: UICollectionViewCell {
    private var postData: MapPost?

    private lazy var postImage: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        return imageView
    }()

    private lazy var postLocation: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
        label.alpha = 0.96
        label.lineBreakMode = .byTruncatingTail
        contentView.addSubview(label)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        postImage.sd_cancelCurrentImageLoad()
        postImage.image = UIImage()
        postLocation.text = ""
    }

    public func cellSetup(postData: MapPost, transform: Bool = true, cornerRadius: CGFloat = 2) {
        self.postData = postData

        postImage.layer.cornerRadius = cornerRadius
        postImage.sd_cancelCurrentImageLoad()
        if transform {
            let transformer = SDImageResizingTransformer(size: CGSize(width: UIScreen.main.bounds.width * 2 / 3, height: (UIScreen.main.bounds.width * 2 / 3) * 1.5), scaleMode: .aspectFill)
            
            postImage.sd_setImage(
                with: URL(string: postData.imageURLs.first ?? ""),
                placeholderImage: UIImage(color: UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)),
                options: .highPriority,
                context: [.imageTransformer: transformer]
            )
        } else {
            postImage.sd_setImage(
                with: URL(string: postData.imageURLs.first ?? ""),
                placeholderImage: UIImage(color: UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)),
                options: .highPriority
                )
        }

        if postData.spotName != "" {
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = UIImage(named: "Vector")
            imageAttachment.bounds = CGRect(x: 0, y: -2.5, width: imageAttachment.image?.size.width ?? 0, height: imageAttachment.image?.size.height ?? 0)
            let attachmentString = NSAttributedString(attachment: imageAttachment)
            let completeText = NSMutableAttributedString(string: "")
            completeText.append(attachmentString)
            completeText.append(NSAttributedString(string: " "))
            completeText.append(NSAttributedString(string: postData.spotName ?? ""))
            self.postLocation.attributedText = completeText
        }
    }
}

extension CustomMapBodyCell {
    private func viewSetup() {
        contentView.backgroundColor = .black

        contentView.addSubview(postImage)
        postImage.snp.makeConstraints {
            $0.leading.trailing.top.bottom.equalToSuperview()
        }

        contentView.addSubview(postLocation)
        postLocation.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(8)
            $0.bottom.equalToSuperview().inset(9)
        }
    }
}

//
//  CustomMapBodyCell.swift
//  Spot
//
//  Created by Arnold on 7/24/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SDWebImage

protocol CustomMapBodyCellDelegate {
    func finishFetching(mapPostID: String, fetchedMapPost: MapPost )
}

class CustomMapBodyCell: UICollectionViewCell {
    
    private var postImage: UIImageView!
    private var postLocation: UILabel!
    private var postID: String!
    private var postData: MapPost?
    private lazy var fetching = false
    private lazy var imageManager = SDWebImageManager()
    
    public var delegate: CustomMapBodyCellDelegate?
    
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
    
    public func cellSetup(postID: String, postData: MapPost?) {
        self.postID = postID
        self.postData = postData
        if postData != nil {
            postImage.image = postData?.postImage[0]
            if postData!.spotName != "" {
                let imageAttachment = NSTextAttachment()
                imageAttachment.image = UIImage(named: "Vector")
                imageAttachment.bounds = CGRect(x: 0, y: -2.5, width: imageAttachment.image!.size.width, height: imageAttachment.image!.size.height)
                let attachmentString = NSAttributedString(attachment: imageAttachment)
                let completeText = NSMutableAttributedString(string: "")
                completeText.append(attachmentString)
                completeText.append(NSAttributedString(string: " "))
                completeText.append(NSAttributedString(string: postData!.spotName!))
                self.postLocation.attributedText = completeText
            }
        } else {
            guard fetching == false else { return }
            fetchPostData(ID: postID)
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
            contentView.addSubview($0)
        }
        postLocation.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(8)
            $0.bottom.equalToSuperview().inset(9)
        }
    }
    
    private func fetchPostData(ID: String) {
        DispatchQueue.main.async {
            self.fetching = true
            self.getPost(postID: ID) { mapPost in
                if mapPost.spotName != "" {
                    let imageAttachment = NSTextAttachment()
                    imageAttachment.image = UIImage(named: "Vector")
                    imageAttachment.bounds = CGRect(x: 0, y: -2.5, width: imageAttachment.image!.size.width, height: imageAttachment.image!.size.height)
                    let attachmentString = NSAttributedString(attachment: imageAttachment)
                    let completeText = NSMutableAttributedString(string: "")
                    completeText.append(attachmentString)
                    completeText.append(NSAttributedString(string: " "))
                    completeText.append(NSAttributedString(string: mapPost.spotName!))
                    self.postLocation.attributedText = completeText
                }
                
                self.imageManager.loadImage(with: URL(string: mapPost.imageURLs[0]), options: .highPriority, context: nil, progress: nil) { [weak self] (image, data, err, cache, download, url) in
                    self?.fetching = false
                    guard self != nil else { return }
                    let image = image ?? UIImage()
                    self?.postImage.image = image
                    var mapPostWithImage = mapPost
                    mapPostWithImage.postImage.append(image)
                    let userInfo = ["mapPost": mapPostWithImage]
                    NotificationCenter.default.post(name: NSNotification.Name("FetchedMapPost"), object: nil, userInfo: userInfo)
                    
                    if self!.postID != mapPostWithImage.id {
                        self?.postLocation.text = ""
                        self?.postImage.image = UIImage()
                        self?.cellSetup(postID: self!.postID, postData: self?.postData)
                    }
                    
//                    self?.delegate?.finishFetching(mapPostID: ID, fetchedMapPost: mapPostWithImage)
                }
            }
        }
    }
}

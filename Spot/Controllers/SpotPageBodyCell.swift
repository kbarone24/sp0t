//
//  SpotPageBodyCell.swift
//  Spot
//
//  Created by Arnold on 8/10/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SDWebImage

class SpotPageBodyCell: UICollectionViewCell {
    
    private var postImage: UIImageView!
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
        }
    }
    
    public func cellSetup() {
        
    }
}

extension SpotPageBodyCell {
    private func viewSetup() {
        contentView.backgroundColor = .white
        
        postImage = UIImageView {
            $0.image = UIImage()
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.layer.cornerRadius = 2
            $0.backgroundColor = .gray
            contentView.addSubview($0)
        }
        postImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
    
    private func fetchPostData(ID: String) {
        DispatchQueue.main.async {
            self.fetching = true
            self.getPost(postID: ID) { mapPost in
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
                        self?.postImage.image = UIImage()
//                        self?.cellSetup(postID: self!.postID, postData: self?.postData)
                    }
                    
                }
            }
        }
    }
}

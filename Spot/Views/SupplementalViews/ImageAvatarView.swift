//
//  ImageAvatarView.swift
//  Spot
//
//  Created by Kenny Barone on 7/25/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import FirebaseUI

class ImageAvatarView: UIImageView {
    var imageManager: SDWebImageManager!
        
    func setUp(avatarURLs: [String]) {
        let transformer = SDImageResizingTransformer(size: CGSize(width: 69.4, height: 100), scaleMode: .aspectFit)
        var offset: CGFloat = 0
        if avatarURLs.count == 0 { return }
        for i in 0...avatarURLs.count - 1 {
            SDWebImageManager.shared.loadImage(with: URL(string: avatarURLs[i]), options: [.highPriority, .scaleDownLargeImages], context: [.imageTransformer: transformer], progress: nil) { (rawImage, data, err, cache, download, url) in
                let imageView = UIImageView {
                    $0.image = rawImage ?? UIImage()
                    $0.contentMode = .scaleAspectFill
                    self.addSubview($0)
                }
                print(i, "offset", offset)
                imageView.tag = i
                imageView.snp.makeConstraints {
                    $0.width.equalTo(26)
                    $0.height.equalTo(37.5)
                    $0.centerY.equalToSuperview()
                    $0.centerX.equalToSuperview().offset(offset)
                }
                offset = CGFloat(i/2) * 13 + 13
                if i % 2 != 0 { offset = -offset }
            }
            if i == avatarURLs.count - 1 {
                for sub in subviews.reversed() { self.bringSubviewToFront(sub) }
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        layer.cornerRadius = 2
        clipsToBounds = true
        contentMode = .scaleAspectFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func removeFromSuperview() {
        super.removeFromSuperview()
        imageManager.cancelAll()
    }
}

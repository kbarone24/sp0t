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
    lazy var imageManager = SDWebImageManager()
    var backgroundView: UIView!
        
    func setUp(avatarURLs: [String], annotation: Bool, completion: @escaping(_ success: Bool) -> Void) {
        backgroundColor = .clear
        layer.cornerRadius = 2
        clipsToBounds = true
        contentMode = .scaleAspectFill
        
        /// background view will slide with even # of images to center the view
        backgroundView = UIView {
            $0.backgroundColor = .clear
            addSubview($0)
        }
        let even = avatarURLs.count % 2 == 0
        if annotation { addBackgroundFrame(even: even) } else { makeBackgroundConstraints(even: even) }

        let transformer = SDImageResizingTransformer(size: CGSize(width: 69.4, height: 100), scaleMode: .aspectFit)
        var offset: CGFloat = 0
        var count = 0
        if avatarURLs.count == 0 { completion(false); return }
        for i in 0...avatarURLs.count - 1 {
            let imageView = AvatarImageView {
                $0.contentMode = .scaleAspectFill
                backgroundView.insertSubview($0, at: 0)
            }
            if annotation { imageView.addFrame(offset: offset, width: backgroundView.bounds.width) } else { imageView.makeConstraints(offset: offset) }

            offset = CGFloat(i/2) * 13 + 13
            if i % 2 != 0 { offset = -offset }
            
            SDWebImageManager.shared.loadImage(with: URL(string: avatarURLs[i]), options: [.highPriority, .scaleDownLargeImages], context: [.imageTransformer: transformer], progress: nil) { (rawImage, data, err, cache, download, url) in
                imageView.image = rawImage ?? UIImage()
                count += 1
                if count == avatarURLs.count { completion(true); return }
            }
        }
    }
        
    override func removeFromSuperview() {
        super.removeFromSuperview()
        imageManager.cancelAll()
    }
    
    func addBackgroundFrame(even: Bool) {
        let width = even ? 61 : 74
        backgroundView.frame = CGRect(x: 0, y: 0, width: width, height: 38)
    }
    
    func makeBackgroundConstraints(even: Bool) {
        let inset: CGFloat = even ? 13 : 0
        backgroundView.snp.makeConstraints {
            $0.top.bottom.leading.equalToSuperview()
            $0.trailing.equalToSuperview().inset(inset)
        }
    }
}

class AvatarImageView: UIImageView {
    func makeConstraints(offset: CGFloat) {
        snp.makeConstraints {
            $0.width.equalTo(26)
            $0.height.equalTo(37.5)
            $0.centerY.equalToSuperview()
            $0.centerX.equalToSuperview().offset(offset)
        }
    }
    func addFrame(offset: CGFloat, width: CGFloat) {
        frame = CGRect(x: (width - 26)/2 + offset, y: 0, width: 26, height: 37.5)
    }
}

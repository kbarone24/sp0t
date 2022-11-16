//
//  RightAlignedAvatarView.swift
//  Spot
//
//  Created by Kenny Barone on 9/20/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import FirebaseUI
import Foundation
import UIKit

class RightAlignedAvatarView: UIView {
    lazy var imageManager = SDWebImageManager()

    func setUp(avatarURLs: [String], annotation: Bool, completion: @escaping(_ success: Bool) -> Void) {
        backgroundColor = .clear
        layer.cornerRadius = 2
        clipsToBounds = true
        contentMode = .scaleAspectFill

        let avatarURLs = avatarURLs.prefix(5)
        let transformer = SDImageResizingTransformer(size: CGSize(width: 69.4, height: 100), scaleMode: .aspectFit)
        var offset: CGFloat = 26
        var count = 0
        if avatarURLs.count == 0 { completion(false); return }
        for i in 0...avatarURLs.count - 1 {
            let imageView = AvatarImageView {
                $0.frame = CGRect(x: bounds.width - offset, y: 0, width: 26, height: 37.5)
                $0.contentMode = .scaleAspectFill
                insertSubview($0, at: 0)
            }
            offset += 16.45

            SDWebImageManager.shared.loadImage(with: URL(string: avatarURLs[i]), options: [.highPriority, .scaleDownLargeImages], context: [.imageTransformer: transformer], progress: nil) { (rawImage, _, _, _, _, _) in
                imageView.image = rawImage ?? UIImage()
                count += 1
                if count == avatarURLs.count { completion(true); return }
            }
        }
    }
}

//
//  UIImageExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/19/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

extension UIImage {
    /// https://stackoverflow.com/questions/26542035/create-uiimage-with-solid-color-in-swift
    convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }

    func alpha(_ a: CGFloat) -> UIImage {
        return UIGraphicsImageRenderer(size: size, format: imageRendererFormat).image { (_) in
            draw(in: CGRect(origin: .zero, size: size), blendMode: .normal, alpha: a)
        }
    }

    func aspectRatio() -> CGFloat {
        return size.height / size.width
    }

    func resize(scaledToFill size: CGSize) -> UIImage? {
        let scale: CGFloat = max(size.width / (self.size.width), size.height / (self.size.height))
        let width: CGFloat = round((self.size.width) * scale)
        let height: CGFloat = round((self.size.height) * scale)
        let imageRect = CGRect(x: (size.width - width) / 2.0 - 1.0, y: (size.height - height) / 2.0 - 1.5, width: width + 2.0, height: height + 3.0)

        // if image rect size > image size, make them the same?
        let clipSize = CGSize(width: floor(size.width), height: floor(size.height)) /// fix rounding error for images taken from camera
        UIGraphicsBeginImageContextWithOptions(clipSize, false, 0.0)

        draw(in: imageRect)

        let newImage: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
}

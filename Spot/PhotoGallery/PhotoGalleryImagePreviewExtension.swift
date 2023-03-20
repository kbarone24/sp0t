//
//  PhotoGalleryImagePreviewExtension.swift
//  Spot
//
//  Created by Kenny Barone on 11/1/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

extension PhotoGalleryController: ImagePreviewDelegate {
    func select(galleryIndex: Int) {
        select(index: galleryIndex)
    }

    func deselect(galleryIndex: Int) {
        deselect(index: galleryIndex)
    }
}

extension PhotoGalleryController {
    func addPreviewView(object: ImageObject, galleryIndex: Int) {
        // add ImagePreviewView over top of gallery
        Mixpanel.mainInstance().track(event: "GalleryPreviewTap")
        guard let cell = collectionView.cellForItem(at: IndexPath(row: galleryIndex, section: 0)) as? GalleryCell else { return }

        imagePreview = ImagePreviewView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: UIScreen.main
            .bounds.height))
        imagePreview.backgroundColor = .blue
        imagePreview.delegate = self
        imagePreview.alpha = 0

        if let window = UIApplication.shared.keyWindow {
            window.addSubview(imagePreview)
            let frame = cell.superview?.convert(cell.frame, to: nil) ?? CGRect()
            imagePreview.imageExpand(originalFrame: frame, selectedIndex: 0, galleryIndex: galleryIndex, imageObjects: [object])
        }
    }

    func removePreviews() {
        // remove saved images from image objects to avoid memory pile up
        if imagePreview.selectedIndex == 0 {
            if let i = UploadPostModel.shared.imageObjects.firstIndex(where: { $0.0.id == imagePreview.imageObjects.first?.id }) {
                UploadPostModel.shared.imageObjects[i].0.animationImages.removeAll()
                UploadPostModel.shared.imageObjects[i].0.stillImage = UIImage()
            }
        }

        for sub in imagePreview.subviews { sub.removeFromSuperview() }
        imagePreview.removeFromSuperview()
    }
}

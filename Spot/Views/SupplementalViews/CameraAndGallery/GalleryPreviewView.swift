//
//  GalleryPreviewView.swift
//  Spot
//
//  Created by Kenny Barone on 7/5/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel
import Photos

class GalleryPreviewView: UIView {
    
    var imageView: UIImageView!
    var imageMask: UIView!
    var selectButton: UIButton!
    var aliveToggle: UIButton!
    
    var circleView: CircleView!
    var imageObject: ImageObject!
    var selectedIndex = 0
    var galleryIndex = 0
    
    unowned var upload: UploadPostController!
    unowned var picker: PhotoGalleryPicker!
    unowned var cluster: ClusterPickerController!
    
    lazy var imageFetcher = ImageFetcher()
    var activityIndicator: CustomActivityIndicator!
    var asset: PHAsset!
    
    deinit {
        imageFetcher.cancelFetchForAsset(asset: asset) /// cancel gif fetch
        imageView.animationImages?.removeAll() /// cancels animation
    }
    
    func setUp(object: ImageObject, selectedIndex: Int, galleryIndex: Int) {
        
        Mixpanel.mainInstance().track(event: "GalleryPreviewOpen")
        asset = object.asset
        
        backgroundColor = UIColor(named: "SpotBlack")
        layer.cornerRadius = 9
        layer.masksToBounds = true
        
        self.selectedIndex = selectedIndex
        self.imageObject = object
        self.galleryIndex = galleryIndex
                
        if imageView != nil { imageView.image = UIImage(); imageView.animationImages?.removeAll() }
        imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height))
        imageView.layer.cornerRadius = 9
        
        if imageObject.animationImages.isEmpty { imageObject.gifMode = false }
        let images = imageObject.gifMode ? imageObject.animationImages : [imageObject.stillImage]
        let aspect = images.first!.size.height / images.first!.size.width
        imageView.contentMode = aspect > 1.3 ? .scaleAspectFill : .scaleAspectFit
        addSubview(imageView)

        if imageObject.gifMode {
            imageView.animationImages = images
            /// only animate for active index
            if frame.minX == 25 { imageView.animateGIF(directionUp: true, counter: 0, frames: images.count, alive: false) } else { imageView.image = images.first! }
            
        } else {
            imageView.image = images.first!
        }
        
        if aspect > 1.1 { imageView.addBottomMask() }

        if selectButton != nil { selectButton.setTitle("", for: .normal) }
        selectButton = UIButton(frame: CGRect(x: bounds.width - 168, y: bounds.height - 51, width: 120, height: 40))
        let title = selectedIndex > 0 ? "Selected" : "Select"
        selectButton.setTitle(title, for: .normal)
        selectButton.titleEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        selectButton.contentHorizontalAlignment = .right
        selectButton.contentVerticalAlignment = .center
        selectButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 18)
        selectButton.setTitleColor(.white, for: .normal)
        selectButton.addTarget(self, action: #selector(circleTap(_:)), for: .touchUpInside)
        addSubview(selectButton)
        
        if circleView != nil { for sub in circleView.subviews { sub.removeFromSuperview()}; circleView = CircleView() }
        circleView = CircleView(frame: CGRect(x: bounds.width - 47, y: bounds.height - 46, width: 30, height: 30))
        let index = selectedIndex
        circleView.setUp(index: index)
        addSubview(circleView)
        
        let circleButton = UIButton(frame: CGRect(x: bounds.width - 52, y: bounds.height - 51, width: 46, height: 46))
        circleButton.addTarget(self, action: #selector(circleTap(_:)), for: .touchUpInside)
        addSubview(circleButton)
        
        if imageObject.asset.mediaSubtypes.contains(.photoLive) {
            if aliveToggle != nil { aliveToggle.setImage(UIImage(), for: .normal) }
            aliveToggle = UIButton(frame: CGRect(x: 5.7, y: self.bounds.height - 56, width: 94, height: 53))
            /// 74 x 33
            let image = imageObject.gifMode ? UIImage(named: "AliveOn") : UIImage(named: "AliveOff")
            aliveToggle.setImage(image, for: .normal)
            aliveToggle.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            aliveToggle.addTarget(self, action: #selector(toggleAlive(_:)), for: .touchUpInside)
            addSubview(aliveToggle)
            
            activityIndicator = CustomActivityIndicator(frame: CGRect(x: 18, y: bounds.height - 240, width: 30, height: 30))
            activityIndicator.isHidden = true
            addSubview(activityIndicator)
        }
    }
    
    @objc func circleTap(_ sender: UIButton) {

        let selected = selectedIndex == 0
        let text = selected ? "Selected" : "Select"
        
        Mixpanel.mainInstance().track(event: "GalleryPreviewToggle", properties: ["selected": selected])
        
        selectButton.setTitle(text, for: .normal)
        
        if picker != nil {
            selected ? picker.select(index: galleryIndex, circleTap: true) : picker.deselect(index: galleryIndex, circleTap: true)
            selectedIndex = selected ? UploadImageModel.shared.selectedObjects.count : 0
            
        } else if cluster != nil {
            selected ? cluster.select(index: galleryIndex, circleTap: true) : cluster.deselect(index: galleryIndex, circleTap: true)
            selectedIndex = selected ? UploadImageModel.shared.selectedObjects.count : 0
            
        } else if upload != nil {
            selectedIndex = selected ? UploadImageModel.shared.selectedObjects.count + 1 : 0 /// do first to account for animation
            selected ? upload.selectImage(cellIndex: galleryIndex, galleryIndex: galleryIndex, circleTap: true) : upload.deselectImage(index: galleryIndex, circleTap: true)
        }
                
        for sub in circleView.subviews { sub.removeFromSuperview() }
        circleView.setUp(index: selectedIndex)
        addSubview(circleView)
    }
    
    @objc func toggleAlive(_ sender: UIButton) {
                        
        imageObject.gifMode = !imageObject.gifMode
        
        Mixpanel.mainInstance().track(event: "GalleryToggleAlive", properties: ["on": imageObject.gifMode])

        let image = imageObject.gifMode ? UIImage(named: "AliveOn") : UIImage(named: "AliveOff")
        aliveToggle.setImage(image, for: .normal)
        
        if imageObject.gifMode {
            
            aliveToggle.isHidden = true
            activityIndicator.startAnimating()
            
            /// download alive if available and not yet downloaded
            imageFetcher.fetchLivePhoto(currentAsset: imageObject.asset, animationImages: imageObject.animationImages) { [weak self] animationImages, failed in

                guard let self = self else { return }
                
                self.activityIndicator.stopAnimating()
                self.aliveToggle.isHidden = false
                
                self.imageObject.animationImages = animationImages
                
                /// animate with gif images
                self.imageView.animationImages = self.imageObject.animationImages
                self.imageView.animateGIF(directionUp: true, counter: 0, frames: self.imageObject.animationImages.count, alive: false)
                self.updateParent()
                ///fetch image is async so need to make sure another image wasn't appended while this one was being fetched
            }

        } else {
            /// remove to stop animation and set to still image
         ///   imageView.isHidden = true
            imageView.image = imageObject.stillImage
            imageView.animationImages?.removeAll()
            updateParent()
        }
    }
    
    func updateParent() {
        
        if picker != nil {
            UploadImageModel.shared.imageObjects[galleryIndex].image.gifMode = imageObject.gifMode
            UploadImageModel.shared.imageObjects[galleryIndex].image.animationImages = imageObject.animationImages
            if selectedIndex > 0 { UploadImageModel.shared.selectedObjects[selectedIndex - 1].gifMode = imageObject.gifMode } /// adjust selected objects if object was selected
            
        } else if cluster != nil {
            cluster.imageObjects[galleryIndex].image.gifMode = imageObject.gifMode
            cluster.imageObjects[galleryIndex].image.animationImages = imageObject.animationImages
            if selectedIndex > 0 { UploadImageModel.shared.selectedObjects[selectedIndex - 1].gifMode = imageObject.gifMode } /// adjust selected objects if object was selected
            
        } else if upload != nil {
            UploadImageModel.shared.scrollObjects[galleryIndex].gifMode = imageObject.gifMode
            UploadImageModel.shared.scrollObjects[galleryIndex].animationImages = imageObject.animationImages
        }
    }
}

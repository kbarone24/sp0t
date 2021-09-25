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

class GalleryPreviewView: UIView {
    
    var imageView: UIImageView!
    var imageMask: UIView!
    var selectButton: UIButton!
    var aliveToggle: UIButton!
    
    var circleView: CircleView!
    var object: ImageObject!
    var selectedIndex = 0
    var galleryIndex = 0
    
    unowned var upload: UploadPostController!
    unowned var picker: PhotoGalleryPicker!
    unowned var cluster: ClusterPickerController!
    
    func setUp(object: ImageObject, selectedIndex: Int, galleryIndex: Int) {
        
        Mixpanel.mainInstance().track(event: "GalleryPreviewOpen")
        
        backgroundColor = UIColor(named: "SpotBlack")
        layer.cornerRadius = 9
        layer.masksToBounds = true
        
        self.selectedIndex = selectedIndex
        self.object = object
        self.galleryIndex = galleryIndex
                
        if imageView != nil { imageView.image = UIImage(); imageView.animationImages?.removeAll() }
        imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height))
        imageView.layer.cornerRadius = 9
        
        let images = !object.gifMode ? [object.stillImage] : object.animationImages
        let aspect = images.first!.size.height / images.first!.size.width
        imageView.contentMode = aspect > 1.3 ? .scaleAspectFill : .scaleAspectFit
        addSubview(imageView)

        if !object.gifMode {
            imageView.image = images.first!
            
        } else {
            imageView.animationImages = images
            /// only animate for active index
            if frame.minX == 25 { imageView.animateGIF(directionUp: true, counter: 0, frames: images.count, alive: false) } else { imageView.image = images.first! }
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
        
        if !object.animationImages.isEmpty {
            if aliveToggle != nil { aliveToggle.setImage(UIImage(), for: .normal) }
            aliveToggle = UIButton(frame: CGRect(x: 5.7, y: self.bounds.height - 56, width: 94, height: 53))
            /// 74 x 33
            let image = object.gifMode ? UIImage(named: "AliveOn") : UIImage(named: "AliveOff")
            aliveToggle.setImage(image, for: .normal)
            aliveToggle.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            aliveToggle.addTarget(self, action: #selector(toggleAlive(_:)), for: .touchUpInside)
            addSubview(aliveToggle)
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
            selected ? upload.selectImage(index: galleryIndex, circleTap: true) : upload.deselectImage(index: galleryIndex, circleTap: true)
        }
                
        for sub in circleView.subviews { sub.removeFromSuperview() }
        circleView.setUp(index: selectedIndex)
        addSubview(circleView)
    }
    
    @objc func toggleAlive(_ sender: UIButton) {
                
        object.gifMode = !object.gifMode
        
        Mixpanel.mainInstance().track(event: "GalleryToggleAlive", properties: ["on": object.gifMode])

        let image = object.gifMode ? UIImage(named: "AliveOn") : UIImage(named: "AliveOff")
        aliveToggle.setImage(image, for: .normal)
        
        if object.gifMode {
            /// animate with gif images
            imageView.animationImages = object.animationImages
            imageView.animateGIF(directionUp: true, counter: 0, frames: object.animationImages.count, alive: false)
        } else {
            /// remove to stop animation and set to still image
         ///   imageView.isHidden = true
            imageView.image = object.stillImage
            imageView.animationImages?.removeAll()
        }
        
        if picker != nil {
            UploadImageModel.shared.imageObjects[galleryIndex].0.gifMode = object.gifMode
            if selectedIndex > 0 { UploadImageModel.shared.selectedObjects[selectedIndex - 1].gifMode = object.gifMode } /// adjust selected objects if object was selected
            
        } else if cluster != nil {
            cluster.imageObjects[galleryIndex].0.gifMode = object.gifMode
            if selectedIndex > 0 { UploadImageModel.shared.selectedObjects[selectedIndex - 1].gifMode = object.gifMode } /// adjust selected objects if object was selected
            
        } else if upload != nil {
            upload.scrollObjects[galleryIndex].imageObject.gifMode = object.gifMode
        }
    }
}

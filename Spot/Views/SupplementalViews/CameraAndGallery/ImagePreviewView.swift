//
//  ImagePreviewView.swift
//  Spot
//
//  Created by Kenny Barone on 11/8/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Photos
import Mixpanel

class ImagePreviewView: UIView, UIGestureRecognizerDelegate {
    
    var imageCloseTap: UITapGestureRecognizer!
    var maskImage: ImagePreview!
    var maskImagePrevious: ImagePreview!
    var maskImageNext: ImagePreview!
    
    var imageObjects: [ImageObject] = []
    var galleryIndex = 0
    var selectedIndex = 0
    var originalFrame: CGRect!
    
    var landscape = false
    var alive = false
    var zooming = false
    var originalCenter: CGPoint!
    
    unowned var imagesCollection, galleryCollection: UICollectionView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("preview deinit")
    }
    
    func expand(originalFrame: CGRect, selectedIndex: Int, galleryIndex: Int, imageObjects: [ImageObject]) {
        
        self.originalFrame = originalFrame
        self.selectedIndex = selectedIndex
        self.galleryIndex = galleryIndex
        self.imageObjects = imageObjects

        imageCloseTap = UITapGestureRecognizer(target: self, action: #selector(closeImageExpand(_:)))
        imageCloseTap.delegate = self
        addGestureRecognizer(imageCloseTap)
        
        let currentObject = imageObjects[selectedIndex]
        maskImage = ImagePreview(frame: originalFrame)
        maskImage.image = currentObject.stillImage
        addSubview(maskImage)
        maskImage.setUp(imageObject: imageObjects[selectedIndex])
        
        maskImage.enableZoom()
        
        if imageObjects.count > 1 {
            
            let pan = UIPanGestureRecognizer(target: self, action: #selector(imageSwipe(_:)))
            pan.delegate = self
            maskImage.addGestureRecognizer(pan)
            
            maskImagePrevious = ImagePreview(frame: originalFrame)
            addSubview(maskImagePrevious)
            
            maskImageNext = ImagePreview(frame: originalFrame)
            addSubview(maskImageNext)
            
            setImageBounds(first: true, selectedIndex: selectedIndex)
        }
        
        let maskAspect = min(currentObject.stillImage.size.height/currentObject.stillImage.size.width, 1.5)
        let maskHeight = maskAspect * UIScreen.main.bounds.width
        let maskY = 20 + (UIScreen.main.bounds.height - maskHeight - 40)/2

        /// animate image preview expand -> use scale aspect fill at first for smooth animation then aspect fit within larger image frame
        UIView.animate(withDuration: 0.25) {
            self.alpha = 1.0 /// animate mask appearing
            let finalRect = CGRect(x: 0, y: maskY, width: UIScreen.main.bounds.width, height: maskHeight)
            self.maskImage.frame = finalRect
            if self.maskImage.aliveToggle != nil { self.maskImage.aliveToggle.frame = CGRect(x: 4, y: finalRect.height - 57, width: 79.4, height: 52.67) }
            if self.maskImage.circleView != nil { self.maskImage.circleView.frame = CGRect(x: finalRect.maxX - 47, y: finalRect.height - 51, width: 30, height: 30) }
            if self.maskImage.selectButton != nil { self.maskImage.selectButton.frame = CGRect(x: finalRect.maxX - 168, y: finalRect.height - 56, width: 120, height: 40) }
            
        } completion: { [weak self] _ in
            guard let self = self else { return }
            self.maskImage.setUp(imageObject: imageObjects[selectedIndex])
        }
    }
    
    func setImageBounds(first: Bool, selectedIndex: Int) {
        
        let sameIndex = selectedIndex == self.selectedIndex
        self.selectedIndex = selectedIndex
        
        let maskHeight: CGFloat = UIScreen.main.bounds.width * 1.5
        let maskY = 20 + (UIScreen.main.bounds.height - maskHeight - 40)/2

        if !first {
            let selectedObject = imageObjects[selectedIndex]
                        
            maskImage.frame = CGRect(x: 0, y: maskY, width: UIScreen.main.bounds.width, height: maskHeight)
            maskImage.setUp(imageObject: selectedObject)
            let selectedImage = selectedObject.stillImage
            if !sameIndex && !first { maskImage.image = selectedImage } /// avoid resetting image while animation is happening
        }
        
        if imageObjects.count > 1 {
            
            maskImagePrevious.frame = CGRect(x: -UIScreen.main.bounds.width, y: maskY, width: UIScreen.main.bounds.width, height: maskHeight)
            maskImagePrevious.image = UIImage()
            if selectedIndex > 0 {
                maskImagePrevious.setUp(imageObject: imageObjects[selectedIndex - 1])
            }

            maskImageNext.frame = CGRect(x: UIScreen.main.bounds.width, y: maskY, width: UIScreen.main.bounds.width, height: maskHeight)
            maskImageNext.image = UIImage()
            if selectedIndex < imageObjects.count - 1 {
                maskImageNext.setUp(imageObject: imageObjects[selectedIndex + 1])
            }
        }
    }
    
    @objc func imageSwipe(_ gesture: UIPanGestureRecognizer) {
        
        if maskImage.zooming { return }
        
        let direction = gesture.velocity(in: self)
        let translation = gesture.translation(in: self)
        
        switch gesture.state {
            
        case .changed:
            
            maskImage.frame = CGRect(x:translation.x, y: maskImage.frame.minY, width: maskImage.frame.width, height: maskImage.frame.height)
            maskImageNext.frame = CGRect(x: UIScreen.main.bounds.width + translation.x, y: maskImageNext.frame.minY, width: maskImageNext.frame.width, height: maskImageNext.frame.height)
            maskImagePrevious.frame = CGRect(x: -UIScreen.main.bounds.width + translation.x, y: maskImagePrevious.frame.minY, width: maskImagePrevious.frame.width, height: maskImagePrevious.frame.height)
            
        case .ended:
            
            /// image swipe from portrait orientation
            
            if direction.x < 0  {
                if maskImage.frame.maxX + direction.x < UIScreen.main.bounds.width/2 && selectedIndex < imageObjects.count - 1 {
                    //animate to next image
                    UIView.animate(withDuration: 0.2) {
                        self.maskImageNext.frame = CGRect(x: 0, y: self.maskImageNext.frame.minY, width: self.maskImageNext.frame.width, height: self.maskImageNext.frame.height)
                        self.maskImage.frame = CGRect(x: -UIScreen.main.bounds.width, y: self.maskImage.frame.minY, width: self.maskImage.frame.width, height: self.maskImage.frame.height)
                        self.maskImagePrevious.frame = CGRect(x: -UIScreen.main.bounds.width, y: self.maskImagePrevious.frame.minY, width: self.maskImagePrevious.frame.width, height: self.maskImagePrevious.frame.height)
                    }
                    
                    /// remove animation images early for smooth swiping
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { [weak self] in
                        guard let self = self else { return }
                        self.maskImage.animationImages?.removeAll()
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        guard let self = self else { return }
                        self.setImageBounds(first: false, selectedIndex: self.selectedIndex + 1)
                        if self.imagesCollection != nil { self.imagesCollection.scrollToItem(at: IndexPath(row: self.selectedIndex, section: 0), at: .left, animated: false)}
                        return
                    }
                } else {
                    //return to original state
                    UIView.animate(withDuration: 0.2) { self.setImageBounds(first: false, selectedIndex: self.selectedIndex) }
                }
                
            } else {
                if maskImage.frame.minX + direction.x > UIScreen.main.bounds.width/2 && selectedIndex > 0 {
                    //animate to previous image
                    UIView.animate(withDuration: 0.2) {
                        self.maskImagePrevious.frame = CGRect(x: 0, y: self.maskImagePrevious.frame.minY, width: self.maskImagePrevious.frame.width, height: self.maskImagePrevious.frame.height)
                        self.maskImage.frame = CGRect(x: UIScreen.main.bounds.width, y: self.maskImage.frame.minY, width: self.maskImage.frame.width, height: self.maskImage.frame.height)
                        self.maskImageNext.frame = CGRect(x: UIScreen.main.bounds.width, y: self.maskImageNext.frame.minY, width: self.maskImageNext.frame.width, height: self.maskImageNext.frame.height)
                    }
                    
                    /// remove animation images early for smooth swiping
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { [weak self] in
                        guard let self = self else { return }
                        self.maskImage.animationImages?.removeAll()
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        guard let self = self else { return }
                        self.setImageBounds(first: false, selectedIndex: self.selectedIndex - 1)
                        if self.imagesCollection != nil { self.imagesCollection.scrollToItem(at: IndexPath(row: self.selectedIndex, section: 0), at: .left, animated: false)}
                        return
                    }
                } else {
                    //return to original state
                    UIView.animate(withDuration: 0.2) { self.setImageBounds(first: false, selectedIndex: self.selectedIndex)
                    }
                }
            }
            /// image swipe from counter clockwise landscape orientation
        default:
            return
        }
        
    }
    
    @objc func closeImageExpand(_ sender: UITapGestureRecognizer) {
        
        let selectedImage = imageObjects[selectedIndex].stillImage
        let maskAspect = min(selectedImage.size.height/selectedImage.size.width, 1.5)
        let maskHeight = maskAspect * UIScreen.main.bounds.width
        let maskY = 20 + (UIScreen.main.bounds.height - maskHeight - 40)/2
        
        DispatchQueue.main.async {
            
            self.maskImage.frame = CGRect(x: 0, y: maskY, width: UIScreen.main.bounds.width, height: maskHeight)
            var endFrame = self.originalFrame
            
            /// get updated frame (scroll objects resort)
            if self.imagesCollection != nil {
                guard let cell = self.imagesCollection.cellForItem(at: IndexPath(row: self.selectedIndex, section: 0)) as? SelectedImageCell else { return }
                endFrame = self.imagesCollection.convert(cell.frame, to: nil)
                self.imagesCollection.reloadData()
                
                /// unhide cancelbutton for smooth animation
                self.maskImage.cancelButton.alpha = 0.0
                self.maskImage.cancelButton.isHidden = false
                self.maskImage.cancelButton.frame = CGRect(x: endFrame!.width - 39, y: 4, width: 35, height: 35)
            } else {
                /// animate to gallery -> unhide circle for smooth animation
                self.maskImage.galleryCircle.alpha = 0.0
                self.maskImage.galleryCircle.isHidden = false
                self.maskImage.galleryCircle.frame = CGRect(x: endFrame!.width - 27, y: 6, width: 23, height: 23)
            }
            
            /// main animation
            UIView.animate(withDuration: 0.25) {
                self.maskImage.frame = endFrame ?? CGRect()
                
                /// set alive toggle to its height in the cell + adjust borders to fit original views
                if self.imagesCollection != nil {
                    if self.maskImage.aliveToggle != nil { self.maskImage.aliveToggle.frame = CGRect(x: -2, y: endFrame!.height - 44, width: 64, height: 46) }
                    self.maskImage.cancelButton.alpha = 1.0
                    self.maskImage.layer.cornerRadius = 9
                    self.maskImage.layer.cornerCurve = .continuous
                    
                } else {
                    self.maskImage.galleryCircle.alpha = 1.0
                    self.maskImage.layer.borderColor = UIColor(named: "SpotBlack")!.cgColor
                    self.maskImage.layer.borderWidth = 1
                }
            }
            
            /// background animation -> fade is only necessary for upload overview
            let duration: CGFloat = self.imagesCollection != nil ? 0.45 : 0.26
            UIView.animate(withDuration: duration) {
                self.backgroundColor = UIColor(named: "SpotBlack")!.withAlphaComponent(0.0)
                
            } completion: { [weak self] complete in
                guard let self = self else { return }
                for subview in self.subviews { subview.removeFromSuperview() }
                self.isHidden = true
                self.backgroundColor = UIColor(named: "SpotBlack")
                self.removeGestureRecognizer(self.imageCloseTap)
                self.maskImage = nil
                self.maskImageNext = nil
                self.maskImagePrevious = nil
                NotificationCenter.default.post(name: Notification.Name("PreviewRemove"), object: nil, userInfo: nil)
            }
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return !touch.view!.isKind(of: UIButton.self)
    }
}

class ImagePreview: UIImageView, UIGestureRecognizerDelegate {
    
    var contentView: UIView!
    var aliveToggle: UIButton!
    var circleView: CircleView!
    var imageMask: UIView!
    
    var selectButton: UIButton!
    var zooming = false
    var originalCenter: CGPoint!
    
    var cancelButton: UIButton!
    var galleryCircle: CircleView!
    
    var imageObject: ImageObject!
    lazy var activityIndicator = CustomActivityIndicator()
    lazy var imageFetcher = ImageFetcher()
    
    var circleIndex = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        tag = 85
        clipsToBounds = true
        isUserInteractionEnabled = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if imageObject != nil { imageFetcher.cancelFetchForAsset(asset: imageObject.asset) }
        imageFetcher = ImageFetcher()
    }
    
    func setUp(imageObject: ImageObject) {
        
        self.imageObject = imageObject
        image = imageObject.stillImage
        contentMode = .scaleAspectFill
        animationImages?.removeAll()
        
        if aliveToggle != nil { aliveToggle.setImage(UIImage(), for: .normal)}
        if imageMask != nil { imageMask.removeFromSuperview() }
        activityIndicator.removeFromSuperview()
                        
        if !imageObject.animationImages.isEmpty {
            animationImages = imageObject.animationImages
            if imageObject.gifMode { self.animateGIF(directionUp: true, counter: 0, frames: imageObject.animationImages.count, alive: false) }
        }
        
        contentView = UIView(frame: getTrueFrame())
        contentView.backgroundColor = nil
        addSubview(contentView)
        
        /// mask so can more clearly see toggle
       /* imageMask = UIView(frame: contentView.bounds)
        imageMask.backgroundColor = nil
        let layer0 = CAGradientLayer()
        layer0.frame = imageMask.bounds
        layer0.colors = [
            UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.01).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.06).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.23).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.5).cgColor
        ]
        layer0.locations = [0, 0.11, 0.33, 0.65, 1]
        layer0.startPoint = CGPoint(x: 0.5, y: 0)
        layer0.endPoint = CGPoint(x: 0.5, y: 1.0)
        imageMask.layer.addSublayer(layer0)
        contentView.addSubview(imageMask) */

        if self.imageObject.asset.mediaSubtypes.contains(.photoLive) {
            
            aliveToggle = UIButton(frame: CGRect(x: 4, y: contentView.frame.height - 57, width: 79.4, height: 52.67))
            let image = imageObject.gifMode ? UIImage(named: "AliveOn") : UIImage(named: "AliveOff")
            aliveToggle.imageView?.contentMode = .scaleAspectFit
            aliveToggle.contentHorizontalAlignment = .fill
            aliveToggle.contentVerticalAlignment = .fill
            aliveToggle.setImage(image, for: .normal)
            aliveToggle.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            aliveToggle.addTarget(self, action: #selector(toggleAlive(_:)), for: .touchUpInside)
            contentView.addSubview(aliveToggle)
            
            activityIndicator = CustomActivityIndicator(frame: CGRect(x: 14, y: contentView.frame.height - 273, width: 30, height: 30))
            activityIndicator.isHidden = true
            contentView.addSubview(activityIndicator)
        }
        
        guard let previewView = superview as? ImagePreviewView else { return }
        
        if previewView.galleryCollection != nil {
            
            var index = 0
            if let i = UploadImageModel.shared.selectedObjects.firstIndex(where: {$0.id == imageObject.id}) { index = i + 1; circleIndex = i + 1 }
            
            if selectButton != nil { selectButton.setTitle("", for: .normal) }
            selectButton = UIButton(frame: CGRect(x: contentView.frame.maxX - 168, y: contentView.frame.height - 56, width: 120, height: 40))
            let title = circleIndex > 0 ? "Selected" : "Select"
            selectButton.setTitle(title, for: .normal)
            selectButton.titleEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            selectButton.contentHorizontalAlignment = .right
            selectButton.contentVerticalAlignment = .center
            selectButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 18)
            selectButton.setTitleColor(.white, for: .normal)
            selectButton.addTarget(self, action: #selector(circleTap(_:)), for: .touchUpInside)
            contentView.addSubview(selectButton)
            
            circleView = CircleView(frame: CGRect(x: frame.maxX - 47, y: contentView.frame.height - 51, width: 30, height: 30))
            circleView.setUp(index: index)
            contentView.addSubview(circleView)
            
            let circleButton = UIButton(frame: CGRect(x: bounds.width - 52, y: contentView.frame.height - 56, width: 46, height: 46))
            circleButton.addTarget(self, action: #selector(circleTap(_:)), for: .touchUpInside)
            contentView.addSubview(circleButton)
            
            /// for animation back to gallery
            galleryCircle = CircleView(frame: CGRect(x: contentView.frame.width - 27, y: 6, width: 23, height: 23))
            galleryCircle.setUp(index: index)
            galleryCircle.isHidden = true
            contentView.addSubview(galleryCircle)
            
        } else {
            /// for animation back to upload
            cancelButton = UIButton(frame: CGRect(x: contentView.frame.width - 39, y: 4, width: 35, height: 35))
            cancelButton.setImage(UIImage(named: "CheckInX"), for: .normal)
            cancelButton.isHidden = true
            cancelButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            contentView.addSubview(cancelButton)
        }
    }
    
    @objc func toggleAlive(_ sender: UIButton) {
        
        imageObject.gifMode = !imageObject.gifMode
        
        Mixpanel.mainInstance().track(event: "MaskToggleAlive", properties: ["on": imageObject.gifMode])

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
                self.animationImages = self.imageObject.animationImages
                self.animateGIF(directionUp: true, counter: 0, frames: self.imageObject.animationImages.count, alive: false)
                self.updateParent()
                ///fetch image is async so need to make sure another image wasn't appended while this one was being fetched
            }

        } else {
            /// remove to stop animation and set to still image
         ///   imageView.isHidden = true
            self.image = imageObject.stillImage
            self.animationImages?.removeAll()
            updateParent()
        }
    }
    
    @objc func circleTap(_ sender: UIButton) {
        
        let selected = circleIndex == 0
        let text = selected ? "Selected" : "Select"
        selectButton.setTitle(text, for: .normal)
        
        Mixpanel.mainInstance().track(event: "GalleryPreviewToggle", properties: ["selected": selected])
        
        guard let previewView = superview as? ImagePreviewView else { return }
        
        // defer to gallery/cluster select methods
        if let gallery = previewView.galleryCollection.viewContainingController() as? PhotoGalleryPicker {
            selected ? gallery.select(index: previewView.galleryIndex, circleTap: true) : gallery.deselect(index: previewView.galleryIndex, circleTap: true)
            circleIndex = selected ? UploadImageModel.shared.selectedObjects.count : 0
            
        } else if let cluster = previewView.galleryCollection.viewContainingController() as? ClusterPickerController {
            selected ? cluster.select(index: previewView.galleryIndex, circleTap: true) : cluster.deselect(index: previewView.galleryIndex, circleTap: true)
            circleIndex = selected ? UploadImageModel.shared.selectedObjects.count : 0
        }
        
        for sub in circleView.subviews { sub.removeFromSuperview() }
        circleView.setUp(index: circleIndex)
    }
    
    func updateParent() {
        
        guard let previewView = superview as? ImagePreviewView else { return }
        previewView.imageObjects[previewView.selectedIndex].animationImages = imageObject.animationImages
        previewView.imageObjects[previewView.selectedIndex].gifMode = imageObject.gifMode
        
        /// update if selected in scrollObjects
        if let i = UploadImageModel.shared.scrollObjects.firstIndex(where: {$0.id == imageObject.id}) {
            UploadImageModel.shared.scrollObjects[i].animationImages = imageObject.animationImages
            UploadImageModel.shared.scrollObjects[i].gifMode = imageObject.gifMode
        }
        
        /// update in gallery / cluster
        if let i = UploadImageModel.shared.imageObjects.firstIndex(where: {$0.image.id == imageObject.id}) {
            UploadImageModel.shared.imageObjects[i].image.animationImages = imageObject.animationImages
            UploadImageModel.shared.imageObjects[i].image.gifMode = imageObject.gifMode
        }
    }
    
    func enableZoom() {
        
        isUserInteractionEnabled = true
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(zoom(_:)))
        pinchGesture.delegate = self
        addGestureRecognizer(pinchGesture)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
    }
    
    
    @objc func zoom(_ sender: UIPinchGestureRecognizer) {
        
        switch sender.state {
            
        case .began:
            zooming = true
            originalCenter = center
            
        case .changed:
            let pinchCenter = CGPoint(x: sender.location(in: self).x - self.bounds.midX,
                                      y: sender.location(in: self).y - self.bounds.midY)
            
            let transform = self.transform.translatedBy(x: pinchCenter.x, y: pinchCenter.y)
                .scaledBy(x: sender.scale, y: sender.scale)
                .translatedBy(x: -pinchCenter.x, y: -pinchCenter.y)
            
            let currentScale = self.frame.size.width / self.bounds.size.width
            var newScale = currentScale * sender.scale
            if newScale < 1 {
                newScale = 1
                let transform = CGAffineTransform(scaleX: newScale, y: newScale)
                self.transform = transform
                
            } else {
                self.transform = transform
                sender.scale = 1
            }
            
        case .ended, .cancelled, .failed:
            UIView.animate(withDuration: 0.3, animations: { [weak self] in
                
                guard let self = self else { return }
                self.center = self.originalCenter
                self.transform = CGAffineTransform.identity
            })
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [ weak self] in
                guard let self = self else { return }
                self.zooming = false
            }
            
        default: return
        }
    }
    
    @objc func pan(_ sender: UIPanGestureRecognizer) {
        
        if zooming && sender.state == .changed {
            let translation = sender.translation(in: self)
            let currentScale = self.frame.size.width / self.bounds.size.width
            self.center = CGPoint(x: self.center.x + (translation.x * currentScale), y: self.center.y + (translation.y * currentScale))
            sender.setTranslation(CGPoint.zero, in: superview)
        }
    }
    
    /// source: https://medium.com/@jeremysh/instagram-pinch-to-zoom-pan-gesture-tutorial-772681660dfe
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer.view?.tag == 85 && otherGestureRecognizer.view?.tag == 85 /// only user for postImage zoom / swipe
    }
        
    func getTrueFrame() -> CGRect {
      //  let maskAspect = min(imageObject.stillImage.size.height/imageObject.stillImage.size.width, 1.5)
       // let maskHeight = maskAspect * UIScreen.main.bounds.width
        return CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
    }
}

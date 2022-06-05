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
        Mixpanel.mainInstance().track(event: "ImagePreviewOpen", properties: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func imageExpand(originalFrame: CGRect, selectedIndex: Int, galleryIndex: Int, imageObjects: [ImageObject]) {
        
        self.originalFrame = originalFrame
        self.selectedIndex = selectedIndex
        self.galleryIndex = galleryIndex
        self.imageObjects = imageObjects

        imageCloseTap = UITapGestureRecognizer(target: self, action: #selector(closeImageTap(_:)))
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
            if self.maskImage.aliveToggle != nil { self.maskImage.aliveToggle.frame = CGRect(x: 7, y: finalRect.height - 54, width: 74, height: 46) }
            if self.maskImage.circleView != nil { self.maskImage.circleView.frame = CGRect(x: finalRect.maxX - 52, y: finalRect.height - 53, width: 40, height: 40); self.maskImage.circleView.number.frame = CGRect(x: 0, y: self.maskImage.circleView.bounds.height/2 - 15/2, width: self.maskImage.circleView.bounds.width, height: 15) }
            if self.maskImage.selectButton != nil { self.maskImage.selectButton.frame = CGRect(x: finalRect.maxX - 150, y: finalRect.height - 54, width: 98, height: 43) }

        } completion: { [weak self] _ in
            guard let self = self else { return }
            self.maskImage.setUp(imageObject: imageObjects[selectedIndex])
        }
    }
    
    func setImageBounds(first: Bool, selectedIndex: Int) {
        
        self.selectedIndex = selectedIndex

        if !first {
            let selectedObject = imageObjects[selectedIndex]
            
            let maskAspect = min(selectedObject.stillImage.size.height/selectedObject.stillImage.size.width, 1.5)
            let maskHeight = maskAspect * UIScreen.main.bounds.width
            let maskY = 20 + (UIScreen.main.bounds.height - maskHeight - 40)/2

            maskImage.frame = CGRect(x: 0, y: maskY, width: UIScreen.main.bounds.width, height: maskHeight)
            maskImage.setUp(imageObject: selectedObject)
        }
        
        if imageObjects.count > 1 {
            
            /// blank frame or use filled aspect ratio of next object
            let pAspect = selectedIndex > 0 ? min(imageObjects[selectedIndex - 1].stillImage.size.height/imageObjects[selectedIndex - 1].stillImage.size.width, 1.5) : 1.5
            let pHeight = pAspect * UIScreen.main.bounds.width
            let py = 20 + (UIScreen.main.bounds.height - pHeight - 40)/2

            maskImagePrevious.frame = CGRect(x: -UIScreen.main.bounds.width, y: py, width: UIScreen.main.bounds.width, height: pHeight)
            maskImagePrevious.image = UIImage()
            
            if selectedIndex > 0 {
                maskImagePrevious.setUp(imageObject: imageObjects[selectedIndex - 1])
            }
            
            let nAspect = selectedIndex < imageObjects.count - 1 ? min(imageObjects[selectedIndex + 1].stillImage.size.height/imageObjects[selectedIndex + 1].stillImage.size.width, 1.5) : 1.5
            let nHeight = nAspect * UIScreen.main.bounds.width
            let ny = 20 + (UIScreen.main.bounds.height - nHeight - 40)/2

            maskImageNext.frame = CGRect(x: UIScreen.main.bounds.width, y: ny, width: UIScreen.main.bounds.width, height: nHeight)
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
                        self.setAnimationIndex(newIndex: self.selectedIndex + 1)
                        self.setImageBounds(first: false, selectedIndex: self.selectedIndex + 1)
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
                        self.setAnimationIndex(newIndex: self.selectedIndex - 1)
                        self.setImageBounds(first: false, selectedIndex: self.selectedIndex - 1)
                        return
                    }
                } else {
                    //return to original state
                    UIView.animate(withDuration: 0.2) { self.setImageBounds(first: false, selectedIndex: self.selectedIndex)
                    }
                }
            }

        default:
            return
        }
        
    }
    
    // set animationIndex to maintain animation state on image swipe
    func setAnimationIndex(newIndex: Int) {
         imageObjects[newIndex].animationIndex = newIndex > selectedIndex ? maskImageNext.animationIndex : maskImagePrevious.animationIndex
        imageObjects[newIndex].directionUp = newIndex > selectedIndex ? maskImageNext.directionUp : maskImagePrevious.directionUp
    }
    
    @objc func closeImageTap(_ sender: UITapGestureRecognizer) {
        if maskImage.imageFetcher.isFetching { maskImage.cancelImageFetch(); return }
        closeImageExpand()
    }
    
    func closeImageExpand() {
        
        let selectedImage = imageObjects[selectedIndex].stillImage
        let maskAspect = min(selectedImage.size.height/selectedImage.size.width, 1.5)
        let maskHeight = maskAspect * UIScreen.main.bounds.width
        let maskY = 20 + (UIScreen.main.bounds.height - maskHeight - 40)/2
        
        DispatchQueue.main.async {
            
            self.maskImage.frame = CGRect(x: 0, y: maskY, width: UIScreen.main.bounds.width, height: maskHeight)
            var endFrame = self.originalFrame ?? CGRect()
            var imageRemoved = false
            
            if self.imagesCollection != nil {
                /// animate to center of screen if selected
                if self.maskImage.circleIndex > 0 { endFrame = CGRect(x: (UIScreen.main.bounds.width - endFrame.width)/2, y: (UIScreen.main.bounds.height/2 - endFrame.height)/2, width: endFrame.width, height: endFrame.height); imageRemoved = true }
            }
            
            self.maskImage.galleryCircle.alpha = 0.0
            self.maskImage.galleryCircle.isHidden = false
            if self.maskImage.circleView != nil { self.maskImage.circleView.isHidden = true }
            if self.maskImage.selectButton != nil { self.maskImage.selectButton.isHidden = true }
            if self.maskImage.aliveToggle != nil { self.maskImage.aliveToggle.isHidden = true }
            
            /// main animation
            UIView.animate(withDuration: 0.25) {
                
                self.maskImage.frame = endFrame
                
                /// set alive toggle to its height in the cell + adjust borders to fit original views
                if self.imagesCollection != nil {
                    self.maskImage.layer.cornerRadius = 8
                    self.maskImage.layer.cornerCurve = .continuous
                    
                } else {
                    self.maskImage.galleryCircle.alpha = 1.0
                    self.maskImage.galleryCircle.frame = CGRect(x: endFrame.width - 27, y: 6, width: 23, height: 23)
                    self.maskImage.layer.borderColor = UIColor(named: "SpotBlack")!.cgColor
                    self.maskImage.layer.borderWidth = 1
                }
            }
            
            /// background animation -> fade is only necessary for upload overview
            let duration: CGFloat = 0.26
            UIView.animate(withDuration: duration) {
                self.backgroundColor = UIColor(named: "SpotBlack")!.withAlphaComponent(0.0)
                if imageRemoved { self.alpha = 0.0 }
                
            } completion: { [weak self] complete in
                guard let self = self else { return }
                for subview in self.subviews { subview.removeFromSuperview() }
                self.isHidden = true
                self.backgroundColor = UIColor(named: "SpotBlack")
                self.removeGestureRecognizer(self.imageCloseTap)
                Mixpanel.mainInstance().track(event: "ImagePreviewClose", properties: nil)
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
    lazy var activityIndicator = UIActivityIndicatorView()
    lazy var imageFetcher = ImageFetcher()
    
    var circleIndex = 0
    var animationIndex = 0
    var directionUp = true
    
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
        if !imageObject.gifMode { image = imageObject.stillImage }
        contentMode = .scaleAspectFill
        
        if aliveToggle != nil { aliveToggle.setImage(UIImage(), for: .normal)}
        if imageMask != nil { imageMask.removeFromSuperview() }
        activityIndicator.removeFromSuperview()
        
        let animating = !(animationImages?.isEmpty ?? true)
        animationImages = imageObject.animationImages
        animationIndex = imageObject.animationIndex
        
        /// only animate if not already animating + if this is maskImage
        if imageObject.gifMode && !animating {
            self.animatePreviewGif()
        }
        
        contentView = UIView(frame: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        contentView.backgroundColor = nil
        addSubview(contentView)
        
        guard let previewView = superview as? ImagePreviewView else { return }

        /// scale button as frame expands
        let galleryAnimation = contentView.bounds.width < 150 && previewView.galleryCollection != nil
        if self.imageObject.asset.mediaSubtypes.contains(.photoLive) {
            
            if aliveToggle != nil { aliveToggle.setImage(UIImage(), for: .normal)}
            let aliveFrame = galleryAnimation ? CGRect(x: 0, y: contentView.frame.height - 19.5, width: 24, height: 19.5) : CGRect(x: 7, y: contentView.frame.height - 54, width: 74, height: 46)
            aliveToggle = UIButton(frame: aliveFrame)
            let image = imageObject.gifMode ? UIImage(named: "AliveOn") : UIImage(named: "AliveOff")
            aliveToggle.imageView?.contentMode = .scaleAspectFit
            aliveToggle.contentHorizontalAlignment = .fill
            aliveToggle.contentVerticalAlignment = .fill
            aliveToggle.setImage(image, for: .normal)
            aliveToggle.imageEdgeInsets = UIEdgeInsets(top: 7, left: 7, bottom: 7, right: 7)
            aliveToggle.addTarget(self, action: #selector(toggleAlive(_:)), for: .touchUpInside)
            contentView.addSubview(aliveToggle)
            
            activityIndicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
            activityIndicator.isHidden = true
            activityIndicator.color = .white
            activityIndicator.transform = CGAffineTransform(scaleX: 2.5, y: 2.5)
            contentView.addSubview(activityIndicator)
        }
                
        var index = 0
        if let i = UploadPostModel.shared.selectedObjects.firstIndex(where: {$0.id == imageObject.id}) { index = i + 1; circleIndex = i + 1 }
        
        if selectButton != nil { selectButton.setImage(UIImage(), for: .normal) }
        let selectFrame = galleryAnimation ? CGRect(x: contentView.frame.width - 50, y: contentView.frame.height - 18, width: 39.5, height: 15) : CGRect(x: contentView.frame.maxX - 150, y: contentView.frame.height - 54, width: 98, height: 43)
        selectButton = UIButton(frame: selectFrame)
        let image = circleIndex > 0 ? UIImage(named: "SelectedButton") : UIImage(named: "SelectButton")
        selectButton.setImage(image, for: .normal)
        selectButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        selectButton.addTarget(self, action: #selector(circleTap(_:)), for: .touchUpInside)
        selectButton.contentHorizontalAlignment = .right
        selectButton.contentVerticalAlignment = .center
        contentView.addSubview(selectButton)
        
        if circleView != nil { circleView.removeFromSuperview() }
        let circleFrame = galleryAnimation ? CGRect(x: contentView.frame.maxX - 17, y: contentView.frame.height - 17, width: 15, height: 15) : CGRect(x: contentView.frame.maxX - 52, y: contentView.frame.height - 53, width: 40, height: 40)
        circleView = CircleView(frame: circleFrame)
        circleView.setUp(index: index)
        circleView.layer.cornerRadius = 16
        contentView.addSubview(circleView)
        
        let circleButton = UIButton(frame: CGRect(x: bounds.width - 52, y: contentView.frame.height - 56, width: 46, height: 46))
        circleButton.addTarget(self, action: #selector(circleTap(_:)), for: .touchUpInside)
        contentView.addSubview(circleButton)
        
        /// for animation back to gallery
        galleryCircle = CircleView(frame: CGRect(x: contentView.frame.width - 27, y: 6, width: 23, height: 23))
        galleryCircle.setUp(index: index)
        galleryCircle.isHidden = true
        contentView.addSubview(galleryCircle)
    }
    
    func addActivityIndicator() {
        bringSubviewToFront(activityIndicator)
        activityIndicator.startAnimating()
    }
    
    func removeActivityIndicator() {
        activityIndicator.stopAnimating()
    }

    @objc func toggleAlive(_ sender: UIButton) {
        
        
        Mixpanel.mainInstance().track(event: "ImagePreviewToggleAlive", properties: ["on": imageObject.gifMode])
        
        if !imageObject.gifMode {
            
            aliveToggle.isEnabled = false
            activityIndicator.startAnimating()
            imageFetcher.fetchingIndex = 0

            /// download alive if available and not yet downloaded
            imageFetcher.fetchLivePhoto(currentAsset: imageObject.asset, animationImages: imageObject.animationImages) { [weak self] animationImages, failed in

                guard let self = self else { return }
                if animationImages.isEmpty { return }
                
                self.activityIndicator.stopAnimating()
                self.aliveToggle.isEnabled = true
                self.aliveToggle.setImage(UIImage(named: "AliveOn"), for: .normal)
                self.imageObject.gifMode = true

                self.imageObject.animationImages = animationImages
                
                /// animate with gif images
                self.animationImages = self.imageObject.animationImages
                self.animatePreviewGif()
                self.updateParent()
                ///fetch image is async so need to make sure another image wasn't appended while this one was being fetched
            }

        } else {

            aliveToggle.setImage(UIImage(named: "AliveOff"), for: .normal)
            imageObject.gifMode = false
            
            self.image = imageObject.stillImage
            self.animationImages?.removeAll()
            updateParent()
        }
    }
    
    func cancelImageFetch() {
        
        activityIndicator.stopAnimating()
        aliveToggle.isEnabled = true
        
        imageFetcher.cancelFetchForAsset(asset: imageObject.asset)
    }
    
    @objc func circleTap(_ sender: UIButton) {
        
        let selected = circleIndex == 0
        let image = selected ? UIImage(named: "SelectedButton") : UIImage(named: "SelectButton")
        selectButton.setImage(image, for: .normal)
        
        Mixpanel.mainInstance().track(event: "ImagePreviewSelectImage", properties: ["selected": selected])
        
        guard let previewView = superview as? ImagePreviewView else { return }
        
        // defer to gallery/cluster select methods
        
      if let gallery = previewView.galleryCollection.viewContainingController() as? PhotoGalleryController {
            selected ? gallery.select(index: previewView.galleryIndex) : gallery.deselect(index: previewView.galleryIndex)
            circleIndex = selected ? UploadPostModel.shared.selectedObjects.count : 0
        }
        
        for sub in circleView.subviews { sub.removeFromSuperview() }
        circleView.setUp(index: circleIndex)
    }
    
    func updateParent() {
        
        guard let previewView = superview as? ImagePreviewView else { return }
        previewView.imageObjects[previewView.selectedIndex].animationImages = imageObject.animationImages
        previewView.imageObjects[previewView.selectedIndex].gifMode = imageObject.gifMode
                
        /// update in gallery / cluster
        if let i = UploadPostModel.shared.imageObjects.firstIndex(where: {$0.image.id == imageObject.id}) {
            UploadPostModel.shared.imageObjects[i].image.animationImages = imageObject.animationImages
            UploadPostModel.shared.imageObjects[i].image.gifMode = imageObject.gifMode
        }
        
        if let i = UploadPostModel.shared.selectedObjects.firstIndex(where: {$0.id == imageObject.id}) {
            UploadPostModel.shared.selectedObjects[i].animationImages = imageObject.animationImages
            UploadPostModel.shared.selectedObjects[i].gifMode = imageObject.gifMode
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
        
        Mixpanel.mainInstance().track(event: "ImagePreviewZoomOnImage", properties: nil)
        
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
            
    /// custom animateGif func for maintaining animationIndex
    func animatePreviewGif() {

        if superview == nil || isHidden || animationImages?.isEmpty ?? true { return }
        
        UIView.transition(with: self, duration: 0.06, options: [.allowUserInteraction, .beginFromCurrentState], animations: { [weak self] in
                            guard let self = self else { return }
            if self.animationImages?.isEmpty ?? true { return }
            if self.animationIndex >= self.animationImages?.count ?? 0 { return }
            self.image = self.animationImages![self.animationIndex] },
                          completion: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06 + 0.005) { [weak self] in
            guard let self = self else { return }
            
            var newDirection = self.directionUp
            var newCount = self.animationIndex
            
            if self.directionUp {
                if self.animationIndex == self.animationImages!.count - 1 {
                    newDirection = false
                    newCount = self.animationImages!.count - 2
                } else {
                    newCount += 1
                }
            } else {
                if self.animationIndex == 0 {
                    newDirection = true
                    newCount = 1
                } else {
                    newCount -= 1
                }
            }

            self.animationIndex = newCount
            self.directionUp = newDirection
            self.animatePreviewGif()
        }
    }
}

//
//  ImagePreviewView.swift
//  Spot
//
//  Created by Kenny Barone on 11/8/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation
import Mixpanel
import Photos
import UIKit

protocol ImagePreviewDelegate {
    func select(galleryIndex: Int)
    func deselect(galleryIndex: Int)
}

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

    var delegate: ImagePreviewDelegate?
    var animateFromFooter = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        Mixpanel.mainInstance().track(event: "GalleryPreviewOpen", properties: nil)
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

        let maskAspect = min(currentObject.stillImage.size.height / currentObject.stillImage.size.width, 1.5)
        let maskHeight = maskAspect * UIScreen.main.bounds.width
        let maskY = 20 + (UIScreen.main.bounds.height - maskHeight - 40) / 2
        /// animate image preview expand -> use scale aspect fill at first for smooth animation then aspect fit within larger image frame

        UIView.animate(withDuration: 0.25) {
            self.alpha = 1.0 /// animate mask appearing
            let finalRect = CGRect(x: 0, y: maskY, width: UIScreen.main.bounds.width, height: maskHeight)
            self.maskImage.frame = finalRect
            if self.maskImage.aliveToggle != nil { self.maskImage.aliveToggle.frame = CGRect(x: 7, y: finalRect.height - 54, width: 74, height: 46) }
            if self.maskImage.circleView != nil { self.maskImage.circleView.frame = CGRect(x: finalRect.maxX - 52, y: finalRect.height - 53, width: 40, height: 40) }
            if self.maskImage.selectButton != nil { self.maskImage.selectButton.frame = CGRect(x: finalRect.maxX - 150, y: finalRect.height - 54, width: 98, height: 43) }
            if self.maskImage.imageMask != nil { self.maskImage.imageMask.frame = CGRect(x: 0, y: finalRect.height * 2 / 3, width: finalRect.width, height: finalRect.height / 3) }

        } completion: { [weak self] _ in
            guard let self = self else { return }
            self.maskImage.setUp(imageObject: imageObjects[selectedIndex])
        }
    }

    func setImageBounds(first: Bool, selectedIndex: Int) {

        self.selectedIndex = selectedIndex

        if !first {
            let selectedObject = imageObjects[selectedIndex]

            let maskAspect = min(selectedObject.stillImage.size.height / selectedObject.stillImage.size.width, 1.5)
            let maskHeight = maskAspect * UIScreen.main.bounds.width
            let maskY = 20 + (UIScreen.main.bounds.height - maskHeight - 40) / 2

            maskImage.frame = CGRect(x: 0, y: maskY, width: UIScreen.main.bounds.width, height: maskHeight)
            maskImage.setUp(imageObject: selectedObject)
        }

        if imageObjects.count > 1 {

            /// blank frame or use filled aspect ratio of next object
            let pAspect = selectedIndex > 0 ? min(imageObjects[selectedIndex - 1].stillImage.size.height / imageObjects[selectedIndex - 1].stillImage.size.width, 1.5) : 1.5
            let pHeight = pAspect * UIScreen.main.bounds.width
            let py = 20 + (UIScreen.main.bounds.height - pHeight - 40) / 2

            maskImagePrevious.frame = CGRect(x: -UIScreen.main.bounds.width, y: py, width: UIScreen.main.bounds.width, height: pHeight)
            maskImagePrevious.image = UIImage()

            if selectedIndex > 0 {
                maskImagePrevious.setUp(imageObject: imageObjects[selectedIndex - 1])
            }

            let nAspect = selectedIndex < imageObjects.count - 1 ? min(imageObjects[selectedIndex + 1].stillImage.size.height / imageObjects[selectedIndex + 1].stillImage.size.width, 1.5) : 1.5
            let nHeight = nAspect * UIScreen.main.bounds.width
            let ny = 20 + (UIScreen.main.bounds.height - nHeight - 40) / 2

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

            maskImage.frame = CGRect(x: translation.x, y: maskImage.frame.minY, width: maskImage.frame.width, height: maskImage.frame.height)
            maskImageNext.frame = CGRect(x: UIScreen.main.bounds.width + translation.x, y: maskImageNext.frame.minY, width: maskImageNext.frame.width, height: maskImageNext.frame.height)
            maskImagePrevious.frame = CGRect(x: -UIScreen.main.bounds.width + translation.x, y: maskImagePrevious.frame.minY, width: maskImagePrevious.frame.width, height: maskImagePrevious.frame.height)

        case .ended:

            /// image swipe from portrait orientation

            if direction.x < 0 {
                if maskImage.frame.maxX + direction.x < UIScreen.main.bounds.width / 2 && selectedIndex < imageObjects.count - 1 {
                    // animate to next image
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
                    // return to original state
                    UIView.animate(withDuration: 0.2) { self.setImageBounds(first: false, selectedIndex: self.selectedIndex) }
                }

            } else {
                if maskImage.frame.minX + direction.x > UIScreen.main.bounds.width / 2 && selectedIndex > 0 {
                    // animate to previous image
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
                    // return to original state
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
        let maskAspect = min(selectedImage.size.height / selectedImage.size.width, 1.5)
        let maskHeight = maskAspect * UIScreen.main.bounds.width
        let maskY = 20 + (UIScreen.main.bounds.height - maskHeight - 40) / 2

        DispatchQueue.main.async {

            self.maskImage.frame = CGRect(x: 0, y: maskY, width: UIScreen.main.bounds.width, height: maskHeight)
            let endFrame = self.originalFrame ?? CGRect()

            if self.maskImage.circleView != nil { self.maskImage.circleView.isHidden = true }
            if self.maskImage.selectButton != nil { self.maskImage.selectButton.isHidden = true }
            if self.maskImage.aliveToggle != nil { self.maskImage.aliveToggle.isHidden = true }

            let duration = self.animateFromFooter && !self.maskImage.selected ? 0.0 : 0.25
            /// main animation -> cancel if deselected from footer (weird animation)
            UIView.animate(withDuration: duration) {
                self.backgroundColor = UIColor(named: "SpotBlack")?.withAlphaComponent(0.0)
                self.maskImage.frame = endFrame
                if !self.animateFromFooter {
                    self.maskImage.galleryCircle.alpha = 1.0
                    self.maskImage.galleryCircle.frame = CGRect(x: endFrame.width - 29, y: 6, width: 23, height: 23)
                    self.maskImage.liveIndicator.alpha = 1.0
                    self.maskImage.liveIndicator.frame = CGRect(x: endFrame.width / 2 - 9, y: endFrame.height / 2 - 9, width: 18, height: 18)
                    self.maskImage.galleryMask.alpha = 1.0
                    self.maskImage.layer.borderColor = UIColor(named: "SpotBlack")?.cgColor
                    self.maskImage.layer.borderWidth = 1
                }
            } completion: { [weak self] _ in
                guard let self = self else { return }
                for subview in self.subviews { subview.removeFromSuperview() }
                self.isHidden = true
                self.backgroundColor = UIColor(named: "SpotBlack")
                self.removeGestureRecognizer(self.imageCloseTap)
                Mixpanel.mainInstance().track(event: "GalleryPreviewClose", properties: nil)
                NotificationCenter.default.post(name: Notification.Name("PreviewRemove"), object: nil, userInfo: nil)
            }
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return !(touch.view?.isKind(of: UIButton.self) ?? true)
    }
}

final class ImagePreview: UIImageView, UIGestureRecognizerDelegate {
    var contentView: UIView!
    var aliveToggle: UIButton!
    var circleView: CircleView!
    var imageMask: GradientView!

    var selectButton: UIButton!
    var zooming = false
    var originalCenter: CGPoint!

    var galleryMask: UIView!
    var galleryCircle: CircleView!
    var liveIndicator: UIImageView!

    lazy var activityIndicator = UIActivityIndicatorView()
    lazy var imageFetcher = ImageFetcher()

    var selected = false
    var animationIndex = 0
    var directionUp = true
    var imageObject: ImageObject! {
        didSet {
            selected = UploadPostModel.shared.selectedObjects.contains(where: { $0.id == imageObject.id })
        }
    }

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

        if imageMask == nil {
            imageMask = GradientView(frame: CGRect(x: 0, y: bounds.height * 2 / 3, width: bounds.width, height: bounds.height * 1 / 3))
            addSubview(imageMask)
        }

        addSubview(contentView)

        /// scale button as frame expands
        let galleryAnimation = contentView.bounds.width < 150
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

        let selected = UploadPostModel.shared.selectedObjects.contains(where: { $0.id == imageObject.id })

        if selectButton != nil { selectButton.setTitle("", for: .normal) }
        let selectFrame = galleryAnimation ? CGRect(x: contentView.frame.width - 50, y: contentView.frame.height - 18, width: 39.5, height: 15) : CGRect(x: contentView.frame.maxX - 150, y: contentView.frame.height - 54, width: 98, height: 43)
        selectButton = UIButton(frame: selectFrame)
        let title = selected ? "Selected" : "Select"
        selectButton.setTitle(title, for: .normal)
        selectButton.setTitleColor(.white, for: .normal)
        selectButton.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 18)
        selectButton.addTarget(self, action: #selector(circleTap(_:)), for: .touchUpInside)
        selectButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 8)
        selectButton.contentHorizontalAlignment = .right
        selectButton.contentVerticalAlignment = .center
        selectButton.alpha = UploadPostModel.shared.selectedObjects.count == 5 && !selected ? 0.3 : 1.0
        contentView.addSubview(selectButton)

        if circleView != nil { circleView.removeFromSuperview() }
        let circleFrame = galleryAnimation ? CGRect(x: contentView.frame.maxX - 17, y: contentView.frame.height - 17, width: 15, height: 15) : CGRect(x: contentView.frame.maxX - 52, y: contentView.frame.height - 53, width: 40, height: 40)
        circleView = CircleView(frame: circleFrame)
        circleView.selected = selected
        circleView.layer.cornerRadius = 20
        contentView.addSubview(circleView)

        let circleButton = UIButton(frame: CGRect(x: bounds.width - 52, y: contentView.frame.height - 56, width: 46, height: 46))
        circleButton.addTarget(self, action: #selector(circleTap(_:)), for: .touchUpInside)
        contentView.addSubview(circleButton)

        /// for animation back to gallery
        galleryMask = UIView(frame: self.bounds)
        galleryMask.backgroundColor = UIColor(named: "SpotBlack")?.withAlphaComponent(0.5)
        galleryMask.isHidden = !selected
        galleryMask.alpha = 0.0
        contentView.addSubview(galleryMask)

        liveIndicator = UIImageView(frame: CGRect(x: bounds.width / 2 - 9, y: bounds.height / 2 - 9, width: 18, height: 18))
        liveIndicator.image = UIImage(named: "PlayButton")
        liveIndicator.isHidden = !(imageObject.asset.mediaSubtypes.contains(.photoLive))
        liveIndicator.alpha = 0.0
        contentView.addSubview(liveIndicator)

        galleryCircle = CircleView(frame: CGRect(x: contentView.frame.width - 27, y: 6, width: 23, height: 23))
        galleryCircle.selected = selected
        galleryCircle.layer.cornerRadius = 11.5
        galleryCircle.alpha = 0.0
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
            imageFetcher.fetchLivePhoto(currentAsset: imageObject.asset, animationImages: imageObject.animationImages) { [weak self] animationImages, _ in

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
                /// fetch image is async so need to make sure another image wasn't appended while this one was being fetched
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

        if !selected && UploadPostModel.shared.selectedObjects.count == 5 { return } /// 5 images max
        selected = !selected
        let title = selected ? "Selected" : "Select"
        selectButton.setTitle(title, for: .normal)

        Mixpanel.mainInstance().track(event: "GalleryPreview", properties: ["selected": selected])

        guard let previewView = superview as? ImagePreviewView else { return }
        selected ? previewView.delegate?.select(galleryIndex: previewView.galleryIndex) : previewView.delegate?.deselect(galleryIndex: previewView.galleryIndex)

        circleView.selected = selected

        /// animation methods
        galleryMask.isHidden = !selected
        galleryCircle.selected = selected
    }

    func updateParent() {

        guard let previewView = superview as? ImagePreviewView else { return }
        previewView.imageObjects[previewView.selectedIndex].animationImages = imageObject.animationImages
        previewView.imageObjects[previewView.selectedIndex].gifMode = imageObject.gifMode

        /// update in gallery / cluster
        if let i = UploadPostModel.shared.imageObjects.firstIndex(where: { $0.image.id == imageObject.id }) {
            UploadPostModel.shared.imageObjects[i].image.animationImages = imageObject.animationImages
            UploadPostModel.shared.imageObjects[i].image.gifMode = imageObject.gifMode
        }

        if let i = UploadPostModel.shared.selectedObjects.firstIndex(where: { $0.id == imageObject.id }) {
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

class GradientView: UIView {
  override class var layerClass: AnyClass {
    return CAGradientLayer.self
  }

  var gradientLayer: CAGradientLayer {
    // it is safe to force cast here
    // since we told UIView to use this exact type
    return self.layer as! CAGradientLayer
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    // setup your gradient

      gradientLayer.frame = bounds
      gradientLayer.colors = [
          UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
          UIColor(red: 0, green: 0, blue: 0, alpha: 0.48).cgColor
      ]
      gradientLayer.locations = [0, 1]
      gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
      gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
      gradientLayer.masksToBounds = true
  }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

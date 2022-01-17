//
//  ImageMaskView.swift
//  Spot
//
//  Created by Kenny Barone on 7/28/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase

class MaskImageView: UIView, UIGestureRecognizerDelegate {
    
    var imageCloseTap: UITapGestureRecognizer!
    var maskImage: UIImageView!
    var maskImageNext: UIImageView!
    var maskImagePrevious: UIImageView!
    
    var originalFrame: CGRect!
    var frameIndexes: [Int] = []
    var images: [UIImage] = []
    var selectedIndex = 0
    
    var orientation = 1 /// 1 = portrait (raw values 1 or 2), 3 = counterclockwise landscape, 4 = clockwise landscape,
    var landscape = false
    var alive = false
    var zooming = false
    var originalCenter: CGPoint!
    
    unowned var postCell: PostCell!
    
    override init(frame: CGRect) {

        super.init(frame: frame)
        
        NotificationCenter.default.addObserver(self, selector: #selector(rotate(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
        backgroundColor = UIColor(named: "SpotBlack")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    func imageExpand(originalFrame: CGRect, frameIndexes: [Int], images: [UIImage], selectedIndex: Int, alive: Bool) {
        
      //  landscape = false
        
        orientation = 1
        
        self.frameIndexes = frameIndexes
        self.images = images
        self.selectedIndex = selectedIndex
        self.originalFrame = originalFrame
        
        imageCloseTap = UITapGestureRecognizer(target: self, action: #selector(closeImageExpand(_:)))
        addGestureRecognizer(imageCloseTap)
           
        /// mask image starts as the exact size of the thumbmnail then will expand to full screen
        maskImage = UIImageView(frame: originalFrame)

        let selectedFrame = frameIndexes[selectedIndex]
        let selectedImage = images[selectedFrame]
        maskImage.image = selectedImage
        maskImage.tag = 88
        maskImage.contentMode = .scaleAspectFill
        maskImage.clipsToBounds = true
        maskImage.isUserInteractionEnabled = true
        addSubview(maskImage)
        
        enableZoom()
                
        if frameIndexes.count > 1 {
            
            /// add swipe between images if there are images to swipe through
            let pan = UIPanGestureRecognizer(target: self, action: #selector(imageSwipe(_:)))
            pan.delegate = self
            maskImage.addGestureRecognizer(pan)
            
            maskImagePrevious = UIImageView()
            maskImagePrevious.image = UIImage()
            maskImagePrevious.contentMode = .scaleAspectFit
            maskImagePrevious.clipsToBounds = true
            maskImagePrevious.isUserInteractionEnabled = true
            addSubview(maskImagePrevious)
            
            maskImageNext = UIImageView()
            maskImageNext.image = UIImage()
            maskImageNext.contentMode = .scaleAspectFit
            maskImageNext.clipsToBounds = true
            maskImageNext.isUserInteractionEnabled = true
            addSubview(maskImageNext)
            
            setImageBounds(first: true, selectedIndex: selectedIndex)
        }
        
        let maskAspect = selectedImage.size.height/selectedImage.size.width
        let maskHeight = maskAspect * UIScreen.main.bounds.width
        let maskY = 20 + (UIScreen.main.bounds.height - maskHeight - 40)/2
        
        let animationImages = self.getGifImages()

        if !animationImages.isEmpty {
            self.maskImage.animationImages = animationImages
            /// 5 frame alive check for old alive draft
        
            var animationIndex = 0
            if self.postCell != nil, let imageView = self.postCell.imageScroll.subviews.first(where: {$0.tag == self.selectedIndex && $0 is PostImageView}) as? PostImageView {
                animationIndex = imageView.animationIndex
            }
            
            animationImages.count == 5 ? self.maskImage.animate5FrameAlive(directionUp: true, counter: animationIndex) : self.maskImage.animateGIF(directionUp: true, counter: animationIndex, alive: self.alive) }

            /// animate image preview expand -> use scale aspect fill at first for smooth animation then aspect fit within larger image frame
        UIView.animate(withDuration: 0.2) {
            self.alpha = 1.0 /// animate mask appearing
            self.maskImage.frame = CGRect(x: 0, y: maskY, width: UIScreen.main.bounds.width, height: maskHeight)

        } completion: { [weak self] _ in
            
            guard let self = self else { return }
            self.maskImage.contentMode = .scaleAspectFit
            self.maskImage.frame = CGRect(x: 0, y: 20, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 40)
        }
    }
    
    func setImageBounds(first: Bool, selectedIndex: Int) {
        
        // first = true on original mask expand (will animate the frame of the mask image)
        /// setImageBounds also called on swipe between images
        let sameIndex = selectedIndex == self.selectedIndex
        self.selectedIndex = selectedIndex
         
        if !first {
            let selectedFrame = frameIndexes[selectedIndex]
            maskImage.frame = CGRect(x: 0, y: 20, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 40)
            var selectedImage = images[selectedFrame]
            selectedImage = orientation == 1 ? selectedImage : orientation == 3 ? selectedImage.rotate(byAngle: CGFloat(Double.pi/2)) : selectedImage.rotate(byAngle: CGFloat(-Double.pi/2))
        //    if landscape { selectedImage = selectedImage.rotate(byAngle: CGFloat(Double.pi/2)) }
            if !sameIndex && !first { maskImage.image = selectedImage } /// avoid resetting image while animation is happening
            let animationImages = getGifImages()
            if !animationImages.isEmpty && (!sameIndex && !first) { maskImage.animationImages = animationImages; animationImages.count == 5 ? self.maskImage.animate5FrameAlive(directionUp: true, counter: 0) : self.maskImage.animateGIF(directionUp: true, counter: 0, alive: alive) }
        }
        
        if frameIndexes.count > 1 {
            
            var pImage = UIImage()
            
            if selectedIndex > 0 {
                let pFrame = frameIndexes[selectedIndex - 1]
                pImage = images[pFrame]
                pImage = orientation == 1 ? pImage : orientation == 3 ? pImage.rotate(byAngle: CGFloat(Double.pi/2)) : pImage.rotate(byAngle: CGFloat(-Double.pi/2))
            }
            
            maskImagePrevious.frame = orientation == 3 ? CGRect(x: 0, y: -UIScreen.main.bounds.height - 20, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 40) : orientation == 4 ? CGRect(x: 0, y: UIScreen.main.bounds.height + 20, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 40) : CGRect(x: -UIScreen.main.bounds.width, y: 20, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 40)
            maskImagePrevious.image = pImage

            var nImage = UIImage()
            
            if selectedIndex < frameIndexes.count - 1 {
                let nFrame = frameIndexes[selectedIndex + 1]
                nImage = images[nFrame]
                nImage = orientation == 1 ? nImage : orientation == 3 ? nImage.rotate(byAngle: CGFloat(Double.pi/2)) : nImage.rotate(byAngle: CGFloat(-Double.pi/2))
            }
            
            maskImageNext.frame = orientation == 3 ? CGRect(x: 0, y: UIScreen.main.bounds.height + 20, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 40) : orientation == 4 ? CGRect(x: 0, y: -UIScreen.main.bounds.height - 20, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 40) : CGRect(x: UIScreen.main.bounds.width, y: 20, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 40)
            maskImageNext.image = nImage
        }
    }

    @objc func imageSwipe(_ gesture: UIPanGestureRecognizer) {
        
        if zooming { return }
        
        let direction = gesture.velocity(in: self)
        let translation = gesture.translation(in: self)
        
        switch gesture.state {
        
        case .changed:
            
            if orientation == 1 {
                maskImage.frame = CGRect(x:translation.x, y: maskImage.frame.minY, width: maskImage.frame.width, height: maskImage.frame.height)
                maskImageNext.frame = CGRect(x: UIScreen.main.bounds.width + translation.x, y: maskImageNext.frame.minY, width: maskImageNext.frame.width, height: maskImageNext.frame.height)
                maskImagePrevious.frame = CGRect(x: -UIScreen.main.bounds.width + translation.x, y: maskImagePrevious.frame.minY, width: maskImagePrevious.frame.width, height: maskImagePrevious.frame.height)
                
            } else if orientation == 3 {
                maskImage.frame = CGRect(x: 0, y: translation.y, width: maskImage.frame.width, height: maskImage.frame.height)
                maskImageNext.frame = CGRect(x: 0, y: UIScreen.main.bounds.height + translation.y, width: maskImageNext.frame.width, height: maskImageNext.frame.height)
                maskImagePrevious.frame = CGRect(x: 0, y: -UIScreen.main.bounds.height + translation.y, width: maskImagePrevious.frame.width, height: maskImagePrevious.frame.height)
                
            } else {
                maskImage.frame = CGRect(x: 0, y: translation.y, width: maskImage.frame.width, height: maskImage.frame.height)
                maskImageNext.frame = CGRect(x: 0, y: -UIScreen.main.bounds.height + translation.y, width: maskImageNext.frame.width, height: maskImageNext.frame.height)
                maskImagePrevious.frame = CGRect(x: 0, y: UIScreen.main.bounds.height + translation.y, width: maskImagePrevious.frame.width, height: maskImagePrevious.frame.height)
            }
            
        case .ended:
            
            if orientation == 1 {
                /// image swipe from portrait orientation
                
                if direction.x < 0  {
                    if maskImage.frame.maxX + direction.x < UIScreen.main.bounds.width/2 && selectedIndex < frameIndexes.count - 1 {
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
                            if self.postCell != nil { self.postCell.scrollToImageAt(position: self.selectedIndex, animated: false) }
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
                            if self.postCell != nil { self.postCell.scrollToImageAt(position: self.selectedIndex, animated: false) }
                            return
                        }
                    } else {
                        //return to original state
                        UIView.animate(withDuration: 0.2) { self.setImageBounds(first: false, selectedIndex: self.selectedIndex)
                        }
                    }
                }
                /// image swipe from counter clockwise landscape orientation
            } else if orientation == 3 {
                if direction.y < 0 {
                    if maskImage.frame.maxY + direction.y < UIScreen.main.bounds.height/2 && selectedIndex < frameIndexes.count - 1 {
                        //animate to next image
                        UIView.animate(withDuration: 0.2) {
                            self.maskImageNext.frame = CGRect(x: 0, y: 20, width: self.maskImageNext.frame.width, height: self.maskImageNext.frame.height)
                            self.maskImage.frame = CGRect(x: 0, y: -UIScreen.main.bounds.height, width: self.maskImage.frame.width, height: self.maskImage.frame.height)
                            self.maskImagePrevious.frame = CGRect(x: 0, y: -UIScreen.main.bounds.height, width: self.maskImagePrevious.frame.width, height: self.maskImagePrevious.frame.height)
                        }
                        
                        /// remove animation images early for smooth swiping
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { [weak self] in
                            guard let self = self else { return }
                            self.maskImage.animationImages?.removeAll()
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            guard let self = self else { return }
                            self.setImageBounds(first: false, selectedIndex: self.selectedIndex + 1)
                            if self.postCell != nil { self.postCell.scrollToImageAt(position: self.selectedIndex, animated: false) }
                            return
                        }
                    } else {
                        //return to original state
                        UIView.animate(withDuration: 0.2) { self.setImageBounds(first: false, selectedIndex: self.selectedIndex) }
                    }
                    
                } else {
                    if maskImage.frame.minY + direction.y > UIScreen.main.bounds.height/2 && selectedIndex > 0 {
                        //animate to previous image
                        UIView.animate(withDuration: 0.2) {
                            self.maskImagePrevious.frame = CGRect(x: 0, y: 20, width: self.maskImagePrevious.frame.width, height: self.maskImagePrevious.frame.height)
                            self.maskImage.frame = CGRect(x: 0, y: UIScreen.main.bounds.height, width: self.maskImage.frame.width, height: self.maskImage.frame.height)
                            self.maskImageNext.frame = CGRect(x: 0, y: UIScreen.main.bounds.height, width: self.maskImageNext.frame.width, height: self.maskImageNext.frame.height)
                        }
                        
                        /// remove animation images early for smooth swiping
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { [weak self] in
                            guard let self = self else { return }
                            self.maskImage.animationImages?.removeAll()
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            guard let self = self else { return }
                            self.setImageBounds(first: false, selectedIndex: self.selectedIndex - 1)
                            if self.postCell != nil { self.postCell.scrollToImageAt(position: self.selectedIndex, animated: false) }
                            return
                        }
                    } else {
                        //return to original state
                        UIView.animate(withDuration: 0.2) { self.setImageBounds(first: false, selectedIndex: self.selectedIndex)
                        }
                    }
                }

            } else {
                /// image swipe from clockwise landscape orientation
                if direction.y > 0 {
                    if maskImage.frame.minY + direction.y > UIScreen.main.bounds.height/2 && selectedIndex < frameIndexes.count - 1 {
                        //animate to next image
                        UIView.animate(withDuration: 0.2) {
                            self.maskImageNext.frame = CGRect(x: 0, y: 20, width: self.maskImageNext.frame.width, height: self.maskImageNext.frame.height)
                            self.maskImage.frame = CGRect(x: 0, y: UIScreen.main.bounds.height, width: self.maskImage.frame.width, height: self.maskImage.frame.height)
                            self.maskImagePrevious.frame = CGRect(x: 0, y: UIScreen.main.bounds.height, width: self.maskImagePrevious.frame.width, height: self.maskImagePrevious.frame.height)
                        }
                        
                        /// remove animation images early for smooth swiping
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { [weak self] in
                            guard let self = self else { return }
                            self.maskImage.animationImages?.removeAll()
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            guard let self = self else { return }
                            self.setImageBounds(first: false, selectedIndex: self.selectedIndex + 1)
                            if self.postCell != nil { self.postCell.scrollToImageAt(position: self.selectedIndex, animated: false) }
                            return
                        }
                    } else {
                        //return to original state
                        UIView.animate(withDuration: 0.2) { self.setImageBounds(first: false, selectedIndex: self.selectedIndex) }
                    }
                    
                } else {
                    if maskImage.frame.maxY + direction.y < UIScreen.main.bounds.height/2 && selectedIndex > 0 {
                        //animate to previous image
                        UIView.animate(withDuration: 0.2) {
                            self.maskImagePrevious.frame = CGRect(x: 0, y: 20, width: self.maskImagePrevious.frame.width, height: self.maskImagePrevious.frame.height)
                            self.maskImage.frame = CGRect(x: 0, y: -UIScreen.main.bounds.height, width: self.maskImage.frame.width, height: self.maskImage.frame.height)
                            self.maskImageNext.frame = CGRect(x: 0, y: -UIScreen.main.bounds.height, width: self.maskImageNext.frame.width, height: self.maskImageNext.frame.height)
                        }
                        
                        /// remove animation images early for smooth swiping
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { [weak self] in
                            guard let self = self else { return }
                            self.maskImage.animationImages?.removeAll()
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            guard let self = self else { return }
                            self.setImageBounds(first: false, selectedIndex: self.selectedIndex - 1)
                            if self.postCell != nil { self.postCell.scrollToImageAt(position: self.selectedIndex, animated: false) }
                            return
                        }
                    } else {
                        //return to original state
                        UIView.animate(withDuration: 0.2) { self.setImageBounds(first: false, selectedIndex: self.selectedIndex)
                        }
                    }
                }
            }
        default:
            return
        }
    }
    
    @objc func closeImageExpand(_ sender: UITapGestureRecognizer) {
        
        let selectedFrame = frameIndexes[selectedIndex]
        let selectedImage = images[selectedFrame]
        let maskAspect = selectedImage.size.height/selectedImage.size.width
        let maskHeight = maskAspect * UIScreen.main.bounds.width
        let maskY = 20 + (UIScreen.main.bounds.height - maskHeight - 40)/2
        
        DispatchQueue.main.async {
            
            self.maskImage.frame = CGRect(x: 0, y: maskY, width: UIScreen.main.bounds.width, height: maskHeight)
            self.maskImage.contentMode = .scaleAspectFill
                    
            UIView.animate(withDuration: 0.2) {
                self.maskImage.frame = self.originalFrame
                self.maskImage.layer.cornerRadius = self.postCell == nil ? 5 : 10
                self.maskImage.layer.cornerCurve = .continuous
                self.backgroundColor = UIColor(named: "SpotBlack")!.withAlphaComponent(0.0)
                
            } completion: { [weak self] complete in

                guard let self = self else { return }
                for subview in self.subviews { subview.removeFromSuperview() }
                
                self.isHidden = true
                self.backgroundColor = UIColor(named: "SpotBlack")
                self.removeGestureRecognizer(self.imageCloseTap)

            }
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer.view?.tag == 88 && otherGestureRecognizer.view?.tag == 88 /// only user for postImage zoom / swipe
    }
    
    func getGifImages() -> [UIImage] {
        
        var gifImages: [UIImage] = []
        let selectedFrame = frameIndexes[selectedIndex]

        if frameIndexes.count == 1 {
            gifImages = images.count > 1 ? images : []
            
        } else if frameIndexes.count - 1 == selectedIndex {
            gifImages = images[selectedFrame] != images.last ? images.suffix(images.count - 1 - selectedFrame) : []
            
        } else {
            let frame1 = frameIndexes[selectedIndex + 1]
            gifImages = frame1 - selectedFrame > 1 ? Array(images[selectedFrame...frame1 - 1]) : []
        }
        
        gifImages = orientation == 1 ? gifImages : orientation == 3 ? gifImages.map({$0.rotate(byAngle: CGFloat(Double.pi/2)) ?? UIImage()}) : gifImages.map({$0.rotate(byAngle: CGFloat(-Double.pi/2)) ?? UIImage()})
        return gifImages
    }

    @objc func rotate(_ sender: NSNotification) {

        if maskImage != nil && maskImage.frame.minX == 0 {
            /// rotate if expanded
            if UIDevice.current.orientation.rawValue == 3 || UIDevice.current.orientation.rawValue == 4 && orientation == 1 { rotateToLandscape() } else if UIDevice.current.orientation.rawValue == 1 || UIDevice.current.orientation.rawValue == 2 && orientation != 1 { rotateToPortrait() }
        }
    }

    func rotateToLandscape() {
        
        let clockwise = UIDevice.current.orientation.rawValue == 4
        orientation = UIDevice.current.orientation.rawValue

        UIImageView.transition(with: maskImage, duration: 0.2, options: .transitionCrossDissolve) {
            /// 1.  rotate animationImages if gif
            let animationImages = self.getGifImages()
            if !animationImages.isEmpty {
                self.maskImage.animationImages?.removeAll()
                self.maskImage.animationImages = animationImages
                
            } else {
                /// 2. rotate image if still
                let selectedFrame = self.frameIndexes[self.selectedIndex]
                let currentImage = self.images[selectedFrame]
                self.maskImage.image = clockwise ? currentImage.rotate(byAngle: CGFloat(-Double.pi/2)) : currentImage.rotate(byAngle: CGFloat(Double.pi/2))
            }
            
        } completion: { [weak self] complete in
            guard let self = self else { return }
            self.setImageBounds(first: false, selectedIndex: self.selectedIndex)
        }
        
        /// 3. rotate position of imageviewnext/previous -> scrolling logic takes horizontal
        
    }
    
    func rotateToPortrait() {
        
        orientation = 1
                
        UIImageView.transition(with: maskImage, duration: 0.2, options: .transitionCrossDissolve) {

            /// 1.  rotate animationImages if gif
            let animationImages = self.getGifImages()
            if !animationImages.isEmpty {
                self.maskImage.animationImages?.removeAll()
                self.maskImage.animationImages = animationImages
                
            } else {
                /// 2. rotate image if still
                let selectedFrame = self.frameIndexes[self.selectedIndex]
                let currentImage = self.images[selectedFrame]
                self.maskImage.image = currentImage
            }
        } completion: { [weak self] complete in
            guard let self = self else { return }
            self.setImageBounds(first: false, selectedIndex: self.selectedIndex)
        }
    }
    
    func enableZoom() {
        
        maskImage.isUserInteractionEnabled = true
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(zoom(_:)))
        pinchGesture.delegate = self
        maskImage.addGestureRecognizer(pinchGesture)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        panGesture.delegate = self
        maskImage.addGestureRecognizer(panGesture)
        
    }

        
    @objc func zoom(_ sender: UIPinchGestureRecognizer) {
        
        switch sender.state {
        
        case .began:
            print("zooming")
            zooming = true
            originalCenter = center
            
        case .changed:
            let pinchCenter = CGPoint(x: sender.location(in: maskImage).x - maskImage.bounds.midX,
                                      y: sender.location(in: maskImage).y - maskImage.bounds.midY)
            
            let transform = maskImage.transform.translatedBy(x: pinchCenter.x, y: pinchCenter.y)
                .scaledBy(x: sender.scale, y: sender.scale)
                .translatedBy(x: -pinchCenter.x, y: -pinchCenter.y)
            
            let currentScale = maskImage.frame.size.width / maskImage.bounds.size.width
            var newScale = currentScale*sender.scale
            
            if newScale < 1 {
                newScale = 1
                let transform = CGAffineTransform(scaleX: newScale, y: newScale)
                maskImage.transform = transform
                
            } else {
                maskImage.transform = transform
                sender.scale = 1
            }
            
        case .ended, .cancelled, .failed:
            UIView.animate(withDuration: 0.3, animations: { [weak self] in
                
                guard let self = self else { return }
                self.maskImage.center = self.originalCenter
                self.maskImage.transform = CGAffineTransform.identity
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
            let translation = sender.translation(in: maskImage)
            let currentScale = maskImage.frame.size.width / maskImage.bounds.size.width
            maskImage.center = CGPoint(x: maskImage.center.x + (translation.x * currentScale), y: maskImage.center.y + (translation.y * currentScale))
            sender.setTranslation(CGPoint.zero, in: superview)
        }
    }
    
    /// source: https://medium.com/@jeremysh/instagram-pinch-to-zoom-pan-gesture-tutorial-772681660dfe

    
}

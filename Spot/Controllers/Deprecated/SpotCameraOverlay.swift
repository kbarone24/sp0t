//
//  SpotCameraOverlay.swift
//  Spot
//
//  Created by kbarone on 2/7/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import Photos
import UIKit

class SpotCameraOverlay: UIView {
    var cameraButton: UIButton!
    var cameraRollButton: UIButton!
    var flashButton: UIButton!
    var cancelButton: UIButton!
    var cameraRotateButton: UIButton!
    var flashOn = false

    var createPost = false
    var gifMode = true
    var blurView: UIVisualEffectView!

    override init(frame: CGRect) {
        super.init(frame: frame)

        var offset: CGFloat = 0
        if !(UIScreen.main.nativeBounds.height > 2_400 || UIScreen.main.nativeBounds.height == 1_792) {
            offset = 45
        }

        if createPost {
            let gesture = UIPanGestureRecognizer(target: self, action: #selector(panGesture))
            self.addGestureRecognizer(gesture)

            let blur = UIBlurEffect(style: .dark)
            blurView = UIVisualEffectView(effect: blur)
            blurView.frame = self.bounds
            blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }

        cameraButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width / 2 - 45, y: UIScreen.main.bounds.height - 138 + offset, width: 90, height: 90))
        cameraButton.setImage(UIImage(named: "CameraButton"), for: .normal)
        self.addSubview(cameraButton)

        cameraRollButton = UIButton(frame: CGRect(x: 38, y: UIScreen.main.bounds.height - 120 + offset, width: 40, height: 40))
        var image = UIImage()
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            self.queryLastPhoto(resizeTo: nil) { (im) in
                if im != nil {
                    image = im!
                } else {
                    image = UIImage(named: "PhotoGalleryButton")!
                }
            }
        } else {
            image = UIImage(named: "PhotoGalleryButton")!
        }

        cameraRollButton.setImage(image, for: .normal)
        cameraRollButton.imageView?.contentMode = .scaleAspectFill
        cameraRollButton.imageView?.layer.cornerRadius = 8
        cameraRollButton.imageView?.layer.masksToBounds = true
        cameraRollButton.clipsToBounds = true
        self.addSubview(cameraRollButton)

        let galleryText = UILabel(frame: CGRect(x: 32, y: cameraRollButton.frame.maxY + 5, width: 110, height: 20))
        galleryText.text = "Gallery"
        galleryText.textColor = .white
        galleryText.font = UIFont(name: "SFCamera-Semibold", size: 16)
        self.addSubview(galleryText)

        if offset != 0 {offset = offset - 15}

        flashButton = UIButton(frame: CGRect(x: 24, y: 60 - offset, width: 20, height: 30))
        flashButton.setImage(UIImage(named: "FlashOff"), for: .normal)
        flashButton.addTarget(self, action: #selector(switchFlash(_:)), for: .touchUpInside)
        flashButton.imageView?.contentMode = .scaleAspectFit
        self.addSubview(flashButton)

        cameraRotateButton = UIButton(frame: CGRect(x: 20, y: flashButton.frame.maxY + 26, width: 28, height: 20))
        cameraRotateButton.imageView?.contentMode = .scaleAspectFit
        cameraRotateButton.setImage(UIImage(named: "CameraRotateAlt"), for: .normal)
        self.addSubview(cameraRotateButton)

        cancelButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 90, y: 69 - offset, width: 90, height: 25))
        cancelButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 20)!
        cancelButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        self.addSubview(cancelButton)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func switchFlash(_ sender: UIButton) {
        if flashOn {
            flashButton.setImage(UIImage(named: "FlashOff"), for: .normal)
            flashOn = false
        } else {
            flashButton.setImage(UIImage(named: "FlashOn"), for: .normal)
            flashOn = true
        }
    }

    @objc func panGesture(_ gesture: UIPanGestureRecognizer) {
        let direction = gesture.velocity(in: self)
        if gesture.state == .ended {
            if abs(direction.x) > abs(direction.y) && direction.x > 200 {
                if self.gifMode {
                    self.transitionToPhoto()
                }
            } else if abs(direction.x) > abs(direction.y) && direction.x < 200 {
                if !self.gifMode {
                    self.transitionToGIF()
                }
            }
        }
    }

    func transitionToPhoto() {
        self.gifMode = false
        self.addSubview(blurView)
        UIView.animate(withDuration: 0.2, animations: {
            self.cameraButton.tintColor = nil
            self.blurView.removeFromSuperview()
        })
    }

    func transitionToGIF() {
        self.gifMode = true
        self.addSubview(blurView)

        UIView.animate(withDuration: 0.2, animations: {
            self.cameraButton.tintColor = UIColor(named: "SpotGreen")
            self.blurView.removeFromSuperview()
        })
    }

    func queryLastPhoto(resizeTo size: CGSize?, queryCallback: @escaping ((UIImage?) -> Void)) {

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true

        let fetchResult = PHAsset.fetchAssets(with: PHAssetMediaType.image, options: fetchOptions)
        if let asset = fetchResult.firstObject {
            let manager = PHImageManager.default()

            let targetSize = size == nil ? CGSize(width: asset.pixelWidth, height: asset.pixelHeight) : size!

            manager.requestImage(for: asset,
                                 targetSize: targetSize,
                                 contentMode: .aspectFill,
                                 options: requestOptions,
                                 resultHandler: { image, _ in
                                    queryCallback(image)
            })
        }
    }
}

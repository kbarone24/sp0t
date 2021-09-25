//
//  GIFPreviewController.swift
//  Spot
//
//  Created by kbarone on 2/27/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Photos
import Firebase
import Mixpanel
import CoreLocation
import MobileCoreServices
import AVKit
import CoreImage.CIFilterBuiltins

protocol GIFPreviewDelegate {
    func finishPassingFromCamera(images: [UIImage])
}

class GIFPreviewController: UIViewController {
    
    var spotObject: MapSpot!
    var delegate: GIFPreviewDelegate?
    
    var imageData: Data!
    var outputURL: URL!
    var frontFacing = false /// to rotate gif images when returned to the user
    
    var unfilteredStill: UIImage!
    var filteredStill: UIImage!
    
    var unfilteredImages: [UIImage] = []
    var filteredImages: [UIImage] = []

    var draftID: Int64!
    var gifMode = false
    var previewView: UIImageView!
    var aliveToggle: UIButton!
    var draftsButton: UIButton!
    var offset: CGFloat = 0
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    
    var filtersCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    var selectedItem = 2
    let context = CIContext()
    var cancelOnDismiss = false
            
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
        Mixpanel.mainInstance().track(event: "GIFOpen")
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cancelOnDismiss = true 
    }

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        
        let cameraAspect: CGFloat = 1.5
        var cameraWidth = UIScreen.main.bounds.width - 36
        var cameraHeight = cameraWidth * cameraAspect

        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        let navBarHeight = statusHeight +
                    (self.navigationController?.navigationBar.frame.height ?? 44.0)
        let viewHeight = UIScreen.main.bounds.height - navBarHeight
        
        var minX: CGFloat = 18
        if cameraHeight > viewHeight - 107 {
            cameraHeight = viewHeight - 107
            cameraWidth = cameraHeight/1.5
            minX = (UIScreen.main.bounds.width - cameraWidth) / 2
        }
        
        filteredStill = unfilteredStill
                
        previewView = UIImageView(frame: CGRect(x: minX, y: 16, width:  cameraWidth, height: cameraHeight))
        previewView.image = filteredStill
        previewView.contentMode = .scaleAspectFill
        previewView.clipsToBounds = true
        previewView.isUserInteractionEnabled = true
        previewView.layer.cornerRadius = 12
        view.addSubview(previewView)
                   
        draftsButton = UIButton(frame: CGRect(x: previewView.frame.maxX - 104, y: previewView.frame.maxY - 51, width: 88, height: 35))
        draftsButton.setImage(UIImage(named: "SaveToDraftsButton"), for: .normal)
        draftsButton.imageView?.contentMode = .scaleAspectFit
        draftsButton.addTarget(self, action: #selector(saveToDrafts(_:)), for: .touchUpInside)
        view.addSubview(draftsButton)
                
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 56.5, height: 72)
        layout.minimumInteritemSpacing = 5

        let filtersWidth: CGFloat = 312.5
        let filtersX = (UIScreen.main.bounds.width - filtersWidth) / 2
        filtersCollection.frame = CGRect(x: filtersX, y: previewView.frame.maxY + 16, width: filtersWidth, height: 80)
        filtersCollection.backgroundColor = nil
        filtersCollection.setCollectionViewLayout(layout, animated: false)
        filtersCollection.delegate = self
        filtersCollection.dataSource = self
        filtersCollection.isScrollEnabled = false
        filtersCollection.register(FilterCell.self, forCellWithReuseIdentifier: "FilterCell")
        view.addSubview(filtersCollection)
        
        if gifMode {
            gifMode = false /// set to false until user toggles on
            DispatchQueue.global(qos: .userInitiated).async { self.saveLivePhoto(stillImageData: self.imageData, livePhotoMovieURL: self.outputURL) }
        } else { saveStillPhoto(stillImage: unfilteredStill) }
    }
        
    func setUpNavBar() {
        
        if let mapVC = navigationController?.viewControllers.first(where: {$0 is MapViewController}) as? MapViewController {
            mapVC.customTabBar.tabBar.isHidden = true
        }
        
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.addShadow()
        navigationController?.navigationBar.addGradientBackground(alpha: 1.0)
        
        let backArrow = UIImage(named: "BackArrow")?.withRenderingMode(.alwaysOriginal)
        navigationController?.navigationBar.backIndicatorImage = backArrow
        navigationController?.navigationBar.backIndicatorTransitionMaskImage = backArrow
        navigationItem.backBarButtonItem?.tintColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        navigationItem.title = "Preview"

        let btnTitle = "Select"
        let action = #selector(selectTapped(_:))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: btnTitle, style: .plain, target: self, action: action)
        navigationItem.rightBarButtonItem?.setTitleTextAttributes([NSAttributedString.Key.foregroundColor : UIColor(named: "SpotGreen")!, NSAttributedString.Key.font : UIFont(name: "SFCamera-Semibold", size: 15)!], for: .normal)
    }
    
    func updateGif(animationImages: [UIImage]) {
        
        unfilteredImages = animationImages
        filteredImages = animationImages
        previewView.animationImages = animationImages
        
        aliveToggle = UIButton(frame: CGRect(x: previewView.frame.minX + 12, y: previewView.frame.maxY - 58, width: 94, height: 53))
        /// 74 x 33
        aliveToggle.setImage(UIImage(named: "AliveOff"), for: .normal)
        aliveToggle.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        aliveToggle.addTarget(self, action: #selector(toggleAlive(_:)), for: .touchUpInside)
        view.addSubview(aliveToggle)
    }
        
    @objc func selectTapped(_ sender: UIButton) {
        
        let images = gifMode ? filteredImages : [filteredStill]
        if delegate != nil { delegate?.finishPassingFromCamera(images: images) }
        if let uploadVC = navigationController?.viewControllers.first(where: {$0 is UploadPostController}) as? UploadPostController {
            navigationController?.popToViewController(uploadVC, animated: false)
        }
    }
    
    @objc func backTapped(_ sender: UIButton) {
        let controllers = self.navigationController?.viewControllers
        if let vc = controllers![controllers!.count - 2] as? AVCameraController {
            vc.animationImages.removeAll()
            self.navigationController?.popToViewController(vc, animated: true)
        } 
    }
    
    @objc func toggleAlive(_ sender: UIButton) {
                
        gifMode = !gifMode
        
        Mixpanel.mainInstance().track(event: "PreviewToggleAlive", properties: ["on": gifMode])

        let image = gifMode ? UIImage(named: "AliveOn") : UIImage(named: "AliveOff")
        aliveToggle.setImage(image, for: .normal)
        
        if gifMode {
            /// animate with gif images
            previewView.animationImages = filteredImages
            previewView.animateGIF(directionUp: true, counter: 0, frames: filteredImages.count, alive: false)
        } else {
            /// remove to stop animation and set to still image
            previewView.image = filteredStill
            previewView.animationImages?.removeAll()
        }
    }
    
    @objc func saveToDrafts(_ sender: UIButton) {

        // save draft to core data
        Mixpanel.mainInstance().track(event: "AliveSavedToDrafts")
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else { return }
        
        let managedContext = appDelegate.persistentContainer.viewContext
        
        let imagesArrayObject = ImagesArray(context: managedContext)
        var imageObjects : [ImageModel] = []
        
        var index: Int16 = 0
        
        let images = gifMode ? filteredImages : [filteredStill]
        for image in images {
            let im = ImageModel(context: managedContext)
            im.imageData = image.jpegData(compressionQuality: 0.5)
            im.position = index
            imageObjects.append(im)
            index += 1
        }
        
        let timestamp = NSDate().timeIntervalSince1970
        let seconds = Int64(timestamp)
        
        imagesArrayObject.id = seconds
        imagesArrayObject.images = NSSet(array: imageObjects)
        imagesArrayObject.uid = self.uid
        
        if !locationIsEmpty(location: UserDataModel.shared.currentLocation) {
            imagesArrayObject.postLat = NSNumber(value: UserDataModel.shared.currentLocation.coordinate.latitude)
            imagesArrayObject.postLong = NSNumber(value: UserDataModel.shared.currentLocation.coordinate.longitude)
        }
        
        do {
            try managedContext.save()
            self.draftTransition()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }

    func draftTransition() {
        UIView.transition(with: self.draftsButton,
                          duration: 0.5,
                          options: .transitionCrossDissolve,
                          animations: {
                            self.draftsButton.setImage(UIImage(named: "DraftSaved"), for: .normal)
        }, completion: nil)
        draftsButton.isUserInteractionEnabled = false
    }
    
    func saveStillPhoto(stillImage: UIImage) {
        SpotPhotoAlbum.sharedInstance.save(image: stillImage)
    }
    
    
    func saveLivePhoto(stillImageData: Data, livePhotoMovieURL: URL) {
        
        PHPhotoLibrary.requestAuthorization { status in
            
            guard status == .authorized else { return }
                        
            SpotPhotoAlbum.sharedInstance.save(videoURL: livePhotoMovieURL, imageData: stillImageData) { [weak self] complete, placeholder in
                
                guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier], options: .none).firstObject else { return }
                guard let self = self else { return }

                self.fetchCameraLive(currentAsset: asset, completion: { animationImages, failed in
                    
                    if failed || animationImages.isEmpty { return }
                    
                    let userInfo: [String: Any] = ["gifImages" : animationImages]
                    NotificationCenter.default.post(Notification(name: NSNotification.Name("LiveProcessed"), object: nil, userInfo: userInfo))
                })
            }
        }
    }
    
    func fetchCameraLive(currentAsset: PHAsset, completion: @escaping(_ animationImages: [UIImage], _ failed: Bool) -> Void) {
        
        var animationImages: [UIImage] = []
        
        let editingOptions = PHContentEditingInputRequestOptions()
        editingOptions.isNetworkAccessAllowed = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            currentAsset.requestContentEditingInput(with: editingOptions) { [weak self] input, info in
                
                guard let self = self else { return }
                if self.cancelOnDismiss { completion([], false); return }
                
                if info["PHContentEditingInputCancelledKey"] != nil { completion([UIImage()], false); return }
                if info["PHContentEditingInputErrorKey"] != nil { completion([UIImage()], true); return }
                
                var frameImages: [UIImage] = []
                
                if let input = input {
                    
                    let context = PHLivePhotoEditingContext(livePhotoEditingInput: input)
                    
                    /// download live photos by cycling through frame processor and capturing frames
                    context!.frameProcessor = { frame, _ in
                        frameImages.append(UIImage(ciImage: frame.image))
                        return frame.image
                    }
                    
                    let output = PHContentEditingOutput(contentEditingInput: input)
                    
                    context?.saveLivePhoto(to: output, options: nil, completionHandler: { [weak self] success, err in
                        
                        guard let self = self else { return }
                        if self.cancelOnDismiss { completion([], false); return }

                        if !success || err != nil || frameImages.isEmpty { completion([UIImage()], false); return }
                        
                        /// distanceBetweenFrames fixed at 2 right now, always taking the middle 16 frames of the Live often with large offsets. This number is variable though
                        let distanceBetweenFrames: Double = 2
                        let rawFrames = Double(frameImages.count) / distanceBetweenFrames
                        let numberOfFrames: Double = rawFrames > 11 ? 9 : rawFrames > 7 ? max(7, rawFrames - 2) : rawFrames
                        let rawOffsest = max((rawFrames - numberOfFrames) * distanceBetweenFrames/2, 2) /// offset on beginning and ending of the frames
                        let offset = Int(rawOffsest)
                        
                        let aspect = frameImages[0].size.height / frameImages[0].size.width
                        let size = CGSize(width: min(frameImages[0].size.width, UIScreen.main.bounds.width * 1.5), height: min(frameImages[0].size.height, aspect * UIScreen.main.bounds.width * 1.5))
                        
                        var image0 = self.ResizeImage(with: frameImages[offset], scaledToFill: size) ?? UIImage()
                        if self.frontFacing { image0 = UIImage(cgImage: image0.cgImage!, scale: image0.scale, orientation: UIImage.Orientation.upMirrored) } /// mirror image for front facing cam
                        animationImages.append(image0 )
                        
                        /// add middle frames, trimming first couple and last couple
                        let intMultiplier = (frameImages.count - offset * 2)/Int(numberOfFrames)
                        for i in 1...Int(numberOfFrames) {
                            let multiplier = offset + intMultiplier * i
                            let j = multiplier > frameImages.count - 1 ? frameImages.count - 1 : multiplier
                            var image = self.ResizeImage(with: frameImages[j], scaledToFill: size) ?? UIImage()
                            if self.frontFacing { image = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: UIImage.Orientation.upMirrored) }
                            animationImages.append(image)
                        }
                        
                        DispatchQueue.main.async { self.updateGif(animationImages: animationImages) }
                    })
                }
            }
        }
    }

}

extension GIFPreviewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 5
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FilterCell", for: indexPath) as? FilterCell else { return UICollectionViewCell() }
        let filterValues = filter(image: unfilteredStill, item: indexPath.row)
        cell.setUp(item: indexPath.row, selectedItem: selectedItem, images: unfilteredImages, coverImage: filterValues.0, text: filterValues.1)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
                        
        if indexPath.row == selectedItem { return } /// can't deselect a filter
        
        filteredStill = filter(image: unfilteredStill, item: indexPath.row).0
        if filteredImages.count > 0 { for i in 0...self.filteredImages.count - 1 {
            self.filteredImages[i] = filter(image: self.unfilteredImages[i], item: indexPath.row).0
        } }
        
        if gifMode {
            previewView.animationImages = filteredImages
            
        } else {
            previewView.image = self.filteredStill
        }
        
        selectedItem = indexPath.row
        DispatchQueue.main.async { collectionView.reloadData() }
        
        /// update images with filtered image
    }
    
    func filter(image: UIImage, item: Int) -> (UIImage, String) {
                
        switch item {
        
        case 0: return ink(image: image)
            
        case 1: return pop(image: image)

        case 2: return og(image: image)

        case 3: return haze(image: image)

        default: return sakura(image: image)

        }
    }
    
    func ink(image: UIImage) -> (UIImage , String) {
        let originalImage = CIImage(image: image)
        let filtered0 = inputFilter(image: originalImage ?? CIImage(), saturation: 0.0, brightness: -0.008, contrast: 1.018, vibrance: 0.0, hue: 0.0, exposure: 0.0, warmth: 0, tint: 0.0, highlights: 0.974, shadows: 0.0, sharpness: 0.42)
        let filtered1 = context.createCGImage(filtered0!, from: filtered0!.extent)!
        var newImage = UIImage(cgImage: filtered1)
        if frontFacing { newImage = UIImage(cgImage: newImage.cgImage!, scale: newImage.scale, orientation: UIImage.Orientation.upMirrored) } /// mirror image for front facing cam
        return (newImage, "INK")
    }
    
    func sakura(image: UIImage) -> (UIImage , String) {
        let originalImage = CIImage(image: image)
        let filtered0 = inputFilter(image: originalImage ?? CIImage(), saturation: 1.005, brightness: 0.0, contrast: 0.9, vibrance: 0.2, hue: 0.0, exposure: 0.0, warmth: -0.15, tint: 0.45, highlights: 1.0, shadows: -0.01, sharpness: 0.038)
        let filtered1 = context.createCGImage(filtered0!, from: filtered0!.extent)!
        var newImage = UIImage(cgImage: filtered1)
        if frontFacing { newImage = UIImage(cgImage: newImage.cgImage!, scale: newImage.scale, orientation: UIImage.Orientation.upMirrored) } /// mirror image for front facing cam
        return (newImage, "SAKURA")
    }

    func og(image: UIImage) -> (UIImage , String) {
        let originalImage = CIImage(image: image)
        let filtered0 = inputFilter(image: originalImage ?? CIImage(), saturation: 1.022, brightness: 0.0, contrast: 1.009, vibrance: 0.122, hue: 0.002, exposure: 0.0, warmth: 0.0, tint: 0.0, highlights: 1.0, shadows: 0.0, sharpness: 0.4)
        let filtered1 = context.createCGImage(filtered0!, from: filtered0!.extent)!
        var newImage = UIImage(cgImage: filtered1)
        if frontFacing { newImage = UIImage(cgImage: newImage.cgImage!, scale: newImage.scale, orientation: UIImage.Orientation.upMirrored) } /// mirror image for front facing cam
        return (newImage, "OG")
    }
    
    func haze(image: UIImage) -> (UIImage , String) {
        let originalImage = CIImage(image: image)
        let filtered0 = inputFilter(image: originalImage ?? CIImage(), saturation: 0.94, brightness: 0.0, contrast: 0.992, vibrance: 0.1, hue: 0.0, exposure: 0.0, warmth: 0.45, tint: -0.16, highlights: 1.007, shadows: 0.0, sharpness: 0.403)
        let filtered1 = context.createCGImage(filtered0!, from: filtered0!.extent)!
        var newImage = UIImage(cgImage: filtered1)
        if frontFacing { newImage = UIImage(cgImage: newImage.cgImage!, scale: newImage.scale, orientation: UIImage.Orientation.upMirrored) } /// mirror image for front facing cam
        return (newImage, "HAZE")
    }

    func pop(image: UIImage) -> (UIImage , String) {
        let originalImage = CIImage(image: image)
        let filtered0 = inputFilter(image: originalImage ?? CIImage(), saturation: 1.016, brightness: -0.008, contrast: 1.018, vibrance: 0.0, hue: 0.0, exposure: 0.0, warmth: 0, tint: 0.0, highlights: 0.974, shadows: 0.0, sharpness: 0.42)
        let filtered1 = context.createCGImage(filtered0!, from: filtered0!.extent)!
        var newImage = UIImage(cgImage: filtered1)
        if frontFacing { newImage = UIImage(cgImage: newImage.cgImage!, scale: newImage.scale, orientation: UIImage.Orientation.upMirrored) } /// mirror image for front facing cam
        return (newImage, "POP")
    }
    
    
    func inputFilter(image: CIImage, saturation: Float, brightness: Float, contrast: Float, vibrance: Float, hue: Float, exposure: Float, warmth: Float, tint: Float, highlights: Float, shadows: Float, sharpness: Float) -> CIImage? {
        
        let filter0 = CIFilter.colorControls()
        filter0.inputImage = image
        filter0.saturation = saturation
        filter0.brightness = brightness
        filter0.contrast = contrast
        var result = filter0.outputImage!
        
        let filter1 = CIFilter.vibrance()
        filter1.setValue(result, forKey: kCIInputImageKey)
        filter1.amount = vibrance
        result = filter1.outputImage!
        
        let filter2 = CIFilter.hueAdjust()
        filter2.setValue(result, forKey: kCIInputImageKey)
        filter2.angle = hue
        result = filter2.outputImage!
        
        let filter3 = CIFilter.exposureAdjust()
        filter3.setValue(result, forKey: kCIInputImageKey)
        filter3.ev = exposure
        result = filter3.outputImage!
                
        let filter5 = CIFilter.temperatureAndTint()
        filter5.setValue(result, forKey: kCIInputImageKey)
                
        if warmth == -1 {
            filter5.neutral =  CIVector(x: 16000, y: 1000)
            filter5.targetNeutral = CIVector(x: 1000, y: 500)
        } else if warmth == 1 {
            filter5.neutral = CIVector(x: 6500, y: 500)
            filter5.targetNeutral = CIVector(x: 1000, y: 630)

        } else {
            let warmth: Float = 5000 * warmth
            let tint: Float = 100 * tint
            filter5.neutral = (CIVector(x: 6500 + CGFloat(warmth), y: CGFloat(tint)))
        }
        result = filter5.outputImage!
        
        let filter6 = CIFilter.highlightShadowAdjust()
        filter6.setValue(result, forKey: kCIInputImageKey)
        filter6.highlightAmount = highlights
        filter6.shadowAmount = shadows
        result = filter6.outputImage!
        
        let filter7 = CIFilter.noiseReduction()
        filter7.setValue(result, forKey: kCIInputImageKey)
        filter7.sharpness = sharpness
        result = filter7.outputImage!
                
        return result
    }
}

class FilterCell: UICollectionViewCell {
        
    var bottomMask: UIView!
    var imageView: UIImageView!
    var filterName: UILabel!
    
    func setUp(item: Int, selectedItem: Int, images: [UIImage], coverImage: UIImage, text: String) {
        
        resetView()
                
        imageView = UIImageView(frame: self.bounds)
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 3
        imageView.layer.masksToBounds = true
        imageView.image = coverImage
        addSubview(imageView)
        
        let layer0 = CAGradientLayer()
        layer0.frame = imageView.bounds
        layer0.colors = [
            UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
            UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 0.3).cgColor,
            UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 0.8).cgColor
        ]
        layer0.locations = [0.0, 0.49, 1.0]
        layer0.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer0.endPoint = CGPoint(x: 0.5, y: 1.0)
        imageView.layer.addSublayer(layer0)
        
        filterName = UILabel(frame: CGRect(x: 2, y: 52, width: self.bounds.width - 4, height: 15))
        filterName.textColor = .white
        filterName.font = UIFont(name: "SFCamera-Regular", size: 11.5)
        filterName.textAlignment = .center
        filterName.text = text
        addSubview(filterName)
        
        layer.cornerRadius = 3
        
        if item == selectedItem {
            layer.borderColor = UIColor.white.cgColor
            layer.borderWidth = 1.5
        }
    }
    
    func resetView() {
        layer.borderWidth = 0.0
        if imageView != nil { imageView.image = UIImage() }
        if filterName != nil { filterName.text = "" }
    }
}



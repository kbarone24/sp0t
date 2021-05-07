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
    func FinishPassing(images: [(UIImage)])
}

class GIFPreviewController: UIViewController {
    
    unowned var mapVC: MapViewController!
    var spotObject: MapSpot!
    
    var unfilteredImages: [UIImage] = []
    var filteredImages: [UIImage] = []

    var draftID: Int64!
    var gif = false
    var previewView: UIImageView!
    var draftsButton: UIButton!
    var delegate: GIFPreviewDelegate?
    var offset: CGFloat = 0
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    
    var filtersCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    var selectedItem = 2
    let context = CIContext()
        
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
        Mixpanel.mainInstance().track(event: "GIFOpen")
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        
        let cameraAspect: CGFloat = 1.72267
        var cameraWidth = UIScreen.main.bounds.width - 42
        var cameraHeight = cameraWidth * cameraAspect

        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        let navBarHeight = statusHeight +
                    (self.navigationController?.navigationBar.frame.height ?? 44.0)
        let viewHeight = UIScreen.main.bounds.height - navBarHeight
        
        var minX: CGFloat = 21
        if cameraHeight > viewHeight - 107 {
            cameraHeight = viewHeight - 107
            cameraWidth = cameraHeight/1.72267
            minX = (UIScreen.main.bounds.width - cameraWidth) / 2
        }
        
        /// apply og filter to all images
        for i in 0...unfilteredImages.count - 1 {
            filteredImages.append(og(image: unfilteredImages[i]).0)
        }
                
        previewView = UIImageView(frame: CGRect(x: minX, y: 16, width: cameraWidth, height: cameraHeight))
        if !gif { previewView.image = filteredImages[0] }
        previewView.contentMode = .scaleAspectFill
        previewView.clipsToBounds = true
        previewView.isUserInteractionEnabled = true
        previewView.layer.cornerRadius = 12
        view.addSubview(previewView)
        if gif { previewView.animationImages = filteredImages; previewView.animateGIF(directionUp: true, counter: 0) }
                   
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
        
    }
        
    func setUpNavBar() {
        
        mapVC.customTabBar.tabBar.isHidden = true
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.addShadow()
        navigationController?.navigationBar.addBackgroundImage(alpha: 1.0)
        
        let backArrow = UIImage(named: "BackArrow")?.withRenderingMode(.alwaysOriginal)
        navigationController?.navigationBar.backIndicatorImage = backArrow
        navigationController?.navigationBar.backIndicatorTransitionMaskImage = backArrow
        navigationItem.backBarButtonItem?.tintColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        navigationItem.title = "Preview"

        let btnTitle = "Next"
        let action = #selector(nextTap(_:))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: btnTitle, style: .plain, target: self, action: action)
        navigationItem.rightBarButtonItem?.setTitleTextAttributes([NSAttributedString.Key.foregroundColor : UIColor(named: "SpotGreen")!, NSAttributedString.Key.font : UIFont(name: "SFCamera-Semibold", size: 15)!], for: .normal)
    }
        
    @objc func nextTap(_ sender: UIButton) {
        //      delegate?.FinishPassing(images: photos)

        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "LocationPicker") as? LocationPickerController {
            vc.gifMode = self.gif
            vc.selectedImages = self.filteredImages
            vc.mapVC = self.mapVC
            vc.spotObject = self.spotObject
            
            ///image from camera indicates to location picker to use the current location
            vc.imageFromCamera = true 
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @objc func backTapped(_ sender: UIButton) {
        let controllers = self.navigationController?.viewControllers
        if let vc = controllers![controllers!.count - 2] as? AVCameraController {
            vc.animationImages.removeAll()
            self.navigationController?.popToViewController(vc, animated: true)
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
        for image in filteredImages {
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
        
        if mapVC.currentLocation != nil {
            imagesArrayObject.postLat = NSNumber(value: mapVC.currentLocation.coordinate.latitude)
            imagesArrayObject.postLong = NSNumber(value: mapVC.currentLocation.coordinate.longitude)
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
}

extension GIFPreviewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 5
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FilterCell", for: indexPath) as? FilterCell else { return UICollectionViewCell() }
        let filterValues = filter(image: unfilteredImages[0], item: indexPath.row)
        cell.setUp(item: indexPath.row, selectedItem: selectedItem, images: unfilteredImages, coverImage: filterValues.0, text: filterValues.1)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
                        
        if indexPath.row == selectedItem { return } /// can't deselect a filter
        
        for i in 0...self.filteredImages.count - 1 {
            self.filteredImages[i] = filter(image: self.unfilteredImages[i], item: indexPath.row).0
        }
        
        if gif {
            previewView.animationImages = filteredImages

        } else {
            previewView.image = self.filteredImages[0]
        }
        
        selectedItem = indexPath.row
        DispatchQueue.main.async { collectionView.reloadData() }
        
        /// update images with filtered image
    }
    
    func filter(image: UIImage, item: Int) -> (UIImage, String) {
                
        switch item {
        
        case 0:
           return ink(image: image)
            
        case 1:
            return pop(image: image)

        case 2:
            return og(image: image)

        case 3:
            return haze(image: image)

        default:
            return sakura(image: image)

        }
    }
    
    func ink(image: UIImage) -> (UIImage , String) {
        let originalImage = CIImage(image: image)
        let filtered0 = inputFilter(image: originalImage ?? CIImage(), saturation: 0.0, brightness: -0.008, contrast: 1.018, vibrance: 0.0, hue: 0.0, exposure: 0.0, warmth: 0, tint: 0.0, highlights: 0.974, shadows: 0.0, sharpness: 0.42)
        let filtered1 = context.createCGImage(filtered0!, from: filtered0!.extent)!
        let newImage = UIImage(cgImage: filtered1)
        return (newImage, "INK")
    }
    
    func sakura(image: UIImage) -> (UIImage , String) {
        let originalImage = CIImage(image: image)
        let filtered0 = inputFilter(image: originalImage ?? CIImage(), saturation: 1.005, brightness: 0.0, contrast: 0.9, vibrance: 0.2, hue: 0.0, exposure: 0.0, warmth: -0.15, tint: 0.45, highlights: 1.0, shadows: -0.01, sharpness: 0.038)
        let filtered1 = context.createCGImage(filtered0!, from: filtered0!.extent)!
        let newImage = UIImage(cgImage: filtered1)
        return (newImage, "SAKURA")
    }

    func og(image: UIImage) -> (UIImage , String) {
        let originalImage = CIImage(image: image)
        let filtered0 = inputFilter(image: originalImage ?? CIImage(), saturation: 1.022, brightness: 0.0, contrast: 1.009, vibrance: 0.122, hue: 0.002, exposure: 0.0, warmth: 0.0, tint: 0.0, highlights: 1.0, shadows: 0.0, sharpness: 0.4)
        let filtered1 = context.createCGImage(filtered0!, from: filtered0!.extent)!
        let newImage = UIImage(cgImage: filtered1)
        return (newImage, "OG")
    }
    
    func haze(image: UIImage) -> (UIImage , String) {
        let originalImage = CIImage(image: image)
        let filtered0 = inputFilter(image: originalImage ?? CIImage(), saturation: 0.94, brightness: 0.0, contrast: 0.992, vibrance: 0.1, hue: 0.0, exposure: 0.0, warmth: 0.45, tint: -0.16, highlights: 1.007, shadows: 0.0, sharpness: 0.403)
        let filtered1 = context.createCGImage(filtered0!, from: filtered0!.extent)!
        let newImage = UIImage(cgImage: filtered1)
        return (newImage, "HAZE")
    }

    func pop(image: UIImage) -> (UIImage , String) {
        let originalImage = CIImage(image: image)
        let filtered0 = inputFilter(image: originalImage ?? CIImage(), saturation: 1.016, brightness: -0.008, contrast: 1.018, vibrance: 0.0, hue: 0.0, exposure: 0.0, warmth: 0, tint: 0.0, highlights: 0.974, shadows: 0.0, sharpness: 0.42)
        let filtered1 = context.createCGImage(filtered0!, from: filtered0!.extent)!
        let newImage = UIImage(cgImage: filtered1)
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



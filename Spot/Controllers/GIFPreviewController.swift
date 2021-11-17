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

protocol GIFPreviewDelegate {
    func finishPassingFromCamera(images: [UIImage])
}

class GIFPreviewController: UIViewController {
    
    var spotObject: MapSpot!
    var delegate: GIFPreviewDelegate?
    
    var imageData: Data!
    var outputURL: URL!
    var frontFacing = false /// to rotate gif images when returned to the user
        
    var selectedImages: [UIImage] = []

    var gifMode = false
    var previewView: UIImageView!
    var aliveToggle: UIButton!
    var draftsButton: UIButton!
    var offset: CGFloat = 0
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    
    var selectedItem = 2
    var cancelOnDismiss = false
    
    var retakeButton: UIButton!
    var selectButton: UIButton!
            
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
        let cameraHeight = UIScreen.main.bounds.width * cameraAspect
        let minY : CGFloat = UIScreen.main.bounds.height > 800 ? 82 : 2

        previewView = UIImageView(frame: CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: cameraHeight))
        previewView.contentMode = .scaleAspectFill
        previewView.clipsToBounds = true
        previewView.isUserInteractionEnabled = true
        view.addSubview(previewView)
        
        if gifMode {
            previewView.animationImages = selectedImages
            previewView.animateGIF(directionUp: true, counter: 0, frames: selectedImages.count, alive: false)
        } else {
            previewView.image = selectedImages.first ?? UIImage()
        }
        
        retakeButton = UIButton(frame: CGRect(x: 22, y: previewView.frame.maxY + 16, width: 99, height: 39))
        retakeButton.contentHorizontalAlignment = .center
        retakeButton.contentVerticalAlignment = .center
        retakeButton.setTitle("Retake", for: .normal)
        retakeButton.setTitleColor(.white, for: .normal)
        retakeButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
        retakeButton.layer.borderWidth = 1.5
        retakeButton.layer.borderColor = UIColor(red: 0.363, green: 0.363, blue: 0.363, alpha: 1).cgColor
        retakeButton.layer.cornerRadius = 12
        retakeButton.addTarget(self, action: #selector(retakeTap(_:)), for: .touchUpInside)
        view.addSubview(retakeButton)
        
        selectButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 119, y: retakeButton.frame.minY, width: retakeButton.frame.width, height: retakeButton.frame.height))
        selectButton.contentHorizontalAlignment = .center
        selectButton.contentVerticalAlignment = .center
        selectButton.setTitle("Use photo", for: .normal)
        selectButton.setTitleColor(.black, for: .normal)
        selectButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
        selectButton.backgroundColor = UIColor(named: "SpotGreen")
        selectButton.layer.cornerRadius = 12
        selectButton.addTarget(self, action: #selector(selectTap(_:)), for: .touchUpInside)
        view.addSubview(selectButton)

    }
                
    @objc func selectTap(_ sender: UIButton) {
        
        if delegate != nil { delegate?.finishPassingFromCamera(images: selectedImages) }
        if let uploadVC = navigationController?.viewControllers.first(where: {$0 is UploadPostController}) as? UploadPostController {
            navigationController?.popToViewController(uploadVC, animated: false)
        }
    }
    
    @objc func retakeTap(_ sender: UIButton) {
        let controllers = self.navigationController?.viewControllers
        if let vc = controllers![controllers!.count - 2] as? AVCameraController {
            vc.animationImages.removeAll()
            self.navigationController?.popToViewController(vc, animated: true)
        } 
    }
}

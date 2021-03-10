//
//  TutorialViewController.swift
//  Spot
//
//  Created by kbarone on 4/9/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import GoogleMaps

class TutorialViewController: UIViewController {
    var mapView: GMSMapView!
    var drawer: UIView!
    var spotPreview: UIButton!
    var dialogue: UILabel!
    var nextButton: UIButton!
    var previewText: UILabel!
    var postScroll: UIScrollView!
    var directionsLabel: UILabel!
    var highlightedPost: UIImageView!
    var shadowButton: UIButton!
    
    var bottomMask: UIView!
    var topMask: UIView!
    var centerPoint: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: -77.846156, longitude: 166.664954)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView = GMSMapView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 100), camera: GMSCameraPosition(latitude: centerPoint.latitude, longitude: centerPoint.longitude, zoom: 17.5))
        print("viewing angle", mapView.camera.viewingAngle)
        mapView.animate(toViewingAngle: 60.0)
        mapView.isBuildingsEnabled = true
        mapView.isUserInteractionEnabled = false
        hideLandmarks(mapView: mapView)
        view.addSubview(mapView)
        
        let marker = GMSMarker(position: CLLocationCoordinate2D(latitude: centerPoint.latitude, longitude: centerPoint.longitude))
        marker.map = mapView
        marker.icon = UIImage(named: "RainbowSpotIcon")
        marker.setIconSize(scaledToSize: CGSize(width: 40, height: 40))
        marker.isFlat = true
        marker.isTappable = false
        
        var dialogueY: CGFloat = UIScreen.main.bounds.height - 110
        var halfScreenY : CGFloat = UIScreen.main.bounds.height - 400
        if (UIScreen.main.nativeBounds.height > 2400 || UIScreen.main.nativeBounds.height == 1792) {
            halfScreenY = UIScreen.main.bounds.height - 420
            dialogueY -= 10
        }
        print("half screen y", halfScreenY)
        
        drawer = UIView(frame: CGRect(x: 0, y: halfScreenY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - halfScreenY))
        drawer.backgroundColor = UIColor(named: "SpotBlack")
        drawer.layer.cornerRadius =  13
        view.addSubview(drawer)

        spotPreview = UIButton(frame: CGRect(x: 19, y: 24.5, width: 147, height: 216))
        spotPreview.setImage(UIImage(named: "SpotworldPreview"), for: .normal)
        spotPreview.imageView?.contentMode = .scaleAspectFill
        spotPreview.addTarget(self, action: #selector(openSpotworld(_:)), for: .touchUpInside)
        drawer.addSubview(spotPreview)
        
        previewText = UILabel(frame: CGRect(x: 22, y: spotPreview.frame.maxY + 8, width: 100, height: 19))
        previewText.text = "sp0tw0rld"
        previewText.font = UIFont(name: "SFCamera-Semibold", size: 14)
        previewText.textColor = UIColor(red:0.83, green:0.83, blue:0.83, alpha:1.00)
        previewText.sizeToFit()
        drawer.addSubview(previewText)
        
        let dialogueBox = UIView(frame: CGRect(x: 0, y: dialogueY, width: UIScreen.main.bounds.width, height: dialogueY + 5))
        dialogueBox.backgroundColor = UIColor(patternImage: UIImage(named: "OnboardDialogueBackground")!)
        dialogueBox.layer.cornerRadius = 10
        
        view.addSubview(dialogueBox)
        
        let bot = UIImageView(frame: CGRect(x: 18, y: 11, width: 29, height: 34))
        bot.image = UIImage(named: "OnboardB0t")
        bot.contentMode = .scaleAspectFit
        dialogueBox.addSubview(bot)
        
        let botHandle = UILabel(frame: CGRect(x: bot.frame.maxX + 7, y: 15, width: 100, height: 20))
        botHandle.text = "sp0tb0t"
        botHandle.textColor = UIColor(red:0.82, green:0.82, blue:0.82, alpha:1.00)
        botHandle.font = UIFont(name: "SFCamera-Semibold", size: 14)
        botHandle.sizeToFit()
        dialogueBox.addSubview(botHandle)
        
        dialogue = UILabel(frame: CGRect(x: bot.frame.maxX + 7, y: botHandle.frame.maxY + 2, width: UIScreen.main.bounds.width - 70, height: 20))
        dialogue.numberOfLines = 0
        dialogue.lineBreakMode = .byWordWrapping
        dialogue.text = "Open sp0tw0rld to check out a spot"
        dialogue.font = UIFont(name: "SFCamera-Regular", size: 16)
        dialogue.textColor = UIColor(red:0.67, green:0.67, blue:0.67, alpha:1.00)
        dialogue.sizeToFit()
        dialogueBox.addSubview(dialogue)
        
        self.nextButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 90, y: 28, width: 73, height: 47))
        self.nextButton.setImage(UIImage(named: "NextArrowOnboarding"), for: .normal)
        self.nextButton.addTarget(self, action: #selector(nextTapped0(_:)), for: .touchUpInside)
        self.nextButton.imageView?.contentMode = .scaleAspectFit
        self.nextButton.isHidden = true
        dialogueBox.addSubview(nextButton)
        
        
        shadowButton = UIButton(frame: view.frame)
        shadowButton.addTarget(self, action: #selector(openSpotworld(_:)), for: .touchUpInside)
        view.addSubview(shadowButton)
    }
    
    @objc func openSpotworld(_ sender: UIButton) {
        shadowButton.removeFromSuperview()
        
        UIView.animate(withDuration: 0.3) {
            self.drawer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            self.drawer.layer.cornerRadius = 0
            
            self.spotPreview.isHidden = true
            self.previewText.isHidden = true
            
            var minY: CGFloat = 60
            if (!(UIScreen.main.nativeBounds.height > 2400 || UIScreen.main.nativeBounds.height == 1792)) {
                minY = 40
            }
            
            let descriptionView = UIView(frame: CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: 90))
            descriptionView.backgroundColor = UIColor(named: "SpotBlack")
            self.drawer.addSubview(descriptionView)
            
            let privacyView = UIView(frame: CGRect(x: 12, y: 13, width: 45, height: 16))
            let privacyLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 45, height: 16))
            privacyLabel.textAlignment = .center
            privacyLabel.text = "Public"
            privacyLabel.textColor = .black
            privacyView.backgroundColor = UIColor(red:0.37, green:0.37, blue:0.37, alpha:1.00)
            privacyLabel.font = UIFont(name: "SFCamera-Semibold", size: 11)
            privacyView.layer.cornerRadius = 4
            privacyView.addSubview(privacyLabel)
            descriptionView.addSubview(privacyView)
            
            let natureTag = UIImageView(frame: CGRect(x: 69, y: 9, width: 22, height: 22))
            natureTag.image = UIImage(named: "SpotPageNature")
            descriptionView.addSubview(natureTag)
            
            let sunsetTag = UIImageView(frame: CGRect(x: natureTag.frame.maxX + 4, y: 9, width: 22, height: 22))
            sunsetTag.image = UIImage(named: "SpotPageSunset")
            descriptionView.addSubview(sunsetTag)
            
            let weirdTag = UIImageView(frame: CGRect(x: sunsetTag.frame.maxX + 4, y: 9, width: 22, height: 22))
            weirdTag.image = UIImage(named: "SpotPageWeird")
            descriptionView.addSubview(weirdTag)
            
            let spotName = UILabel(frame: CGRect(x: 12, y: 36, width: 300, height: 24))
            spotName.textColor = UIColor(red:0.88, green:0.88, blue:0.88, alpha:1.0)
            spotName.font = UIFont(name: "SFCamera-Semibold", size: 20)
            spotName.text = "sp0tw0rld"
            spotName.sizeToFit()
            descriptionView.addSubview(spotName)
            
            
            let spotDescription = UILabel(frame: CGRect(x: 12, y: 64, width: UIScreen.main.bounds.width - 24, height: 20))
            spotDescription.textColor = UIColor(red:0.71, green:0.71, blue:0.71, alpha:1.0)
            spotDescription.font = UIFont(name: "SFCamera-Regular", size: 14)
            spotDescription.text = "Home to sp0tb0ts, welcome to all"
            spotDescription.lineBreakMode = .byWordWrapping
            spotDescription.numberOfLines = 0
            spotDescription.sizeToFit()
            descriptionView.addSubview(spotDescription)
            
            self.postScroll = UIScrollView(frame: CGRect(x: 0, y: descriptionView.frame.maxY + 20, width: UIScreen.main.bounds.width, height: 150))
            self.postScroll.backgroundColor = UIColor(named: "SpotBlack")
            self.postScroll.contentSize = CGSize(width: 500, height: 150)
            
            self.drawer.addSubview(self.postScroll)
            
            let addButton = UIImageView(frame: CGRect(x: 14.5, y: 0.5, width: 99, height: 149))
            addButton.image = UIImage(named: "AddToSpotBackground")
            addButton.contentMode = .scaleAspectFill
            self.postScroll.addSubview(addButton)
            
            let imagePreview = UIImageView(frame: CGRect(x: 7, y: 46, width: 86, height: 48))
            imagePreview.image = UIImage(named: "AddToSpotButton")
            imagePreview.clipsToBounds = true
            imagePreview.contentMode = .scaleAspectFit
            addButton.addSubview(imagePreview)
            
            let post1 = UIImageView(frame: CGRect(x: addButton.frame.maxX + 8, y: 0, width: 100, height: 150))
            post1.image = UIImage(named: "SpotworldPost1")
            post1.contentMode = .scaleAspectFill
            self.postScroll.addSubview(post1)
            
            let post2 = UIImageView(frame: CGRect(x: post1.frame.maxX + 8, y: 0, width: 100, height: 150))
            post2.image = UIImage(named: "SpotworldPost2")
            post2.contentMode = .scaleAspectFill
            self.postScroll.addSubview(post2)
            
            let post3 = UIImageView(frame: CGRect(x: post2.frame.maxX + 8, y: 0, width: 100, height: 150))
            post3.image = UIImage(named: "SpotworldPost3")
            post3.contentMode = .scaleAspectFill
            self.postScroll.addSubview(post3)
            
            let friendsLabel = UILabel(frame: CGRect(x: 14, y: self.postScroll.frame.maxY + 23, width: 80, height: 17))
            friendsLabel.text = "4 friends"
            friendsLabel.textColor = UIColor(red:0.54, green:0.54, blue:0.54, alpha:1.00)
            friendsLabel.font = UIFont(name: "SFCamera-Semibold", size: 15)
            friendsLabel.sizeToFit()
            self.drawer.addSubview(friendsLabel)
            
            let bot1 = UIImageView(frame: CGRect(x: 20, y: friendsLabel.frame.maxY + 7, width: 36, height: 36))
            bot1.image = UIImage(named: "Bot1Tutorial")
            self.drawer.addSubview(bot1)
            
            let bot2 = UIImageView(frame: CGRect(x: bot1.frame.maxX + 12, y: friendsLabel.frame.maxY + 7, width: 36, height: 36))
            bot2.image = UIImage(named: "Bot2Tutorial")
            self.drawer.addSubview(bot2)
            
            let bot3 = UIImageView(frame: CGRect(x: bot2.frame.maxX + 12, y: friendsLabel.frame.maxY + 7, width: 36, height: 36))
            bot3.image = UIImage(named: "Bot3Tutorial")
            self.drawer.addSubview(bot3)
            
            let bot4 = UIImageView(frame: CGRect(x: bot3.frame.maxX + 12, y: friendsLabel.frame.maxY + 7, width: 36, height: 36))
            bot4.image = UIImage(named: "Bot4Tutorial")
            self.drawer.addSubview(bot4)
            
            self.directionsLabel = UILabel(frame: CGRect(x: 14, y: bot1.frame.maxY + 34, width: 80, height: 18))
            self.directionsLabel.text = "Directions"
            self.directionsLabel.textColor = UIColor(red:0.54, green:0.54, blue:0.54, alpha:1.00)
            self.directionsLabel.font = UIFont(name: "SFCamera-Semibold", size: 15)
            self.directionsLabel.sizeToFit()
            self.drawer.addSubview(self.directionsLabel)
            
            let containerView = UIImageView(frame: CGRect(x: 14, y: self.directionsLabel.frame.maxY + 13, width: 100, height: 100))
            containerView.layer.cornerRadius = 10
            containerView.image = UIImage(named: "OnboardMap")
            containerView.clipsToBounds = true
            containerView.contentMode = .scaleAspectFill
            self.drawer.addSubview(containerView)
            
            let address = UILabel(frame: CGRect(x: 130, y: self.directionsLabel.frame.maxY + 33, width: 100, height: 20))
            address.text = "22 bot dr, sp0tw0rld, ZY"
            address.textColor = UIColor(red:0.71, green:0.71, blue:0.71, alpha:1.00)
            address.font = UIFont(name: "SFCamera-Regular", size: 14)
            address.sizeToFit()
            self.drawer.addSubview(address)
            
            let directionsImage = UIImageView(frame: CGRect(x: 130, y: address.frame.maxY + 10, width: 12, height: 12))
            directionsImage.image = UIImage(named:("GreenArrow"))
            directionsImage.clipsToBounds = true
            directionsImage.contentMode = .scaleAspectFit
            self.drawer.addSubview(directionsImage)
            
            let startLabel = UILabel(frame: CGRect(x: 149, y: address.frame.maxY + 5, width: 100, height: 18))
            startLabel.text = "Start"
            startLabel.textColor = UIColor(named: "SpotGreen")
            startLabel.font = UIFont(name: "SFCamera-Semibold", size: 15)
            self.drawer.addSubview(startLabel)
            
            self.nextButton.isHidden = false
            
            self.dialogue.frame = CGRect(x: self.dialogue.frame.minX, y: self.dialogue.frame.minY, width: UIScreen.main.bounds.width - 150, height: 20)
            self.dialogue.text = "This is a spot page. Here you can find info and posts to the spot"
            self.dialogue.sizeToFit()
            
            self.topMask = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: descriptionView.frame.minY - 2))
            self.topMask.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            self.drawer.addSubview(self.topMask)
            
            self.bottomMask = UIView(frame: CGRect(x: 0, y: self.postScroll.frame.maxY + 10, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - self.postScroll.frame.maxY))
            self.bottomMask.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            self.drawer.addSubview(self.bottomMask)
        }
    }
    
    @objc func nextTapped0(_ sender: UIButton) {
        UIView.animate(withDuration: 0.3) {
            self.bottomMask.frame = CGRect(x: 0, y: self.directionsLabel.frame.minY - 22, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - self.directionsLabel.frame.maxY)
            
            self.topMask.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: self.postScroll.frame.maxY + 11)
            
            self.dialogue.frame = CGRect(x: self.dialogue.frame.minX, y: self.dialogue.frame.minY, width: UIScreen.main.bounds.width - 155, height: 20)
            self.dialogue.text = "Plus which of your friends have visited"
            self.dialogue.sizeToFit()
            
            self.nextButton.removeTarget(self, action: #selector(self.nextTapped0(_:)), for: .touchUpInside)
            self.nextButton.addTarget(self, action: #selector(self.nextTapped1(_:)), for: .touchUpInside)
        }
    }
    
    @objc func nextTapped1(_ sender: UIButton) {
        UIView.animate(withDuration: 0.3) {
            self.bottomMask.isHidden = true
            self.topMask.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            
            self.dialogue.frame = CGRect(x: self.dialogue.frame.minX, y: self.dialogue.frame.minY, width: UIScreen.main.bounds.width - 70, height: 20)
            self.dialogue.text = "Click on a post to open full-screen view"
            self.dialogue.sizeToFit()
            
            let highlightedPost = UIImageView(frame: CGRect(x: 120, y: self.postScroll.frame.minY, width: 100, height: 150))
            highlightedPost.image = UIImage(named: "SpotworldHighlighted")
            highlightedPost.contentMode = .scaleAspectFill
            highlightedPost.clipsToBounds = true
            self.drawer.addSubview(highlightedPost)
            
            self.nextButton.isHidden = true
            
            let openButton = UIButton(frame: self.topMask.frame)
            openButton.addTarget(self, action: #selector(self.openPost(_:)), for: .touchUpInside)
            openButton.backgroundColor = nil
            self.drawer.addSubview(openButton)
        }
    }
    
    @objc func openPost(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "TutorialPost") as? TutorialPostController {
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }
    
    func hideLandmarks(mapView: GMSMapView) {
        do {
            // Set the map style by passing the URL of the local file.
            if let styleURL = Bundle.main.url(forResource: "map-style-tutorial", withExtension: "json") {
                mapView.mapStyle = try GMSMapStyle(contentsOfFileURL: styleURL)
            } else {
                print("Unable to find map-style.json")
            }
        } catch {
            print("One or more of the map styles failed to load. \(error)")
        }
    }
}

extension GMSMarker {
    func setIconSize(scaledToSize newSize: CGSize) {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        icon?.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        icon = newImage
    }
}

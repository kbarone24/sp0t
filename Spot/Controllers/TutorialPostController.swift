//
//  TutorialPostController.swift
//  Spot
//
//  Created by kbarone on 4/10/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class TutorialPostController: UIViewController {
    var dialogue: UILabel!
    var nextButton: UIButton!
    var imageView: UIImageView!
    var imageSet: [UIImage]!
    var selectedPostIndex = 0
    var imageHeight: CGFloat = 600
    var imageY: CGFloat = 0
    var dialogueY: CGFloat = UIScreen.main.bounds.height - 110
    var largeScreen = false
    
    override func viewDidLoad() {
        if (UIScreen.main.nativeBounds.height > 2400 || UIScreen.main.nativeBounds.height == 1792) {
            dialogueY -= 10
            largeScreen = true
        }
        
        imageSet = [UIImage(named: "OnboardingFishing0")!, UIImage(named: "OnboardingFishing1")!, UIImage(named: "OnboardingFishing2")!, UIImage(named: "OnboardingFishing3")!, UIImage(named: "OnboardingFishing4")!, UIImage(named: "OnboardingFishing5")!, UIImage(named: "OnboardingFishing6")!, UIImage(named: "OnboardingFishing7")!, UIImage(named: "OnboardingFishing8")!, UIImage(named: "OnboardingFishing9")!]
        
        let dialogueBox = UIView(frame: CGRect(x: 0, y: dialogueY, width: UIScreen.main.bounds.width, height: dialogueY + 5))
        dialogueBox.backgroundColor = UIColor(patternImage: UIImage(named: "OnboardDialogueBackground")!)
        dialogueBox.layer.cornerRadius = 10
        
        view.addSubview(dialogueBox)
        
        
        super.viewDidLoad()
        var heightAdjust: CGFloat = 20
        if (UIScreen.main.nativeBounds.height > 2400 || UIScreen.main.nativeBounds.height == 1792) {
            heightAdjust = 0
        }
        
        if UIScreen.main.bounds.width > 375 {
            let aspect: CGFloat = 600 / 375
            let widthDifference = UIScreen.main.bounds.width - 375
            let heightAdjustment = widthDifference * aspect
            imageHeight = imageHeight + heightAdjustment
        }
        
        
        if imageHeight > UIScreen.main.bounds.height - 200 && imageHeight < UIScreen.main.bounds.height - 100 {
            imageY = 40
        } else {
            imageY = (UIScreen.main.bounds.height - imageHeight) / 2 - 30
        }
        
        //   print("y value", yValue)
        
        // move image 1 down
        
        
        let target = UIImageView(frame: CGRect(x: 7.5, y: 7.5, width: 11, height: 11))
        target.contentMode = .scaleAspectFit
        target.image = UIImage(named: "GuestbackBackButton")
        
        let name = UILabel(frame: CGRect(x: 23.5, y: 4.5, width: 100, height: 15))
        name.text = "sp0tw0rld"
        name.font = UIFont(name: "SFCamera-Semibold", size: 13)
        name.textColor = .white
        name.sizeToFit()
        
        let nameBackground = UIView(frame: CGRect(x: 7.5, y: 54 - heightAdjust, width: name.bounds.width + 37, height: 25))
        nameBackground.layer.cornerRadius = 6
        nameBackground.backgroundColor = UIColor(red:0.61, green:0.61, blue:0.61, alpha:1.0).withAlphaComponent(0.3)
        nameBackground.addSubview(target)
        nameBackground.addSubview(name)
        
        imageView = UIImageView(frame: CGRect(x: 0, y: imageY, width: UIScreen.main.bounds.width, height: imageHeight))
        imageView.layer.cornerRadius = 14
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.image = UIImage(named: "OnboardingPicnic0")
        view.addSubview(imageView)
        view.addSubview(nameBackground)

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
        
        dialogue = UILabel(frame: CGRect(x: bot.frame.maxX + 7, y: botHandle.frame.maxY + 2, width: UIScreen.main.bounds.width - 155, height: 20))
        dialogue.numberOfLines = 0
        dialogue.lineBreakMode = .byWordWrapping
        dialogue.text = "sp0t can help you save places"
        dialogue.font = UIFont(name: "SFCamera-Regular", size: 16)
        dialogue.textColor = UIColor(red:0.67, green:0.67, blue:0.67, alpha:1.00)
        dialogue.sizeToFit()
        dialogueBox.addSubview(dialogue)
        
        nextButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 90, y: 20, width: 73, height: 47))
        nextButton.setImage(UIImage(named: "NextArrowOnboarding"), for: .normal)
        nextButton.addTarget(self, action: #selector(nextTapped0(_:)), for: .touchUpInside)
        nextButton.imageView?.contentMode = .scaleAspectFit
        dialogueBox.addSubview(nextButton)
        
        animateGIF(directionUp: true, counter: 0, startingPostIndex: 0)
        
        view.bringSubviewToFront(dialogueBox)
    }
    
    @objc func nextTapped0(_ sender: UIButton) {
        imageSet = [UIImage(named: "OnboardingSkate0")!, UIImage(named: "OnboardingSkate1")!, UIImage(named: "OnboardingSkate2")!, UIImage(named: "OnboardingSkate3")!, UIImage(named: "OnboardingSkate4")!, UIImage(named: "OnboardingSkate5")!, UIImage(named: "OnboardingSkate6")!, UIImage(named: "OnboardingSkate7")!, UIImage(named: "OnboardingSkate8")!, UIImage(named: "OnboardingSkate9")!]
        
        self.nextButton.removeTarget(self, action: #selector(nextTapped0(_:)), for: .touchUpInside)
        self.nextButton.addTarget(self, action: #selector(nextTapped1(_:)), for: .touchUpInside)
        selectedPostIndex = 1
        animateGIF(directionUp: true, counter: 0, startingPostIndex: 1)
        
        dialogue.frame = CGRect(x: dialogue.frame.minX, y: dialogue.frame.minY, width: UIScreen.main.bounds.width - 150, height: 20)
        dialogue.text = "recommend stuff to friends"
        dialogue.sizeToFit()
        
        //move image 2 down
    }
    
    @objc func nextTapped1(_ sender: UIButton) {
        imageSet = [UIImage(named: "OnboardingPicnic0")!, UIImage(named: "OnboardingPicnic1")!, UIImage(named: "OnboardingPicnic2")!, UIImage(named: "OnboardingPicnic3")!, UIImage(named: "OnboardingPicnic4")!, UIImage(named: "OnboardingPicnic5")!, UIImage(named: "OnboardingPicnic6")!, UIImage(named: "OnboardingPicnic7")!, UIImage(named: "OnboardingPicnic8")!, UIImage(named: "OnboardingPicnic9")!]
        
        self.nextButton.removeTarget(self, action: #selector(nextTapped1(_:)), for: .touchUpInside)
        self.nextButton.addTarget(self, action: #selector(nextTapped2(_:)), for: .touchUpInside)
        selectedPostIndex = 2
        animateGIF(directionUp: true, counter: 0, startingPostIndex: 2)
        
        dialogue.frame = CGRect(x: dialogue.frame.minX, y: dialogue.frame.minY, width: UIScreen.main.bounds.width - 155, height: 20)
        dialogue.text = "and capture moments"
        dialogue.sizeToFit()
        
        if !largeScreen {
            imageView.frame = CGRect(x: 0, y: dialogueY - imageHeight, width: UIScreen.main.bounds.width, height: imageHeight)
        }
        
        //original image rect
    }
    
    @objc func nextTapped2(_ sender: UIButton) {
        imageSet = [UIImage(named: "SpotbotFamilyPost0")!, UIImage(named: "SpotbotFamilyPost1")!, UIImage(named: "SpotbotFamilyPost2")!, UIImage(named: "SpotbotFamilyPost3")!, UIImage(named: "SpotbotFamilyPost4")!, UIImage(named: "SpotbotFamilyPost5")!, UIImage(named: "SpotbotFamilyPost6")!, UIImage(named: "SpotbotFamilyPost7")!, UIImage(named: "SpotbotFamilyPost8")!, UIImage(named: "SpotbotFamilyPost9")!]
        
        selectedPostIndex = 3
        animateGIF(directionUp: true, counter: 0, startingPostIndex: 3)
        
        dialogue.frame = CGRect(x: dialogue.frame.minX, y: dialogue.frame.minY, width: UIScreen.main.bounds.width - 155, height: 20)
        dialogue.text = "thanks for being here early"
        dialogue.sizeToFit()
        
        self.nextButton.removeTarget(self, action: #selector(nextTapped2(_:)), for: .touchUpInside)
        self.nextButton.addTarget(self, action: #selector(goTapped(_:)), for: .touchUpInside)
        self.nextButton.setImage(UIImage(named: "OnboardingGo"), for: .normal)
        
        imageView.frame = CGRect(x: 0, y: imageY, width: UIScreen.main.bounds.width, height: imageHeight)
        //move image down
    }
    
    @objc func goTapped(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "TabBar", bundle: nil).instantiateViewController(withIdentifier: "TabBarMain") as? CustomTabBar {
            vc.modalPresentationStyle = .fullScreen
            self.getTopMostViewController()!.present(vc, animated: true, completion: nil)
        }
    }
    
    func animateGIF(directionUp: Bool, counter: Int, startingPostIndex: Int) {
        if selectedPostIndex != startingPostIndex { return }
        var newDirection = directionUp
        var newCount = counter
        if directionUp {
            if counter == 9 {
                newDirection = false
                newCount = 8
            } else {
                newCount += 1
            }
        } else {
            if counter == 0 {
                newDirection = true
                newCount = 1
            } else {
                newCount -= 1
            }
        }
        var newImage = UIImage()
        
        newImage = imageSet[newCount]
        
        UIView.animate(withDuration: 0.10, delay: 0.0, options: .transitionCrossDissolve, animations: {
            if self.selectedPostIndex != startingPostIndex { return }
            self.imageView.image = newImage
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            self.animateGIF(directionUp: newDirection, counter: newCount, startingPostIndex: startingPostIndex)
        }
    }
}

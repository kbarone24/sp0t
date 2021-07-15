//
//  TutorialCell.swift
//  Spot
//
//  Created by Kenny Barone on 4/1/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel
/*
class TutorialCell: UITableViewCell {
    
    var swipeNextLabel: UILabel!
    var postImage: UIImageView!
    var postImageNext: UIImageView!
    var postImagePrevious: UIImageView!
    var postFriendsView: PostFriendsView!
    var dotView: UIView!
    
    var originalOffset: CGFloat!

    var cellHeight: CGFloat = 0
    var swipe: UIPanGestureRecognizer!
    var selectedImageIndex = 0

    var screenSize = 0 /// 0 = iphone8-, 1 = iphoneX + with 375 width, 2 = iPhoneX+ with 414 width
    var imageY: CGFloat = 0 /// minY of postImage before moving drawer
    
    
    func setUp(selectedImageIndex: Int, cellHeight: CGFloat, tabBarHeight: CGFloat) {
        
        self.backgroundColor = UIColor(named: "SpotBlack")
        self.selectedImageIndex = selectedImageIndex
        
        originalOffset = 0
        screenSize = UIScreen.main.bounds.height < 800 ? 0 : UIScreen.main.bounds.width > 400 ? 2 : 1
                       
        resetCell()

        let tutorialImages = getTutorialImages(index: selectedImageIndex)
        swipe = UIPanGestureRecognizer(target: self, action: #selector(imageSwipe(_:)))

        if selectedImageIndex != 4 {
            postImage = UIImageView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: cellHeight - tabBarHeight))
            postImage.image = tutorialImages.current.first ?? UIImage()
            postImage.animationImages = tutorialImages.current
            postImage.animationDuration = 2
            postImage.backgroundColor = nil
            postImage.tag = 16
            postImage.clipsToBounds = true
            postImage.isUserInteractionEnabled = true
            postImage.contentMode = .scaleAspectFill
            addSubview(postImage)
            
            postImage.startAnimating()
            postImage.addGestureRecognizer(swipe)
        }
            
        if selectedImageIndex < 4 {
            postImageNext = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width, y: 0, width: UIScreen.main.bounds.width, height: cellHeight - tabBarHeight))
            postImageNext.clipsToBounds = true
            postImageNext.contentMode = .scaleAspectFill
            postImageNext.image = tutorialImages.next
            addSubview(postImageNext)
            
        } else {
            /// add as main view
            postFriendsView = PostFriendsView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: cellHeight - tabBarHeight))
            postFriendsView.setUp(cellHeight: cellHeight, tabBarHeight: tabBarHeight)
            postFriendsView.addGestureRecognizer(swipe)
            postFriendsView.findFriendsButton.addTarget(self, action: #selector(findFriendsTap(_:)), for: .touchUpInside)
            addSubview(postFriendsView)
        }
        
        if selectedImageIndex > 0 {
            postImagePrevious = UIImageView(frame: CGRect(x: -UIScreen.main.bounds.width, y: 0, width: UIScreen.main.bounds.width, height: cellHeight - tabBarHeight))
            postImagePrevious.clipsToBounds = true
            postImagePrevious.contentMode = .scaleAspectFill
            postImagePrevious.image = tutorialImages.previous
            addSubview(postImagePrevious)
            
        } else {
            swipeNextLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 50, y: cellHeight - tabBarHeight - 30, width: 100, height: 16))
            swipeNextLabel.text = "Swipe left!"
            swipeNextLabel.textColor = UIColor(red: 0.90, green: 0.90, blue: 0.90, alpha: 1.00)
            swipeNextLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
            swipeNextLabel.textAlignment = .center
            postImage.addSubview(swipeNextLabel)
        }
        
        if selectedImageIndex == 3 {
            /// add as next image
            postFriendsView = PostFriendsView(frame: CGRect(x: UIScreen.main.bounds.width, y: 0, width: UIScreen.main.bounds.width, height: cellHeight - tabBarHeight))
            postFriendsView.setUp(cellHeight: cellHeight, tabBarHeight: tabBarHeight)
            addSubview(postFriendsView)
            
        }

        if selectedImageIndex == 1 {
            swipeNextLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 50, y: cellHeight - tabBarHeight - 30, width: 100, height: 16))
            swipeNextLabel.text = "Swipe left!"
            swipeNextLabel.textColor = UIColor(red: 0.90, green: 0.90, blue: 0.90, alpha: 1.00)
            swipeNextLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
            swipeNextLabel.textAlignment = .center
            postImagePrevious.addSubview(swipeNextLabel)
        }
                    
        dotView = UIView(frame: CGRect(x: 0, y: cellHeight - tabBarHeight - 50, width: UIScreen.main.bounds.width, height: 10))
        dotView.backgroundColor = nil
        addSubview(dotView)
        
        var i = 1.0
        
        /// 1/2 of size of dot + the distance between that half and the next dot
        let count = 5
        var xOffset = CGFloat(6 + (Double(count - 1) * 7.5))
        while i <= Double(count) {
            
            let view = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width / 2 - xOffset, y: 0, width: 12, height: 12))
            view.layer.cornerRadius = 6
            
            if i == Double(selectedImageIndex + 1) {
                view.image = UIImage(named: "ElipsesFilled")
            } else {
                view.image = UIImage(named: "ElipsesUnfilled")
            }
            
            view.contentMode = .scaleAspectFit
            dotView.addSubview(view)
            
            i = i + 1.0
            xOffset = xOffset - 15
        }

    }
    
    
    func resetCell() {
        
        if postImage != nil { postImage.stopAnimating(); postImage.animationImages = []; postImage.image = UIImage()}
        if postImageNext != nil { postImageNext.image = UIImage() }
        if postImagePrevious != nil { postImagePrevious.image = UIImage() }
        if postFriendsView != nil { for sub in postFriendsView.subviews { sub.removeFromSuperview() } }
        if swipeNextLabel != nil { swipeNextLabel.text = "" }
        /// remove dots within dotview
        if dotView != nil {
            for dot in dotView.subviews { dot.removeFromSuperview() }
            dotView.removeFromSuperview()
        }
    }
    
    func getTutorialImages(index: Int) -> (current: [UIImage], next: UIImage, previous: UIImage) {
        
        var tutorialString = ""
        var nextString = ""
        var previousString = ""
        
        switch index {
        
        case 0:
            tutorialString = "WelcomeTutorial"
            nextString = "FindTutorial"
            
        case 1:
            previousString = "WelcomeTutorial"
            tutorialString = "FindTutorial"
            nextString = "MakeTutorial"
            
        case 2:
            previousString = "FindTutorial"
            tutorialString = "MakeTutorial"
            nextString = "CreateTutorial"
            
        case 3:
            tutorialString = "CreateTutorial"
            previousString = "MakeTutorial"
            
        case 4:
            previousString = "CreateTutorial"
            
        default: return ([UIImage()], UIImage(), UIImage())
        }
        
        var images: [UIImage] = []
        
        if tutorialString != "" {
            for i in 0...15 {
                let imageString = "\(tutorialString)\(i)"
                images.append(UIImage(named: imageString)!)
            }
        }
    
        let nImageString = "\(nextString)\(0)"
        let nextImage = nextString == "" ? UIImage() : UIImage(named: nImageString)!
        
        let pImageString = "\(previousString)\(0)"
        let previousImage = previousString == "" ? UIImage() : UIImage(named: pImageString)!

        
        return (images, nextImage, previousImage)
    }
    
    @objc func findFriendsTap(_ sender: UIButton) {
        guard let postVC = viewContainingController() as? PostViewController else { return }
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "FindFriends") as? FindFriendsController {
            Mixpanel.mainInstance().track(event: "TutorialFindFriends")
            vc.mapVC = postVC.mapVC
            postVC.present(vc, animated: true, completion: nil)
        }
    }
    
    func resetImageFrames() {

        if selectedImageIndex != 4 {
            let minY = postImage.frame.minY
            let frameN1 = CGRect(x: -UIScreen.main.bounds.width, y: minY, width: UIScreen.main.bounds.width, height: postImage.frame.height)
            let frame0 = CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: postImage.frame.height)
            let frame1 = CGRect(x: UIScreen.main.bounds.width, y: minY, width: UIScreen.main.bounds.width, height: postImage.frame.height)
            if postImagePrevious != nil { postImagePrevious.frame = frameN1 }
            if postImage != nil { postImage.frame = frame0 }
            
            if selectedImageIndex == 3 {
                postFriendsView.frame = frame1
            } else {
                if postImageNext != nil { postImageNext.frame = frame1 }
            }

        } else {

            let minY = postFriendsView.frame.minY
            let frameN1 = CGRect(x: -UIScreen.main.bounds.width, y: minY, width: UIScreen.main.bounds.width, height: postFriendsView.frame.height)
            let frame0 = CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: postFriendsView.frame.height)
            if postImagePrevious != nil { postImagePrevious.frame = frameN1 }
            postFriendsView.frame = frame0
        }
    }

    
    @objc func imageSwipe(_ gesture: UIPanGestureRecognizer) {
        /// cancel gesture if zooming

        guard let postVC = viewContainingController() as? PostViewController else { return }
        
        let direction = gesture.velocity(in: self)
        let translation = gesture.translation(in: self)
        
        let activeFrame = selectedImageIndex == 4 ? postFriendsView.frame : postImage.frame
        
        let minY = activeFrame.minY
        let frameN1 = CGRect(x: -UIScreen.main.bounds.width, y: minY, width: UIScreen.main.bounds.width, height: activeFrame.height)
        let frame0 = CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: activeFrame.height)
        let frame1 = CGRect(x: UIScreen.main.bounds.width, y: minY, width: UIScreen.main.bounds.width, height: activeFrame.height)
        
        switch gesture.state {
            
        case .changed:
            /// something off  about translation on postFriendsView
            //translate to follow finger tracking
            if postImage != nil { postImage.frame = CGRect(x: translation.x, y: postImage.frame.minY, width: postImage.frame.width, height: postImage.frame.height) }
            if postImageNext != nil { postImageNext.frame = CGRect(x: frame1.minX + translation.x, y: postImageNext.frame.minY, width: postImageNext.frame.width, height: postImageNext.frame.height) }
            if postImagePrevious != nil { postImagePrevious.frame = CGRect(x: frameN1.minX + translation.x, y: postImagePrevious.frame.minY, width: postImagePrevious.frame.width, height: postImagePrevious.frame.height) }
            if postFriendsView != nil {
                let activeframe = selectedImageIndex == 3 ? frame1 : frame0
                postFriendsView.frame = CGRect(x: activeframe.minX + translation.x, y: activeframe.minY, width: activeframe.width, height: activeframe.height)
            }
            
        case .ended, .cancelled:
            
            if direction.x < 0 {
                
                if activeFrame.maxX + direction.x < UIScreen.main.bounds.width/2 && selectedImageIndex < 4 {
                    
                    if selectedImageIndex < 3 {
                        //animate to next image
                        UIView.animate(withDuration: 0.2) {
                            self.postImageNext.frame = frame0
                            self.postImage.frame = frameN1
                        }
                        
                    } else if selectedImageIndex == 3 {
                        UIView.animate(withDuration: 0.2) {
                            self.postFriendsView.frame = frame0
                            self.postImage.frame = frameN1
                        }
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        guard let self = self else { return }
                        
                        self.selectedImageIndex += 1
                        postVC.tutorialImageIndex += 1
                        postVC.tableView.reloadData()
                    }
                    
                } else {
                    //return to original state
                    UIView.animate(withDuration: 0.2) { self.resetImageFrames() }
                }
                
            } else {
                
                if postImage.frame.minX + direction.x > UIScreen.main.bounds.width/2 && selectedImageIndex > 0 {
                    //animate to previous image
                    if selectedImageIndex != 4 {
                        UIView.animate(withDuration: 0.2) {
                            self.postImagePrevious.frame = frame0
                            self.postImage.frame = frame1
                        }
                    } else {
                        UIView.animate(withDuration: 0.2) {
                            self.postImagePrevious.frame = frame0
                            self.postFriendsView.frame = frame1
                        }
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        guard let self = self else { return }
                        self.selectedImageIndex -= 1
                        postVC.tutorialImageIndex -= 1
                        postVC.tableView.reloadData()
                    }
                    
                } else {
                    //return to original state
                    UIView.animate(withDuration: 0.2) { self.resetImageFrames() }
                }
            }
        default:
            return
        }
    }
}*/


class PostFriendsCell: UITableViewCell {
    
    var originalOffset: CGFloat!
    var postFriendsView: PostFriendsView!

    func setUp(cellHeight: CGFloat, tabBarHeight: CGFloat) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        tag = 16
        originalOffset = 0
        
        postFriendsView = PostFriendsView(frame: self.bounds)
        postFriendsView.backgroundColor = nil
        postFriendsView.setUp(cellHeight: cellHeight, tabBarHeight: tabBarHeight)
        postFriendsView.findFriendsButton.addTarget(self, action: #selector(findFriendsTap(_:)), for: .touchUpInside)
        addSubview(postFriendsView)
    }
    
    @objc func findFriendsTap(_ sender: UIButton) {
        guard let postVC = viewContainingController() as? PostViewController else { return }
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "FindFriends") as? FindFriendsController {
            vc.mapVC = postVC.mapVC
            postVC.present(vc, animated: true, completion: nil)
        }
    }
}

class PostFriendsView: UIView {
    
    var botImage: UIImageView!
    var label0: UILabel!
    var label1: UILabel!
    var findFriendsButton: UIButton!
    
    func setUp(cellHeight: CGFloat, tabBarHeight: CGFloat) {
        
        let minY = (cellHeight - tabBarHeight) * 0.38

        if botImage != nil { botImage.image = UIImage() }
        botImage = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 21.5, y: minY, width: 43, height: 50))
        botImage.image = UIImage(named: "OnboardB0t")
        addSubview(botImage)
        
        if label0 != nil { label0.text = "" }
        label0 = UILabel(frame: CGRect(x: 20, y: botImage.frame.maxY + 15, width: UIScreen.main.bounds.width - 40, height: 20))
        label0.text = "Your friends posts will show here"
        label0.textColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
        label0.font = UIFont(name: "SFCamera-Semibold", size: 15.5)
        label0.textAlignment = .center
        addSubview(label0)
        
        if label1 != nil { label1.text = "" }
        label1 = UILabel(frame: CGRect(x: 20, y: label0.frame.maxY + 3, width: UIScreen.main.bounds.width - 40, height: 16))
        label1.text = "Get started by adding some friends"
        label1.textColor = UIColor(red: 0.479, green: 0.479, blue: 0.479, alpha: 1)
        label1.font = UIFont(name: "SFCamera-Regular", size: 13)
        label1.textAlignment = .center
        addSubview(label1)
        
        if findFriendsButton != nil { findFriendsButton.setImage(UIImage(), for: .normal) }
        findFriendsButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 121, y: label1.frame.maxY + 23, width: 242, height: 43))
        findFriendsButton.setImage(UIImage(named: "FeedAddFriends"), for: .normal)
        addSubview(findFriendsButton)
    }
}

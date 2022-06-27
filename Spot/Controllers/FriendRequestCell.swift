//
//  FriendRequestCell.swift
//  Spot
//
//  Created by Shay Gyawali on 6/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import FirebaseUI

class FriendRequestCell: UICollectionViewCell {
    
    var friendRequestNotif: UserNotification!
    var senderPic: UIImageView! //imageView
    var cancelButton: UIButton!
    var acceptButton: UIButton! //acceptButton
    var aliveToggle: UIButton!
    
    lazy var activityIndicator = UIActivityIndicatorView()
    var globalRow = 0
    
    var directionUp = true
    var animationIndex = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
       // initialize what is needed
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    func setUp(friendRequest: UserNotification) {
        
        self.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
        self.layer.cornerRadius = 11.31
        //resetCell()
        
        //self.friendRequestNotif = friendRequest
        /// only set imageview when necessary to keep animation state
        
        print("🌿 FRIEND REQUEST: ", friendRequest.userInfo?.imageURL, "\n")
        senderPic = UIImageView(frame: CGRect(x: 65, y: 27.5, width: 71, height: 71))
        senderPic.layer.masksToBounds = false
        senderPic.layer.cornerRadius = senderPic.frame.height/2
        senderPic.clipsToBounds = true
        senderPic.contentMode = UIView.ContentMode.scaleAspectFill
        senderPic.isHidden = false
        let url = friendRequest.userInfo!.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            senderPic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        } else {print("🙈 NOOOOOOO")}
        
        self.addSubview(senderPic)
        
        senderPic.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        senderPic.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        
        let sampleText = UILabel()
        sampleText.text = friendRequest.senderID
        self.addSubview(sampleText)
        
        cancelButton = UIButton(frame: CGRect(x: 0, y: 0, width: 33, height: 33))
        cancelButton.setImage(UIImage(named: "FeedExit"), for: .normal)
        cancelButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        /*cancelButton.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)*/
        self.addSubview(cancelButton)
        cancelButton.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        
    }
        
    func resetCell() {
        if senderPic != nil { senderPic.image = UIImage() }
        if cancelButton != nil { cancelButton.setImage(UIImage(), for: .normal) }
    }
    
    func addActivityIndicator() {
        bringSubviewToFront(activityIndicator)
        activityIndicator.startAnimating()
    }
    
    func removeActivityIndicator() {
        activityIndicator.stopAnimating()
    }
    
    /*@objc func cancelTap(_ sender: UIButton) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        var index = -1 /// -1 for image from camera
        if let i = UploadImageModel.shared.imageObjects.firstIndex(where: {$0.image.id == imageObject.id}) { index = i }
        uploadVC.deselectImage(index: index, circleTap: true)
        imageObject = nil
        imageView = nil
    }*/
    
    
}

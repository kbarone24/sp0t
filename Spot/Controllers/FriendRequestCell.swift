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
    
    var profilePic: UIImageView! //imageView
    var userAvatar: UIImageView!
    var senderView: UIView!
    var cancelButton: UIButton!
    var acceptButton: UIButton! //acceptButton
    var aliveToggle: UIButton!
    var senderUsername: UILabel!
    var senderName: UILabel!
    var timestamp: UILabel!
    
    
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
        resetCell()
        
        /*senderView = UIView {
            $0.frame = CGRect(x: 65, y: 27.5, width: 71, height: 71)
            contentView.addSubview($0)
        } ///might use later for avatarShadow
        
        senderView.snp.makeConstraints{
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().offset(15)
            $0.height.width.equalTo(71)
        }*/
        
        profilePic = UIImageView{
            $0.frame = CGRect(x: 65, y: 27.5, width: 71, height: 71)
            $0.layer.masksToBounds = false
            $0.layer.cornerRadius = $0.frame.height/2
            $0.clipsToBounds = true
            $0.contentMode = UIView.ContentMode.scaleAspectFill
            $0.isHidden = false
            let url = friendRequest.userInfo!.imageURL
            if url != "" {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
                $0.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
            } else {print("🙈 NOOOOOOO")}
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        profilePic.snp.makeConstraints{
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().offset(15)
            $0.height.width.equalTo(71)
        }
        
        if(friendRequest.userInfo?.avatarURL != ""){
            
            
            userAvatar = UIImageView{
                $0.frame = CGRect(x: 65, y: 27.5, width: 71, height: 71)
                $0.layer.masksToBounds = false
                $0.contentMode = UIView.ContentMode.scaleAspectFill
                $0.isHidden = false
                var url = friendRequest.userInfo!.avatarURL!
                if url != "" {
                    let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
                    $0.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
                } else {print("🙈 NOOOOOOO")}
                $0.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview($0)
            }
            
            userAvatar.snp.makeConstraints{
                $0.leading.equalTo(profilePic.snp.leading).offset(-3)
                $0.bottom.equalTo(profilePic.snp.bottom).offset(3)
                $0.height.equalTo(39)
                $0.width.equalTo(30)
            }
        }
        
        
        senderName = UILabel{
            $0.text = friendRequest.userInfo?.name
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 16.5)
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        senderName.snp.makeConstraints{
            $0.centerX.equalToSuperview()
            $0.top.equalTo(profilePic.snp.bottom).offset(10)
        }

    
        senderUsername = UILabel{
            $0.text = friendRequest.senderUsername
            $0.textColor = UIColor(red: 0.675, green: 0.675, blue: 0.675, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 14.5)
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        senderUsername.snp.makeConstraints{
            $0.centerX.equalToSuperview()
            $0.top.equalTo(senderName.snp.bottom).offset(1)
            
        }

        acceptButton = UIButton{
            $0.frame = CGRect(x: 0, y: 0, width: 141, height: 37)
            $0.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            $0.layer.cornerRadius = 11.31
            $0.layer.borderWidth = 1
            $0.layer.borderColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1).cgColor
            let customButtonTitle = NSMutableAttributedString(string: "Accept", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
                //NSAttributedString.Key.backgroundColor: UIColor.red,
                NSAttributedString.Key.foregroundColor: UIColor.black
            ])
            $0.setAttributedTitle(customButtonTitle, for: .normal)
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        acceptButton.snp.makeConstraints{
            $0.centerX.equalToSuperview()
            $0.top.equalTo(senderUsername.snp.bottom).offset(10)
            $0.height.equalTo(37)
            $0.width.equalTo(141)
        }

        
        cancelButton = UIButton {
            $0.frame = CGRect(x: 0, y: 0, width: 33, height: 33)
            $0.setImage(UIImage(named: "FeedExit"), for: .normal)
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        cancelButton.snp.makeConstraints{
            $0.leading.equalToSuperview()
            $0.top.equalToSuperview()
        }
        
        timestamp = UILabel{
            $0.text = friendRequest.timeString
            $0.font = UIFont(name: "SFCompactText-Regular", size: 14.5)
            $0.textColor = UIColor(red: 0.696, green: 0.696, blue: 0.696, alpha: 1)
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        timestamp.snp.makeConstraints{
            $0.trailing.equalToSuperview().offset(-5)
            $0.top.equalToSuperview().offset(5)
        }
    }
        
    func resetCell() {
        if profilePic != nil { profilePic.image = UIImage() }
        if userAvatar != nil { userAvatar.image = UIImage() }
        if cancelButton != nil { cancelButton.setImage(UIImage(), for: .normal) }
        if acceptButton != nil {acceptButton = UIButton()}
        if senderUsername != nil {senderUsername = UILabel()}
        if senderName != nil {senderName = UILabel()}
        if timestamp != nil {timestamp = UILabel()}
    }
    
    override func prepareForReuse() {
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
        if userAvatar != nil { userAvatar.sd_cancelCurrentImageLoad() }
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        //handle cancel tap
        print("holder")
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

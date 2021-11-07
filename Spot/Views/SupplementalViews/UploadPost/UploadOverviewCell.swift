//
//  UploadOverviewCell.swift
//  Spot
//
//  Created by Kenny Barone on 9/16/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Photos
import Mixpanel

/// upload overview cell and subclasses for UploadPostController
class UploadOverviewCell: UITableViewCell, UITextViewDelegate {
    
    var profilePic: UIImageView!
    var spotImage: UIImageView!
    var spotLabel: UILabel!
    
    var tagImage: UIImageView!
    var addedUsersView: AddedUsersView!
    
    var captionView: UITextView!
    var selectedCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewLayout.init())
    
    var scrollObjects: [ImageObject] = []
    
    var friendsButton: UIButton!
    var tagButton: UIButton!
    
    func setUp(post: MapPost, scrollObjects: [ImageObject]) {
        
        backgroundColor = .black
        contentView.backgroundColor = .black
        
        resetCell()
        
        selectionStyle = .none
        self.scrollObjects = scrollObjects
        
        let bigScreen = UserDataModel.shared.screenSize == 2
        var minY: CGFloat = bigScreen ? 15 : 9
        
        if !scrollObjects.isEmpty {
            let cameraLayout = UICollectionViewFlowLayout()
            cameraLayout.scrollDirection = .horizontal
            cameraLayout.itemSize = CGSize(width: 150, height: 199)
            cameraLayout.minimumInteritemSpacing = 9
            cameraLayout.sectionInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
            
            selectedCollection.frame = CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: 200)
            selectedCollection.backgroundColor = .black
            selectedCollection.delegate = self
            selectedCollection.dataSource = self
            selectedCollection.isScrollEnabled = true
            selectedCollection.setCollectionViewLayout(cameraLayout, animated: false)
            selectedCollection.showsHorizontalScrollIndicator = false
            selectedCollection.register(SelectedImageCell.self, forCellWithReuseIdentifier: "SelectedImage")
            addSubview(selectedCollection)
            
            selectedCollection.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
            minY += 215
        }
        
        profilePic = UIImageView(frame: CGRect(x: 17, y: minY, width: 48, height: 51))
        profilePic.layer.cornerRadius = 10
        profilePic.clipsToBounds = true
        profilePic.contentMode = .scaleAspectFill
        profilePic.image = post.userInfo.id == "" ? UIImage(color: UIColor(named: "BlankImage")!) : post.userInfo.profilePic
        contentView.addSubview(profilePic)
        
        loadDetailView(post: post)
    }
    
    func loadDetailView(post: MapPost) {
        
        resetDetailView()
        var minY: CGFloat = profilePic.frame.minY
        let bigScreen = UserDataModel.shared.screenSize == 2
        
        if post.tag ?? "" != "" {
                        
            let tag = Tag(name: post.tag!)
            tagImage = UIImageView(frame: CGRect(x: profilePic.frame.minX - 6, y: minY + 33, width: 24, height: 24))
            tagImage.contentMode = .scaleAspectFit
            tagImage.image = tag.image
            tagImage.layer.cornerRadius = 6
            tagImage.backgroundColor = .black
            addSubview(tagImage)
        }
        
        if !(post.addedUsers?.isEmpty ?? true) {
            /// add addedUsersView

            let usersWidth: CGFloat = post.addedUsers!.count > 3 ? 74 : CGFloat(post.addedUsers!.count) * 17
            
            addedUsersView = AddedUsersView(frame: CGRect(x: profilePic.frame.maxX + 14, y: minY, width: usersWidth, height: 25))
            addedUsersView.setUp(users: post.addedUserProfiles)
            addSubview(addedUsersView)

            minY += 28
        }
        
        minY += 5
        
        let alpha = post.spotName == "" ? 0.55 : 1.0
        spotImage = UIImageView(frame: CGRect(x: profilePic.frame.maxX + 13, y: minY, width: 10, height: 13))
        spotImage.image = UIImage(named: "LocationIcon")
        spotImage.alpha = alpha
        addSubview(spotImage)
                
        if post.spotName != "" {
            
            spotImage.alpha = 1.0
            
            spotLabel = UILabel(frame: CGRect(x: spotImage.frame.maxX + 6, y: minY, width: UIScreen.main.bounds.width - spotImage.frame.maxX - 17, height: 15))
            spotLabel.text = post.spotName
            spotLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
            spotLabel.font = UIFont(name: "SFCamera-Semibold", size: 13.5)
            addSubview(spotLabel)
        } else { spotImage.alpha = 0.55 }
        
        
        ///hardcode cell height in case its laid out before view fully appears
        let cellHeight: CGFloat = scrollObjects.isEmpty ? 220 : 420
        captionView = UITextView(frame: CGRect(x: spotImage.frame.minX - 4, y: spotImage.frame.maxY + 2, width: UIScreen.main.bounds.width - 100, height: cellHeight - 90))
        captionView.backgroundColor = nil
        let captionEmpty = post.caption == ""
        captionView.text = captionEmpty ? "What's up..." : post.caption
        captionView.textColor = captionEmpty ? UIColor(red: 0.267, green: 0.267, blue: 0.267, alpha: 1) : UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha: 1.00)
        captionView.tag = captionEmpty ? 1 : 2 /// 1 is for placeholder text, 2 for acitve text
        captionView.font = UIFont(name: "SFCamera-Regular", size: bigScreen ? 17.5 : 16.5)
        captionView.keyboardDistanceFromTextField = 100
        captionView.isUserInteractionEnabled = true
        captionView.delegate = self
        captionView.tintColor = .white
        contentView.addSubview(captionView)
        
        let friendsColor = post.addedUsers?.isEmpty ?? true ? UIColor(red: 0.525, green: 0.525, blue: 0.525, alpha: 1) : UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        let friendsBorder = post.addedUsers?.isEmpty ?? true ? UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1).cgColor : UIColor(red: 0.525, green: 0.525, blue: 0.525, alpha: 1).cgColor

        friendsButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 162, y: cellHeight - 40, width: 75, height: 24))
        friendsButton.setTitle("Friends", for: .normal)
        friendsButton.setTitleColor(friendsColor, for: .normal)
        friendsButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        friendsButton.contentHorizontalAlignment = .center
        friendsButton.layer.borderWidth = 1
        friendsButton.layer.borderColor = friendsBorder
        friendsButton.layer.cornerRadius = 4
        friendsButton.layer.cornerCurve = .continuous
        friendsButton.addTarget(self, action: #selector(friendsTap(_:)), for: .touchUpInside)
        addSubview(friendsButton)
        
        let tagColor = post.tag == "" ? UIColor(red: 0.525, green: 0.525, blue: 0.525, alpha: 1) : UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        let tagBorder = post.tag == "" ? UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1).cgColor : UIColor(red: 0.525, green: 0.525, blue: 0.525, alpha: 1).cgColor
        tagButton = UIButton(frame: CGRect(x: friendsButton.frame.maxX + 9, y: friendsButton.frame.minY, width: 63, height: 24))
        tagButton.setTitle("Tags", for: .normal)
        tagButton.setTitleColor(tagColor, for: .normal)
        tagButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        tagButton.contentHorizontalAlignment = .center
        tagButton.layer.borderWidth = 1
        tagButton.layer.borderColor = tagBorder
        tagButton.layer.cornerRadius = 4
        tagButton.layer.cornerCurve = .continuous
        tagButton.addTarget(self, action: #selector(tagTap(_:)), for: .touchUpInside)
        addSubview(tagButton)
    }
    
    @objc func friendsTap(_ sender: UIButton) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        uploadVC.pushInviteFriends()
    }
    
    @objc func tagTap(_ sender: UIButton) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        uploadVC.presentTagPicker()
    }
    
    /*
    func addDetail(post: MapPost) {
        
        
        var minX: CGFloat = 5

        if post.tag ?? "" != "" {
            
            let detail1 = UILabel(frame: CGRect(x: minX, y: 8, width: 11, height: 13))
            detail1.text = "is"
            detail1.textColor = UIColor(red: 0.363, green: 0.363, blue: 0.363, alpha: 1)
            detail1.font = UIFont(name: "SFCamera-Regular", size: 13.5)
            usernameDetail.addSubview(detail1)
            
            minX += 15
            
            let tag = Tag(name: post.tag!)
            tagImage = UIImageView(frame: CGRect(x: minX, y: 2, width: 23, height: 23))
            tagImage.contentMode = .scaleAspectFit
            tagImage.image = tag.image
            usernameDetail.addSubview(tagImage)
            minX += 27
        }
        
        if !(post.addedUsers?.isEmpty ?? true) {
            
            let detail2 = UILabel(frame: CGRect(x: minX, y: 8, width: 28, height: 13))
            detail2.text = "with"
            detail2.textColor = UIColor(red: 0.363, green: 0.363, blue: 0.363, alpha: 1)
            detail2.font = UIFont(name: "SFCamera-Regular", size: 13.5)
            usernameDetail.addSubview(detail2)
            
            minX += 36
            
            let usersWidth: CGFloat = post.addedUsers!.count > 3 ? 74 : CGFloat(post.addedUsers!.count) * 17
            
            addedUsersView = AddedUsersView(frame: CGRect(x: minX, y: 2, width: usersWidth, height: 25))
            addedUsersView.setUp(users: post.addedUserProfiles)
            usernameDetail.addSubview(addedUsersView)
        }
    } */
    
    func resetCell() {
        if profilePic != nil { profilePic.image = UIImage() }
        selectedCollection.removeFromSuperview()
    }
    
    func resetDetailView() {
        if tagImage != nil { tagImage.image = UIImage() }
        if addedUsersView != nil { for sub in addedUsersView.subviews {sub.removeFromSuperview()} }
        if captionView != nil { captionView.text = "" }
        if spotImage != nil { spotImage.image = UIImage() }
        if spotLabel != nil { spotLabel.text = "" }
        if friendsButton != nil { friendsButton.setTitle("", for: .normal) }
        if tagButton != nil { tagButton.setTitle("", for: .normal) }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        
        if let uploadVC = viewContainingController() as? UploadPostController {
            uploadVC.tableView.addGestureRecognizer(uploadVC.tapToClose)
        }
        
        if textView.tag == 1 {
            textView.text = nil
            textView.tag = 2
            textView.textColor = UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha: 1.00)
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        
        if let uploadVC = viewContainingController() as? UploadPostController {
            uploadVC.mapVC.removeTable()
            uploadVC.tableView.removeGestureRecognizer(uploadVC.tapToClose)
        }
        
        if textView.tag == 2 && textView.text.isEmpty {
            textView.text = "What's up..."
            textView.tag = 1
            textView.textColor = UIColor(red: 0.267, green: 0.267, blue: 0.267, alpha: 1)
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        
        /// add tag table if this is the same word after @ was type     d
        let cursor = textView.getCursorPosition()
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        uploadVC.addRemoveTagTable(text: textView.text ?? "", cursorPosition: cursor, tableParent: .upload)
        
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        
        let currentText = textView.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: text)
        
        ///update parent
        if let uploadVC = self.viewContainingController() as? UploadPostController {
            if updatedText.count <= 500 { uploadVC.postObject.caption = updatedText }
        }
        
        return updatedText.count <= 500
    }
}

extension UploadOverviewCell: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return scrollObjects.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SelectedImage", for: indexPath) as? SelectedImageCell else { return UICollectionViewCell() }
        cell.setUp(imageObject: scrollObjects[indexPath.row])
        cell.globalRow = indexPath.row
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("select", indexPath.row) /// enlarge image in fullscreen preview
    }
}

class SelectedImageCell: UICollectionViewCell {
    
    var imageObject: ImageObject!
    
    var imageView: UIImageView!
    var cancelButton: UIButton!
    var aliveToggle: UIButton!
    
    var activityIndicator: CustomActivityIndicator!
    lazy var imageFetcher = ImageFetcher()
    lazy var globalRow = 0
    
    deinit {
        imageFetcher.cancelFetchForAsset(asset: imageObject.asset)
    }
    
    func setUp(imageObject: ImageObject) {
        
        backgroundColor = nil
        resetCell()
        
        self.imageObject = imageObject
        
        imageView = UIImageView(frame: self.bounds)
        imageView.image = imageObject.stillImage
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 9
        imageView.layer.cornerCurve = .continuous
        imageView.isUserInteractionEnabled = true
        addSubview(imageView)
        
        cancelButton = UIButton(frame: CGRect(x: bounds.width - 39, y: 4, width: 35, height: 35))
        cancelButton.setImage(UIImage(named: "CheckInX"), for: .normal)
        cancelButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        cancelButton.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
        addSubview(cancelButton)
        
        if imageObject.asset.mediaSubtypes.contains(.photoLive) {
            aliveToggle = UIButton(frame: CGRect(x: 0, y: self.bounds.height - 53, width: 94, height: 53))
            /// 74 x 33
            let image = imageObject.gifMode ? UIImage(named: "AliveOn") : UIImage(named: "AliveOff")
            aliveToggle.setImage(image, for: .normal)
            aliveToggle.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            aliveToggle.addTarget(self, action: #selector(toggleAlive(_:)), for: .touchUpInside)
            addSubview(aliveToggle)
            
            activityIndicator = CustomActivityIndicator(frame: CGRect(x: 14, y: 79, width: 30, height: 30))
            activityIndicator.isHidden = true
            addSubview(activityIndicator)
        }
    }
    
    func resetCell() {
        if imageView != nil { imageView.image = UIImage() }
        if cancelButton != nil { cancelButton.setImage(UIImage(), for: .normal) }
        if aliveToggle != nil { aliveToggle.setImage(UIImage(), for: .normal) }
        if activityIndicator != nil { activityIndicator.removeFromSuperview() }
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        guard let index = UploadImageModel.shared.imageObjects.firstIndex(where: {$0.image.id == imageObject.id}) else { return }
        uploadVC.deselectImage(index: index, circleTap: true)
    }
    
    @objc func toggleAlive(_ sender: UIButton) {
                        
        imageObject.gifMode = !imageObject.gifMode
        
        Mixpanel.mainInstance().track(event: "UploadToggleAlive", properties: ["on": imageObject.gifMode])

        let image = imageObject.gifMode ? UIImage(named: "AliveOn") : UIImage(named: "AliveOff")
        aliveToggle.setImage(image, for: .normal)
        
        if imageObject.gifMode {
            
            aliveToggle.isHidden = true
            activityIndicator.startAnimating()
            
            /// download alive if available and not yet downloaded
            imageFetcher.fetchLivePhoto(currentAsset: imageObject.asset, animationImages: imageObject.animationImages) { [weak self] animationImages, failed in

                guard let self = self else { return }
                
                self.activityIndicator.stopAnimating()
                self.aliveToggle.isHidden = false
                
                self.imageObject.animationImages = animationImages
                
                /// animate with gif images
                self.imageView.animationImages = self.imageObject.animationImages
                self.imageView.animateGIF(directionUp: true, counter: 0, frames: self.imageObject.animationImages.count, alive: false)
                self.updateParent()
                ///fetch image is async so need to make sure another image wasn't appended while this one was being fetched
            }

        } else {
            /// remove to stop animation and set to still image
         ///   imageView.isHidden = true
            imageView.image = imageObject.stillImage
            imageView.animationImages?.removeAll()
            updateParent()
        }
    }
    
    func updateParent() {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        uploadVC.scrollObjects[globalRow].gifMode = imageObject.gifMode
    }
}

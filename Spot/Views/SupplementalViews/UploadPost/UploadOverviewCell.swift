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
    
    var cellHeight, bodyHeight, collectionHeight, itemHeight, itemWidth: CGFloat!
    
    var spotIcon: UIImageView!
    var spotLabel: UILabel!
    var spotButton: UIButton!
    
    var addedUsersButton: UIButton!
    var addedUsersIcon: UIImageView!
    var addedUsersLabel: UILabel!
    
    var captionView: UITextView!
    var selectedCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewLayout.init())
    
    var imagePreview: ImagePreviewView!
    
    var friendsButton: UIButton!
    var tagButton: UIButton!
    var privacyButton: UIButton!
    
    lazy var imageFetcher = ImageFetcher()

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PreviewRemove"), object: nil)
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        selectionStyle = .none
        backgroundColor = .clear
        
        bodyHeight = 96
        bodyHeight += UserDataModel.shared.screenSize == 0 ? 112 : UserDataModel.shared.screenSize == 1 ? 117 : 140
        itemWidth = UserDataModel.shared.screenSize == 0 ? 140 : UserDataModel.shared.screenSize == 1 ? 160 : 195
        itemHeight = itemWidth * 1.3266
        collectionHeight = itemHeight
        cellHeight = bodyHeight + collectionHeight

        let backgroundLayer = CAGradientLayer()
        backgroundLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: cellHeight)
       // backgroundLayer.shouldRasterize = true
        backgroundLayer.colors = [
            UIColor.black.withAlphaComponent(0.85).cgColor,
            UIColor.black.withAlphaComponent(0.95).cgColor,
            UIColor.black.cgColor,
            UIColor.black.cgColor
        ]
        backgroundLayer.locations = [0, 0.1, 0.3, 1.0]
        backgroundLayer.startPoint = CGPoint(x: 0.5, y: 0)
        backgroundLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(backgroundLayer, at: 0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp(post: MapPost) {
        
        ///hardcode cell height in case its laid out before view fully appears -> hard code body height so mask stays with cell change        
        resetCell()
                
        let cameraLayout = UICollectionViewFlowLayout()
        cameraLayout.scrollDirection = .horizontal
        cameraLayout.itemSize = CGSize(width: itemWidth, height: itemHeight)
        cameraLayout.minimumInteritemSpacing = 8
        cameraLayout.sectionInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        
        selectedCollection.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: itemHeight + 1)
        selectedCollection.backgroundColor = nil
        selectedCollection.delegate = self
        selectedCollection.dataSource = self
        selectedCollection.isScrollEnabled = true
        selectedCollection.setCollectionViewLayout(cameraLayout, animated: false)
        selectedCollection.showsHorizontalScrollIndicator = false
        selectedCollection.register(SelectedImageCell.self, forCellWithReuseIdentifier: "SelectedImage")
        contentView.addSubview(selectedCollection)
        
        selectedCollection.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
        loadDetailView(post: post)
        
        /// call function when imagePreview is removed from view hierarchy
        NotificationCenter.default.addObserver(self, selector: #selector(removePreview(_:)), name: NSNotification.Name("PreviewRemove"), object: nil)
    }
    
    func loadDetailView(post: MapPost) {
        
        // load separately to avoid re-laying out collection on reload
        
        resetDetailView()
        
        let minY: CGFloat = selectedCollection.frame.maxY + 13
        let alpha = post.spotName == "" ? 0.55 : 1.0
        
        spotIcon = UIImageView(frame: CGRect(x: 15, y: minY, width: 17, height: 17))
        spotIcon.image = post.tag == "" ? UIImage(named: "FeedSpotIcon") : Tag(name: post.tag!).image
        spotIcon.alpha = alpha
        contentView.addSubview(spotIcon)
        
        if post.tag != "" {
            let spotImageButton = UIButton(frame: CGRect(x: spotIcon.frame.minX - 3, y: spotIcon.frame.minY - 3, width: spotIcon.frame.width + 6, height: spotIcon.frame.height + 6))
            spotImageButton.addTarget(self, action: #selector(tagTap(_:)), for: .touchUpInside)
            contentView.addSubview(spotImageButton)
        }
                
        if post.spotName != "" {
            
            spotIcon.alpha = 1.0
            
            let labelWidth: CGFloat = UIScreen.main.bounds.width - spotIcon.frame.maxX - 17
            spotLabel = UILabel(frame: CGRect(x: spotIcon.frame.maxX + 8, y: minY + 1.5, width: labelWidth, height: 15))
            spotLabel.text = post.spotName
            spotLabel.lineBreakMode = .byTruncatingTail
            spotLabel.numberOfLines = 1
            spotLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
            spotLabel.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
            spotLabel.sizeToFit()
            if spotLabel.frame.width > labelWidth { spotLabel.frame = CGRect(x: spotIcon.frame.maxX + 8, y: minY + 2, width: labelWidth, height: 15) } /// prevent overflow on sizetofit
            contentView.addSubview(spotLabel)
            
            /// extend past bounds to expand touch area
            spotButton = UIButton(frame: CGRect(x: spotLabel.frame.minX - 3, y: minY - 5, width: spotLabel.frame.width + 15, height: spotLabel.frame.height + 14))
            spotButton.addTarget(self, action: #selector(spotNameTap(_:)), for: .touchUpInside)
            contentView.addSubview(spotButton)
            
        } else { spotIcon.alpha = 0.55 }

        let heightAdjust: CGFloat = post.spotName == "" ? 0 : 20
        captionView = UITextView(frame: CGRect(x: spotIcon.frame.minX - 4, y: spotIcon.frame.maxY + 8, width: UIScreen.main.bounds.width - 100, height: cellHeight - spotIcon.frame.maxY - 120 + heightAdjust))
        captionView.backgroundColor = nil
        captionView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        let captionEmpty = post.caption == ""
        captionView.text = captionEmpty ? "What's up..." : post.caption
        captionView.textColor = captionEmpty ? UIColor(red: 0.267, green: 0.267, blue: 0.267, alpha: 1) : UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha: 1.00)
        captionView.tag = captionEmpty ? 1 : 2 /// 1 is for placeholder text, 2 for acitve text
        captionView.font = UIFont(name: "SFCompactText-Regular", size: 15)
        captionView.keyboardDistanceFromTextField = 100
        captionView.isUserInteractionEnabled = true
        captionView.delegate = self
        captionView.tintColor = .white
        captionView.keyboardDistanceFromTextField = 0 /// dont want entire view to slide up
        contentView.addSubview(captionView)
        
        if spotButton != nil { contentView.bringSubviewToFront(spotButton) }
        
        if !(post.addedUsers?.isEmpty ?? true) {
            addedUsersIcon = UIImageView(frame: CGRect(x: 17, y: captionView.frame.maxY + 7, width: 14.6, height: 14))
            addedUsersIcon.image = UIImage(named: "TaggedFriendIcon")
            contentView.addSubview(addedUsersIcon)
            
            let labelWidth: CGFloat = UIScreen.main.bounds.width - addedUsersIcon.frame.maxX - 20
            addedUsersLabel = UILabel(frame: CGRect(x: addedUsersIcon.frame.maxX + 5, y: captionView.frame.maxY + 5, width: labelWidth, height: 16))
            addedUsersLabel.textColor = UIColor(red: 0.412, green: 0.412, blue: 0.412, alpha: 1)
            addedUsersLabel.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
            addedUsersLabel.lineBreakMode = .byTruncatingTail
            addedUsersLabel.numberOfLines = 1
            addedUsersLabel.backgroundColor = nil
            
            var textString = ""
            for user in post.addedUserProfiles { textString.append(user.username); if user.id != post.addedUserProfiles.last?.id { textString.append(", ")} }
            addedUsersLabel.text = textString
            addedUsersLabel.sizeToFit()
            if addedUsersLabel.frame.width > labelWidth { addedUsersLabel.frame = CGRect(x: addedUsersIcon.frame.maxX + 5, y: captionView.frame.maxY + 5, width: labelWidth, height: 16) } /// prevent overflow on sizetofit
            contentView.addSubview(addedUsersLabel)
            
            addedUsersButton = UIButton(frame: CGRect(x: addedUsersIcon.frame.minX - 5, y: addedUsersLabel.frame.minY - 5, width: addedUsersLabel.frame.maxX - addedUsersIcon.frame.minX + 10, height: 25))
            addedUsersButton.addTarget(self, action: #selector(friendsTap(_:)), for: .touchUpInside)
            contentView.addSubview(addedUsersButton)
        }
        
        friendsButton = UIButton(frame: CGRect(x: 8, y: cellHeight - 56.5, width: 94, height: 43))
        friendsButton.setImage(UIImage(named: "UploadFriendsButton"), for: .normal)
        friendsButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        friendsButton.addTarget(self, action: #selector(friendsTap(_:)), for: .touchUpInside)
        contentView.addSubview(friendsButton)
        
        tagButton = UIButton(frame: CGRect(x: friendsButton.frame.maxX + 2, y: friendsButton.frame.minY, width: 78, height: 43))
        tagButton.setImage(UIImage(named: "UploadTagsButton"), for: .normal)
        tagButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        tagButton.addTarget(self, action: #selector(tagTap(_:)), for: .touchUpInside)
        contentView.addSubview(tagButton)
        
        privacyButton = UIButton(frame: CGRect(x: tagButton.frame.maxX + 2, y: friendsButton.frame.minY, width: 95, height: 43))
        privacyButton.setImage(UIImage(named: "UploadPrivacyButton"), for: .normal)
        privacyButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        privacyButton.addTarget(self, action: #selector(privacyTap(_:)), for: .touchUpInside)
        contentView.addSubview(privacyButton)
    }

    @objc func friendsTap(_ sender: UIButton) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        uploadVC.pushInviteFriends()
    }
    
    @objc func tagTap(_ sender: UIButton) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        uploadVC.presentTagPicker()
    }
    
    @objc func privacyTap(_ sender: UIButton) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        uploadVC.presentPrivacyPicker()
    }
    
    @objc func spotNameTap(_ sender: UIButton) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        uploadVC.spotObject == nil ? uploadVC.presentAddNew() : uploadVC.switchToChooseSpot()
    }
    
    func resetCell() {
        selectedCollection.removeFromSuperview()
    }
     
    @objc func removePreview(_ sender: NSNotification) {
        if imagePreview != nil {
            guard let cell = selectedCollection.cellForItem(at: IndexPath(item: imagePreview.selectedIndex, section: 0)) as? SelectedImageCell else { return }
            cell.animationIndex = imagePreview.maskImage.animationIndex
            cell.directionUp = imagePreview.maskImage.directionUp
            imagePreview.removeFromSuperview()
            imagePreview = nil
        }
    }
    
    func resetDetailView() {
        if captionView != nil { captionView.text = "" }
        if spotIcon != nil { spotIcon.image = UIImage() }
        if spotLabel != nil { spotLabel.text = "" }
        if addedUsersIcon != nil { addedUsersIcon.image = UIImage() }
        if addedUsersLabel != nil { addedUsersLabel.text = "" }
        if friendsButton != nil { friendsButton.setImage(UIImage(), for: .normal) }
        if tagButton != nil { tagButton.setImage(UIImage(), for: .normal) }
        if privacyButton != nil { privacyButton.setImage(UIImage(), for: .normal) }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        
        if let uploadVC = viewContainingController() as? UploadPostController {
            uploadVC.uploadTable.addGestureRecognizer(uploadVC.tapToClose)
        }
        
        /// tag = 2 for spot during editing / when text isn't empty
        if textView.tag == 1 {
            textView.text = nil
            textView.tag = 2
            textView.textColor = UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha: 1.00)
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        
        if let uploadVC = viewContainingController() as? UploadPostController {
            uploadVC.mapVC.removeTable()
            uploadVC.uploadTable.removeGestureRecognizer(uploadVC.tapToClose)
        }
        
        /// tag = 1 for placeholder
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
        return UploadImageModel.shared.scrollObjects.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SelectedImage", for: indexPath) as? SelectedImageCell else { return UICollectionViewCell() }
        cell.setUp(imageObject: UploadImageModel.shared.scrollObjects[indexPath.row])
        if cell.imageObject.asset.mediaSubtypes.contains(.photoLive) { cell.aliveToggle.addTarget(self, action: #selector(aliveTap(_:)), for: .touchUpInside); cell.aliveToggle.tag = indexPath.row }
        cell.globalRow = indexPath.row
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        // cancel fetch if tapping an image while fetching happening
        if imageFetcher.fetchingIndex == indexPath.row {
            toggleAliveAt(row: indexPath.row)
            return
        }
        
        // show image preview on image tap
        guard let cell = collectionView.cellForItem(at: indexPath) as? SelectedImageCell else { return }

        scrollToImageAt(position: indexPath.row, animated: true)
        
        imagePreview = ImagePreviewView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        imagePreview.alpha = 0.0
        imagePreview.imagesCollection = collectionView
        
        
        let frame = cell.superview?.convert(cell.frame, to: nil) ?? CGRect()
        
        UploadImageModel.shared.scrollObjects[indexPath.row].animationIndex = cell.animationIndex
        UploadImageModel.shared.scrollObjects[indexPath.row].directionUp = cell.directionUp
        
        DispatchQueue.main.async {
            let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
            window?.addSubview(self.imagePreview)
            self.imagePreview.imageExpand(originalFrame: frame, selectedIndex: indexPath.row, galleryIndex: 0, imageObjects: UploadImageModel.shared.scrollObjects)
        }

        Mixpanel.mainInstance().track(event: "UploadImagePreviewTap", properties: nil)
    }
    
    func scrollToImageAt(position: Int, animated: Bool) {
        DispatchQueue.main.async {
            self.selectedCollection.scrollToItem(at: IndexPath(item: position, section: 0), at: .left, animated: animated)
        }
    }
    
    @objc func aliveTap(_ sender: UIButton) {
        let row = sender.tag
        toggleAliveAt(row: row)
    }
    
    func toggleAliveAt(row: Int) {
        
        let imageObject = UploadImageModel.shared.scrollObjects[row]
        
        let indexPath = IndexPath(item: row, section: 0)
        guard let cell = selectedCollection.cellForItem(at: indexPath) as? SelectedImageCell else { return }
        Mixpanel.mainInstance().track(event: "UploadImageScrollToggleGif", properties: ["gif": imageObject.gifMode])
        
        if !imageObject.gifMode {
            
            cell.addActivityIndicator()
            
            let sameRow = imageFetcher.fetchingIndex == row
            self.cancelFetchForItemAt(index: imageFetcher.fetchingIndex) /// fetching index reset here
            if sameRow { return } /// cancel for double tap toggle
            
            imageFetcher.fetchingIndex = row
            
            imageFetcher.fetchLivePhoto(currentAsset: imageObject.asset, animationImages: imageObject.animationImages) { [weak self] animationImages, failed in
                
                if failed || animationImages.isEmpty { return }
                guard let self = self else { return }
                
                guard let cell = self.selectedCollection.cellForItem(at: IndexPath(item: row, section: 0)) as? SelectedImageCell else { return }
                cell.removeActivityIndicator()
                
                UploadImageModel.shared.scrollObjects[row].gifMode = true
                UploadImageModel.shared.scrollObjects[row].animationImages = animationImages
                DispatchQueue.main.async { self.selectedCollection.reloadItems(at: [indexPath]) }
                return
            }
            
        } else {
            UploadImageModel.shared.scrollObjects[row].gifMode = false
            DispatchQueue.main.async { self.selectedCollection.reloadItems(at: [indexPath]) }
        }
    }
    
    func cancelFetchForItemAt(index: Int) {

        if index < 0 { return }
        
        guard let cell = selectedCollection.cellForItem(at: IndexPath(item: index, section: 0)) as? SelectedImageCell else { return }
        guard let currentObject = UploadImageModel.shared.scrollObjects[safe: index] else { return }
        let currentAsset = currentObject.asset
        
        cell.activityIndicator.stopAnimating()
        imageFetcher.cancelFetchForAsset(asset: currentAsset)
    }
}

class SelectedImageCell: UICollectionViewCell {
    
    var imageObject: ImageObject!
    
    var imageView: UIImageView!
    var cancelButton: UIButton!
    var aliveToggle: UIButton!
    
    lazy var activityIndicator = UIActivityIndicatorView()
    var globalRow = 0
    
    var directionUp = true
    var animationIndex = 0
        
    func setUp(imageObject: ImageObject) {
        
        backgroundColor = nil
        resetCell()
        
        self.imageObject = imageObject
        /// only set imageview when necessary to keep animation state
        if imageView == nil {
            imageView = UIImageView(frame: self.bounds)
            imageView.clipsToBounds = true
            imageView.contentMode = .scaleAspectFill
            imageView.layer.cornerRadius = 9
            imageView.layer.cornerCurve = .continuous
            imageView.isUserInteractionEnabled = true
            addSubview(imageView)
        }
        
        let animating = !(imageView.animationImages?.isEmpty ?? true)
        
        /// remove animation images to stop animation
        if !imageObject.gifMode {
            imageView.image = imageObject.stillImage
            imageView.animationImages?.removeAll()
            
        } else {
            imageView.animationImages = imageObject.animationImages
            if !animating { animateScrollGif() }
        }
        
        cancelButton = UIButton(frame: CGRect(x: bounds.width - 35, y: 2, width: 33, height: 33))
        cancelButton.setImage(UIImage(named: "ImageCancelButton"), for: .normal)
        cancelButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        cancelButton.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
        addSubview(cancelButton)
        
        if imageObject.asset.mediaSubtypes.contains(.photoLive) {
            aliveToggle = UIButton(frame: CGRect(x: 0, y: self.bounds.height - 42, width: 60, height: 42))
            /// 74 x 33
            let image = imageObject.gifMode ? UIImage(named: "AliveOn") : UIImage(named: "AliveOff")
            aliveToggle.setImage(image, for: .normal)
            aliveToggle.imageView?.contentMode = .scaleAspectFit
            aliveToggle.contentHorizontalAlignment = .fill
            aliveToggle.contentVerticalAlignment = .fill
            aliveToggle.imageEdgeInsets = UIEdgeInsets(top: 7, left: 7, bottom: 7, right: 7)
            addSubview(aliveToggle)
            
            activityIndicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
            activityIndicator.isHidden = true
            activityIndicator.color = .white
            activityIndicator.transform = CGAffineTransform(scaleX: 1.8, y: 1.8)
            addSubview(activityIndicator)
        }
    }
    
    func resetCell() {
        if imageView != nil { imageView.image = UIImage() }
        if cancelButton != nil { cancelButton.setImage(UIImage(), for: .normal) }
        if aliveToggle != nil { aliveToggle.setImage(UIImage(), for: .normal) }
        activityIndicator.removeFromSuperview()
    }
    
    func addActivityIndicator() {
        bringSubviewToFront(activityIndicator)
        activityIndicator.startAnimating()
    }
    
    func removeActivityIndicator() {
        activityIndicator.stopAnimating()
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        var index = -1 /// -1 for image from camera
        if let i = UploadImageModel.shared.imageObjects.firstIndex(where: {$0.image.id == imageObject.id}) { index = i }
        uploadVC.deselectImage(index: index, circleTap: true)
        imageObject = nil
        imageView = nil
    }
    
    func animateScrollGif() {

        if imageView == nil || imageView.isHidden || imageView.animationImages?.isEmpty ?? true { return }
        let animationImages = imageView.animationImages

        UIView.transition(with: self, duration: 0.06, options: [.allowUserInteraction, .beginFromCurrentState], animations: { [weak self] in
                            guard let self = self else { return }
            if animationImages?.isEmpty ?? true { return }
            if self.animationIndex >= animationImages?.count ?? 0 { return }
            self.imageView.image = animationImages![self.animationIndex] },
                          completion: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06 + 0.005) { [weak self] in
            guard let self = self else { return }
            
            var newDirection = self.directionUp
            var newCount = self.animationIndex
            
            if self.directionUp {
                if self.animationIndex == animationImages!.count - 1 {
                    newDirection = false
                    newCount = animationImages!.count - 2
                } else {
                    newCount += 1
                }
            } else {
                if self.animationIndex == 0 {
                    newDirection = true
                    newCount = 1
                } else {
                    newCount -= 1
                }
            }

            self.animationIndex = newCount
            self.directionUp = newDirection
            self.animateScrollGif()
        }
    }

}

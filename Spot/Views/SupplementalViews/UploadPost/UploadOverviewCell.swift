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

/// upload overview cell and subclasses for UploadPostController
class UploadOverviewCell: UITableViewCell, UITextViewDelegate {
    
    var profilePic: UIImageView!
    var username: UILabel!
    
    var spotImage: UIImageView!
    var spotLabel: UILabel!
    
    var usernameDetail: UIView!
    var tagImage: UIImageView!
    var addedUsersView: AddedUsersView!
    
    var captionView: UITextView!
    var cameraCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewLayout.init())
    
    var scrollObjects: [ScrollObject] = []
    
    func setUp(post: MapPost, scrollObjects: [ScrollObject]) {
        
        backgroundColor = .black
        contentView.backgroundColor = .black
        
        resetCell()
        
        selectionStyle = .none
        self.scrollObjects = scrollObjects
        
        let bigScreen = UserDataModel.shared.screenSize == 2
        let minX: CGFloat = bigScreen ? 15 : 9
        profilePic = UIImageView(frame: CGRect(x: 15, y: minX, width: 48, height: 48))
        profilePic.layer.cornerRadius = profilePic.frame.width/2
        profilePic.clipsToBounds = true
        profilePic.image = post.userInfo.id == "" ? UIImage(color: UIColor(named: "BlankImage")!) : post.userInfo.profilePic
        contentView.addSubview(profilePic)
        
        username = UILabel(frame: CGRect(x: profilePic.frame.maxX + 10, y: profilePic.frame.minY + 7, width: 200, height: 16))
        username.text = post.userInfo == nil ? "" : post.userInfo!.username
        username.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        username.font = UIFont(name: "SFCamera-Semibold", size: 14)
        username.sizeToFit()
        contentView.addSubview(username)
        
        usernameDetail = UIView(frame: CGRect(x: username.frame.maxX + 1, y: username.frame.minY - 5.5, width: UIScreen.main.bounds.width - username.frame.minX - 50, height: 25))
        contentView.addSubview(usernameDetail)
        
        let alpha = post.spotName == "" ? 0.55 : 1.0
        spotImage = UIImageView(frame: CGRect(x: profilePic.frame.maxX + 8.5, y: username.frame.maxY + 5, width: 16.5, height: 16.5))
        spotImage.image = UIImage(named: "FeedSpotIcon")
        spotImage.alpha = alpha
        addSubview(spotImage)
                
        addDetail(post: post)
        
        ///hardcode cell height in case its laid out before view fully appears
        let cellHeight: CGFloat = UserDataModel.shared.screenSize == 0 ? 244 : UserDataModel.shared.screenSize == 1 ? 265 : 325
        captionView = UITextView(frame: CGRect(x: 19, y: profilePic.frame.maxY + 9, width: UIScreen.main.bounds.width - 38, height: cellHeight - 185))
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
        
        let cameraLayout = UICollectionViewFlowLayout()
        cameraLayout.scrollDirection = .horizontal
        cameraLayout.itemSize = CGSize(width: 75, height: 95)
        cameraLayout.minimumInteritemSpacing = 12
        cameraLayout.sectionInset = UIEdgeInsets(top: 0, left: 11, bottom: 0, right: 11)
        
        cameraCollection.frame = CGRect(x: 0, y: captionView.frame.maxY + 10, width: UIScreen.main.bounds.width, height: 100)
        cameraCollection.backgroundColor = .black
        cameraCollection.delegate = self
        cameraCollection.dataSource = self
        cameraCollection.isScrollEnabled = true
        cameraCollection.setCollectionViewLayout(cameraLayout, animated: false)
        cameraCollection.showsHorizontalScrollIndicator = false
        cameraCollection.register(UploadCameraCell.self, forCellWithReuseIdentifier: "UploadCamera")
        cameraCollection.register(UploadGalleryCell.self, forCellWithReuseIdentifier: "UploadGallery")
        cameraCollection.register(UploadImageCell.self, forCellWithReuseIdentifier: "UploadImage")
        addSubview(cameraCollection)
        
        //  cameraCollection.reloadData()
        cameraCollection.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
    }
    
    func addDetail(post: MapPost) {
        
        if post.spotName != "" {
            
            spotImage.alpha = 1.0
            
            spotLabel = UILabel(frame: CGRect(x: spotImage.frame.maxX + 4, y: username.frame.maxY + 6.5, width: UIScreen.main.bounds.width - spotImage.frame.maxX - 17, height: 15))
            spotLabel.text = post.spotName
            spotLabel.textColor = UIColor(red: 0.525, green: 0.525, blue: 0.525, alpha: 1)
            spotLabel.font = UIFont(name: "SFCamera-Semibold", size: 14)
            addSubview(spotLabel)
        } else { spotImage.alpha = 0.55 }
        
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
    }
    
    func resetCell() {
        if profilePic != nil { profilePic.image = UIImage() }
        if username != nil { username.text = "" }
        if spotImage != nil { spotImage.image = UIImage() }
        if spotLabel != nil { spotLabel.text = "" }
        if usernameDetail != nil { for sub in usernameDetail.subviews { sub.removeFromSuperview() } }
        if captionView != nil { captionView.text = "" }
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
        
        if textView.tag == 2 {
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
        return scrollObjects.count + 2
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if indexPath.row == 0 {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "UploadCamera", for: indexPath) as? UploadCameraCell else { return UICollectionViewCell() }
            cell.setUp()
            cell.imagesFull = UploadImageModel.shared.selectedObjects.count > 4
            return cell
            
        } else if indexPath.row == scrollObjects.count + 1 {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "UploadGallery", for: indexPath) as? UploadGalleryCell else { return UICollectionViewCell() }
            cell.setUp()
            cell.imagesFull = UploadImageModel.shared.selectedObjects.count > 4
            return cell
            
        } else {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "UploadImage", for: indexPath) as? UploadImageCell else { return UICollectionViewCell() }
            cell.setUp(scrollObject: scrollObjects[indexPath.row - 1], row: indexPath.row)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        guard let viewControllers = uploadVC.navigationController?.viewControllers else { return }
        if viewControllers.contains(where: {$0 is AVCameraController || $0 is PhotosContainerController}) { return } /// double stack happening
        
        if indexPath.row == 0 {
            
            if UploadImageModel.shared.selectedObjects.count > 4 { showMaxImagesAlert(); return }
            uploadVC.openCamera()
            
        } else if indexPath.row == scrollObjects.count + 1 {
            
            if UploadImageModel.shared.selectedObjects.count > 4 { showMaxImagesAlert(); return }
            uploadVC.openGallery()
                        
        } else {
            
            if uploadVC.scrollObjects[indexPath.row - 1].selected {
                uploadVC.deselectImage(index: indexPath.row - 1, circleTap: false)
                
            } else {
                uploadVC.selectImage(index: indexPath.row - 1, circleTap: false)
            }
            
        }
    }
    
    func showMaxImagesAlert() {
        
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        
        let errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 100, width: UIScreen.main.bounds.width, height: 32))
        let errorLabel = UILabel(frame: CGRect(x: 23, y: 6, width: UIScreen.main.bounds.width - 46, height: 18))

        errorBox.backgroundColor = UIColor.lightGray
        errorLabel.textColor = UIColor.white
        errorLabel.textAlignment = .center
        errorLabel.text = "5 photos max"
        errorLabel.font = UIFont(name: "SFCamera-Semibold", size: 14)
        
        uploadVC.view.addSubview(errorBox)
        errorBox.addSubview(errorLabel)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            errorLabel.removeFromSuperview()
            errorBox.removeFromSuperview()
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        /// push location picker once content offset pushes 50 pts past the natural boundary
        if scrollView.contentOffset.x > scrollView.contentSize.width - UIScreen.main.bounds.width + 60 {
            guard let uploadVC = viewContainingController() as? UploadPostController else { return }
            uploadVC.openGallery()
        }
    }
}

class UploadCameraCell: UICollectionViewCell {
    
    var cameraIcon: UIImageView!
    var imagesFull = false
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        
        backgroundColor = UIColor(red: 0.075, green: 0.075, blue: 0.075, alpha: 1)
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
    }
    
    func setUp() {
        let alpha: CGFloat = imagesFull ? 0.3 : 1.0
        if cameraIcon != nil { cameraIcon.image = UIImage() }
        cameraIcon = UIImageView(frame: CGRect(x: 25, y: 36, width: 25.5, height: 20))
        cameraIcon.image = UIImage(named: "UploadCameraButton")!.alpha(alpha)
        cameraIcon.isUserInteractionEnabled = false
        addSubview(cameraIcon)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class UploadGalleryCell: UICollectionViewCell {
    
    var galleryIcon: UIImageView!
    var imagesFull = false

    override init(frame: CGRect) {
        
        super.init(frame: frame)
        
        backgroundColor = UIColor(red: 0.075, green: 0.075, blue: 0.075, alpha: 1)
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
    }
    
    func setUp() {
        let alpha: CGFloat = imagesFull ? 0.3 : 1.0
        if galleryIcon != nil { galleryIcon.image = UIImage() }
        galleryIcon = UIImageView(frame: CGRect(x: 25, y: 36, width: 25.5, height: 20))
        galleryIcon.image = UIImage(named: "UploadGalleryButton")!.alpha(alpha)
        galleryIcon.isUserInteractionEnabled = false
        addSubview(galleryIcon)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class UploadImageCell: UICollectionViewCell {
    
    var image: UIImageView!
    var imageMask: UIView!
    var circleView: CircleView!
    lazy var activityIndicator = UIActivityIndicatorView()
    
    var globalRow: Int!
    var thumbnailSize: CGSize!
    lazy var requestID: Int32 = 1
    lazy var imageManager = PHCachingImageManager()
    var liveIndicator: UIImageView!
    
    var scrollObject: ScrollObject!
    
    func setUp(scrollObject: ScrollObject, row: Int) {
        
        self.backgroundColor = nil
        self.scrollObject = scrollObject
        self.globalRow = row
        
        thumbnailSize = CGSize(width: bounds.width * 1.5, height: bounds.height * 1.5)
        
        resetCell()
        
        let downloaded = scrollObject.imageObject.stillImage != UIImage()
        image = UIImageView(frame: self.bounds)
        image.image = downloaded ? scrollObject.imageObject.stillImage : UIImage(color: UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1), size: thumbnailSize)
        image.clipsToBounds = true
        image.contentMode = .scaleAspectFill
        image.layer.cornerRadius = 8
        image.layer.cornerCurve = .continuous
        image.isUserInteractionEnabled = false
        
        addSubview(image)
        
        activityIndicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        activityIndicator.color = .white
        activityIndicator.transform = CGAffineTransform(scaleX: 1.8, y: 1.8)
        activityIndicator.isHidden = true
        addSubview(activityIndicator)
        
        /// add mask for selected images
        if scrollObject.selected { addImageMask() }
        
        if scrollObject.imageObject.asset.mediaSubtypes.contains(.photoLive) {
            liveIndicator = UIImageView(frame: CGRect(x: self.bounds.midX - 9, y: self.bounds.midY - 9, width: 18, height: 18))
            liveIndicator.image = UIImage(named: "PreviewGif")
            addSubview(liveIndicator)
        }
        
        let index = scrollObject.selected ? row : 0
        addCircle(index: index)
        if downloaded { return }
        
        /// fetch from asset if not downloaded yet
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            
            guard let self = self else { return }
            
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            
            self.requestID = self.imageManager.requestImage(for: scrollObject.imageObject.asset, targetSize: self.thumbnailSize, contentMode: .aspectFill, options: options) { (result, info) in
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if result != nil { self.image.image = result! }
                }
            }
        }
    }
    
    private func addImageMask() {
        
        imageMask = UIView(frame: self.bounds)
        imageMask.backgroundColor = UIColor(named: "SpotBlack")?.withAlphaComponent(0.5)
        
        let layer = CAGradientLayer()
        layer.frame = imageMask.bounds
        layer.colors = [
            UIColor(red: 0.098, green: 0.783, blue: 0.701, alpha: 0.13).cgColor,
            UIColor(red: 0.098, green: 0.784, blue: 0.702, alpha: 0.03).cgColor,
            UIColor(red: 0.098, green: 0.784, blue: 0.702, alpha: 0.1).cgColor,
            UIColor(red: 0.098, green: 0.783, blue: 0.701, alpha: 0.33).cgColor
        ]
        layer.locations = [0, 0.3, 0.66, 1]
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        imageMask.layer.addSublayer(layer)
        
        addSubview(imageMask)
    }
    
    func addActivityIndicator() {
        bringSubviewToFront(activityIndicator)
        activityIndicator.startAnimating()
    }
    
    func removeActivityIndicator() {
        activityIndicator.stopAnimating()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        activityIndicator.stopAnimating()
        imageManager.cancelImageRequest(requestID)
        image.image = nil
        if imageMask != nil { for layer in imageMask.layer.sublayers ?? [] { layer.removeFromSuperlayer() } }
    }
    
    deinit {
        imageManager.cancelImageRequest(requestID)
    }
    
    func resetCell() {
        
        if image != nil { image.image = nil }
        if circleView != nil { for sub in circleView.subviews {sub.removeFromSuperview()}; circleView = CircleView() }
        if liveIndicator != nil { liveIndicator.image = UIImage() }
        
        if self.gestureRecognizers != nil {
            for gesture in self.gestureRecognizers! {
                self.removeGestureRecognizer(gesture)
            }
        }
    }
    
    func addCircle(index: Int) {
        
        circleView = CircleView(frame: CGRect(x: bounds.width - 31, y: bounds.height - 31, width: 24, height: 24))
        circleView.setUp(index: index)
        addSubview(circleView)
        
        let circleButton = UIButton(frame: CGRect(x: bounds.width - 36, y: bounds.height - 36, width: 34, height: 34))
        circleButton.addTarget(self, action: #selector(circleTap(_:)), for: .touchUpInside)
        addSubview(circleButton)
    }
    
    @objc func circleTap(_ sender: UIButton) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        scrollObject.selected ? uploadVC.deselectImage(index: globalRow - 1, circleTap: true) : uploadVC.selectImage(index: globalRow - 1, circleTap: true)
    }
}

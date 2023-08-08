//
//  CreatePostController.swift
//  Spot
//
//  Created by Kenny Barone on 7/20/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import IQKeyboardManagerSwift
import PhotosUI
import GeoFireUtils
import Mixpanel

protocol CreatePostDelegate: AnyObject {
    func finishUpload(post: MapPost)
}

class CreatePostController: UIViewController {
    private let spot: MapSpot
    private let parentPostID: String?
    private let replyUsername: String?
    private let parentPosterID: String?

    let textViewPlaceholder = "sup..."

    private lazy var replyUsernameView = ReplyUsernameView()

    private(set) lazy var avatarImage = UIImageView()

    private(set) lazy var textView: UITextView = {
        let view = UITextView()
        view.backgroundColor = nil
        view.textColor = UIColor(red: 0.954, green: 0.954, blue: 0.954, alpha: 1)
        view.font = UIFont(name: "SFCompactText-Regular", size: 22.5)
        view.alpha = 0.6
        view.tintColor = UIColor(named: "SpotGreen")
        view.text = textViewPlaceholder
        view.isScrollEnabled = false
        view.textContainer.maximumNumberOfLines = 8
        view.textContainer.lineBreakMode = .byTruncatingHead
        view.isUserInteractionEnabled = true
        return view
    }()

    private(set) lazy var tagFriendsView = TagFriendsView()

    private(set) lazy var cameraButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "CreatePostCameraButton"), for: .normal)
        button.addTarget(self, action: #selector(cameraTap), for: .touchUpInside)
        return button
    }()

    var thumbnailView: CreateThumbnailView? {
        didSet {
            cameraButton.isHidden = thumbnailView != nil
            togglePostButton()
        }
    }

    private(set) lazy var progressMask: UIView = {
        let view = UIView()
        view.backgroundColor = .black.withAlphaComponent(0.7)
        view.isHidden = true
        return view
    }()
    private(set) lazy var progressBar = ProgressBar()

    var imageObject: ImageObject?
    var videoObject: VideoObject?
    weak var delegate: CreatePostDelegate?

    var postCaption: String {
        let rawText = textView.text == textViewPlaceholder ? "" : textView.text ?? ""
        return rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(spot: MapSpot, parentPostID: String?, replyUsername: String?, parentPosterID: String?, imageObject: ImageObject?, videoObject: VideoObject?) {
        self.spot = spot
        self.parentPostID = parentPostID
        self.replyUsername = replyUsername
        self.parentPosterID = parentPosterID
        self.imageObject = imageObject
        self.videoObject = videoObject
        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = SpotColors.SpotBlack.color

        if let replyUsername {
            replyUsernameView.configure(username: replyUsername)
            view.addSubview(replyUsernameView)
            replyUsernameView.snp.makeConstraints {
                $0.top.equalTo(8)
                $0.leading.equalTo(14)
            }
        }

        view.addSubview(avatarImage)
        let userAvatar = UserDataModel.shared.userInfo.getAvatarImage()
        avatarImage.image = userAvatar
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(14)
            $0.width.equalTo(45.33)
            $0.height.equalTo(51)
            if replyUsername == nil {
                $0.top.equalTo(18)
            } else {
                $0.top.equalTo(replyUsernameView.snp.bottom).offset(8)
            }
        }

        view.addSubview(textView)
        textView.delegate = self
        textView.snp.makeConstraints {
            $0.leading.equalTo(avatarImage.snp.trailing).offset(9)
            $0.top.equalTo(avatarImage).offset(6)
            $0.trailing.equalToSuperview().inset(18)
        }

        view.addSubview(cameraButton)
        cameraButton.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalTo(-100)
        }

        view.addSubview(progressMask)
        progressMask.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        progressMask.addSubview(progressBar)
        progressBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(50)
            $0.bottom.equalTo(-100)
            $0.height.equalTo(18)
        }

        if imageObject != nil || videoObject != nil {
            addThumbnailView(imageObject: imageObject, videoObject: videoObject)
        }
    }

    deinit {
        print("deinit create")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableKeyboardMethods()
        textView.becomeFirstResponder()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        disableKeyboardMethods()
    }

    private func setUpNavBar() {
        navigationController?.setUpDarkNav(translucent: false)
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont(name: "UniversCE-Black", size: 19) as Any
        ]
        navigationItem.title = spot.spotName

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "SEND", style: .plain, target: self, action: #selector(postTap))
        navigationItem.rightBarButtonItem?.setTitleTextAttributes([.foregroundColor : UIColor(named: "SpotGreen") as Any, .font: UIFont(name: "SFCompactRounded-Bold", size: 17) as Any], for: .normal)
        navigationItem.rightBarButtonItem?.setTitleTextAttributes([.foregroundColor : UIColor.darkGray, .font: UIFont(name: "SFCompactRounded-Bold", size: 17) as Any], for: .disabled)
        togglePostButton()
    }

    func togglePostButton() {
        navigationItem.rightBarButtonItem?.isEnabled = !postCaption.isEmpty || thumbnailView != nil
    }

    @objc func cameraTap() {
        launchCamera()
    }

    @objc func postTap() {
        guard let imageVideoService = try? ServiceContainer.shared.service(for: \.imageVideoService) else {
            return
        }
        Mixpanel.mainInstance().track(event: "UploadPostTap")
        // 1. Update UX to reflect upload state (progress view + disable user interaction)
        navigationController?.navigationBar.isUserInteractionEnabled = false
        view.isUserInteractionEnabled = false

        // 2. Configure new, simplified upload to DB function
        let postImage = thumbnailView?.thumbnailImage
        var postObject = MapPost(postImage: postImage, caption: postCaption, spot: spot)
        postObject.parentPostID = parentPostID
        postObject.parentPosterUsername = replyUsername
        postObject.parentPosterID = parentPosterID
        postObject.userInfo = UserDataModel.shared.userInfo
        postObject.generateSnapshot()

        if imageObject != nil {
            addProgressView()
            imageVideoService.uploadImages(
                images: postObject.postImage,
                parentView: view,
                progressFill: progressBar.progressFill,
                fullWidth: self.progressBar.bounds.width - 2
            ) { [weak self] imageURLs, failed in
                guard let self = self else { return }
                if imageURLs.isEmpty && failed {
                    Mixpanel.mainInstance().track(event: "FailedPostUploadOnImage")
                    self.showFailAlert()
                    return
                }
                print("got image urls")
                postObject.imageURLs = imageURLs
                self.uploadPostToDB(postObject: postObject)
            }

        } else if let videoObject {
            addProgressView()
            let dispatch = DispatchGroup()
            dispatch.enter()

            //MARK: Upload video data
            guard let data = try? Data(contentsOf: videoObject.videoPath) else {
                showFailAlert()
                return
            }
            imageVideoService.uploadVideo(data: data) { [weak self] (videoURL) in
                guard videoURL != "" else {
                    self?.showFailAlert()
                    return
                }
                postObject.videoURL = videoURL
                dispatch.leave()
            } failure: { [weak self] _ in
                self?.showFailAlert()
                return
            }

            //MARK: Upload thumbnail image
            dispatch.enter()
            imageVideoService.uploadImages(
                images: postObject.postImage,
                parentView: view,
                progressFill: self.progressBar.progressFill,
                fullWidth: self.progressBar.bounds.width - 2

            ) { [weak self] imageURLs, failed in
                if imageURLs.isEmpty && failed {
                    Mixpanel.mainInstance().track(event: "FailedPostUploadOnVideo")
                    self?.showFailAlert()
                    return
                }
                postObject.imageURLs = imageURLs
                dispatch.leave()
            }

            //MARK: Finish upload
            dispatch.notify(queue: .global()) { [weak self] in
                self?.uploadPostToDB(postObject: postObject)
            }
        } else {
            // text post
            uploadPostToDB(postObject: postObject)
        }
    }

    private func uploadPostToDB(postObject: MapPost) {
        guard let spotService = try? ServiceContainer.shared.service(for: \.spotService),
              let postService = try? ServiceContainer.shared.service(for: \.mapPostService),
              let userService = try? ServiceContainer.shared.service(for: \.userService)
        else { return }

        // MARK: save photo/video to library
        let galleryAuth = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch galleryAuth {
        case .authorized, .limited:
            if let imageObject, imageObject.fromCamera {
                DispatchQueue.global(qos: .background).async {
                    SpotPhotoAlbum.shared.save(image: imageObject.stillImage)
                }

            } else if let videoObject, videoObject.fromCamera {
                DispatchQueue.global(qos: .background).async {
                    SpotPhotoAlbum.shared.save(videoURL: videoObject.videoPath, addWatermark: true)
                }
            }
        default: break
        }

        DispatchQueue.global(qos: .background).async {
            var spot = self.spot
            spot.imageURL = postObject.imageURLs.first ?? ""

            // don't need to update spot level values for comments
            if self.parentPostID == nil {
                spotService.uploadSpot(
                    post: postObject,
                    spot: spot
                )
            }

            postService.uploadPost(post: postObject, spot: spot)

            userService.setUserValues(
                poster: UserDataModel.shared.uid,
                post: postObject
            )

            Mixpanel.mainInstance().track(event: "SuccessfulPostUpload")
        }

        //MARK: Configure passback to SpotController
        self.delegate?.finishUpload(post: postObject)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // enable upload animation to finish
            HapticGenerator.shared.play(.soft)
            self.navigationController?.popViewController(animated: true)
        }
    }

    private func addProgressView() {
        progressMask.isHidden = false
        view.bringSubviewToFront(progressMask)
    }

    private func showFailAlert() {
        let alert = UIAlertController(title: "Upload failed", message: "", preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(title: "OK", style: .default) { _ in }
        )
        present(alert, animated: true, completion: nil)
    }
}

// MARK: image / video methods
extension CreatePostController {
    func addThumbnailView(imageObject: ImageObject?, videoObject: VideoObject?) {
        let thumbnailImage = imageObject?.stillImage ?? videoObject?.thumbnailImage ?? UIImage()
        let thumbnailView = CreateThumbnailView(thumbnailImage: thumbnailImage, videoURL: videoObject?.videoPath)
        thumbnailView.delegate = self

        let imageAspect = thumbnailImage.size.height / thumbnailImage.size.width
        let imageWidth = UIScreen.main.bounds.width - 152
        let imageHeight = min(imageAspect, 1.23) * (imageWidth)

        view.addSubview(thumbnailView)
        thumbnailView.snp.makeConstraints {
            $0.leading.equalTo(18)
            $0.top.greaterThanOrEqualTo(avatarImage.snp.bottom).offset(12)
            $0.top.greaterThanOrEqualTo(textView.snp.bottom)
            $0.height.equalTo(imageHeight)
            $0.width.equalTo(imageWidth)
        }

        self.thumbnailView = thumbnailView
        self.imageObject = imageObject
        self.videoObject = videoObject
    }

    func launchCamera() {
        addActionSheet()
    }

    func addActionSheet() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(
            UIAlertAction(title: "Camera", style: .default) { [weak self] _ in
                self?.launchImagePicker()
            }
        )

        alert.addAction(
            UIAlertAction(title: "Gallery", style: .default) { [weak self] _ in
                self?.launchPhotoPicker()
            }
        )

        alert.addAction(
            UIAlertAction(title: "Dismiss", style: .cancel) { _ in
            }
        )
        present(alert, animated: true)
    }

    private func launchImagePicker() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = false
        picker.mediaTypes = ["public.image", "public.movie"]
        picker.sourceType = .camera
        picker.videoMaximumDuration = 15
        picker.videoQuality = .typeHigh
        self.present(picker, animated: true)
    }

    private func launchPhotoPicker() {
        var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        config.filter = .any(of: [.images, .videos])
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        self.present(picker, animated: true)
    }

    func launchStillImagePreview(imageObject: ImageObject) {
        let vc = StillImagePreviewView(imageObject: imageObject)
        vc.delegate = self
        self.navigationController?.pushViewController(vc, animated: false)
    }

    func launchVideoEditor(asset: PHAsset) {
        let vc = VideoEditorController(videoAsset: asset)
        vc.delegate = self
        self.navigationController?.pushViewController(vc, animated: false)
    }
}


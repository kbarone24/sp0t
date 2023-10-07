//
//  CreatePostController.swift
//  Spot
//
//  Created by Kenny Barone on 7/20/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import PhotosUI
import GeoFireUtils
import Mixpanel

protocol CreatePostDelegate: AnyObject {
    func finishUpload(post: Post)
}

class CreatePostController: UIViewController {
    private var spot: Spot?
    private var map: CustomMap?
    private let parentPostID: String?
    private let parentPosterID: String?
    // reply to info is the same as parent info if replying to a post, reply to info will = comment you're replying to, parentPost will always be the parent post in the thread
    let replyToID: String?
    let replyToUsername: String?

    let textViewPlaceholder = "sup..."
    var usernameText: String? {
        if let replyToUsername, replyToUsername != "" {
            return "@\(replyToUsername) "
        }
        return nil
    }

    var taggedUserIDs = [String]()
    var taggedUsernames = [String]()

    private lazy var replyUsernameView = ReplyUsernameView()

    private lazy var spotAndMapView = ChooseSpotAndMapView()

    private(set) lazy var avatarImage = UIImageView()

    private(set) lazy var textView: UITextView = {
        let view = UITextView()
        view.backgroundColor = nil
        view.textColor = UIColor(red: 0.954, green: 0.954, blue: 0.954, alpha: 1)
        view.font = SpotFonts.SFCompactRoundedRegular.fontWith(size: 22.5)
        view.alpha = 0.6
        view.tintColor = UIColor(named: "SpotGreen")
        view.isScrollEnabled = false
        view.textContainer.maximumNumberOfLines = 8
        view.textContainer.lineBreakMode = .byTruncatingHead
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        view.text = textViewPlaceholder
        return view
    }()

    private lazy var replyUsernameLabel: UILabel = {
        let label = UILabel()
        label.textColor = SpotColors.SublabelGray.color
        label.font = SpotFonts.SFCompactRoundedRegular.fontWith(size: 22.5)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private(set) lazy var tagFriendsView = TagFriendsView()

    private(set) lazy var cameraButton: UIButton = {
        let button = UIButton(withInsets: NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
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

    init(spot: Spot?, map: CustomMap?, parentPostID: String?, parentPosterID: String?, replyToID: String?, replyToUsername: String?, imageObject: ImageObject?, videoObject: VideoObject?) {
        self.spot = spot
        self.map = map
        self.parentPostID = parentPostID
        self.parentPosterID = parentPosterID
        self.replyToID = replyToID
        self.replyToUsername = replyToUsername

        self.imageObject = imageObject
        self.videoObject = videoObject
        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = SpotColors.SpotBlack.color
        setUpView()

        if let spot, spot.createdFromPOI {
            setSpotCity()
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
        edgesForExtendedLayout = []
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableKeyboardMethods()
        textView.becomeFirstResponder()

        Mixpanel.mainInstance().track(event: "CreatePostAppeared")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        disableKeyboardMethods()
    }

    private func setUpNavBar() {
        navigationController?.setUpOpaqueNav(backgroundColor: SpotColors.HeaderGray.color)
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont(name: "UniversCE-Black", size: 19) as Any
        ]
        if let replyToUsername {
            navigationItem.title = "Reply to \(replyToUsername)"
        } else {
            navigationItem.title = "Create post"
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "SEND", style: .plain, target: self, action: #selector(postTap))
        navigationItem.rightBarButtonItem?.setTitleTextAttributes([.foregroundColor : UIColor.white, .font: SpotFonts.SFCompactRoundedBold.fontWith(size: 17)], for: .normal)
        navigationItem.rightBarButtonItem?.setTitleTextAttributes([.foregroundColor : UIColor.darkGray, .font: SpotFonts.SFCompactRoundedBold.fontWith(size: 17)], for: .disabled)
        togglePostButton()

    }

    private func setUpView() {
        if let replyToUsername {
            replyUsernameView.configure(username: replyToUsername)
            view.addSubview(replyUsernameView)
            replyUsernameView.snp.makeConstraints {
                $0.top.equalTo(8)
                $0.leading.equalTo(14)
            }
        } else {

            view.addSubview(spotAndMapView)
            spotAndMapView.configure(spotName: spot?.spotName, mapName: map?.mapName)
            spotAndMapView.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(16)
                $0.height.equalTo(30)
                if replyToUsername == nil {
                    $0.top.equalTo(18)
                } else {
                    $0.top.equalTo(replyUsernameView.snp.bottom).offset(12)
                }
            }

            if spot != nil {
                // disable user interaction on passed spot
                spotAndMapView.spotContainer.layer.borderWidth = 0
            } else {
                spotAndMapView.spotContainer.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(chooseSpotTap)))
            }

            if map != nil  {
                // disable user interaction on passed map
                spotAndMapView.mapContainer.layer.borderWidth = 0
            } else {
                spotAndMapView.mapContainer.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(chooseMapTap)))
            }
        }

        view.addSubview(avatarImage)
        let userAvatar = UserDataModel.shared.userInfo.getAvatarImage()
        avatarImage.image = userAvatar
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(14)
            $0.width.equalTo(45.33)
            $0.height.equalTo(51)
            if replyToUsername != nil {
                $0.top.equalTo(replyUsernameView.snp.bottom).offset(8)
            } else {
                $0.top.equalTo(spotAndMapView.snp.bottom).offset(8)
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
            $0.leading.trailing.equalToSuperview().inset(2)
            $0.top.equalTo(0)
            $0.height.equalTo(2)
        }

        if imageObject != nil || videoObject != nil {
            addThumbnailView(imageObject: imageObject, videoObject: videoObject)
        }
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
        let caption = getCaptionWithUsername()
        var postObject = Post(postImage: postImage, caption: caption, spot: spot, map: map)

        postObject.parentPostID = parentPostID
        postObject.parentPosterID = parentPosterID
        postObject.replyToID = replyToID
        postObject.replyToUsername = replyToUsername

        let taggedUsernames = caption.getTaggedUsernames()

        Task {
            for username in taggedUsernames {
                if let replyToUsername, replyToUsername != "", let replyToID, username == replyToUsername {
                    // avoid fetching original posters info
                    postObject.taggedUsers?.append(replyToUsername)
                    postObject.taggedUserIDs?.append(replyToID)
                    
                } else {
                    guard let userService = try? ServiceContainer.shared.service(for: \.userService),
                          let user = try? await userService.getUserFromUsername(username: username) else { continue }
                    postObject.taggedUsers?.append(user.username)
                    postObject.taggedUserIDs?.append(user.id ?? "")
                }
            }

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
    }

    private func uploadPostToDB(postObject: Post) {
        guard let spotService = try? ServiceContainer.shared.service(for: \.spotService),
              let postService = try? ServiceContainer.shared.service(for: \.postService),
              let userService = try? ServiceContainer.shared.service(for: \.userService),
              let mapService = try? ServiceContainer.shared.service(for: \.mapService)
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
            let map = self.map
            spot?.imageURL = postObject.imageURLs.first ?? ""

            // don't need to update spot/map level values for comments
            if self.parentPostID == nil {
                if let spot {
                    spotService.uploadSpot(
                        post: postObject,
                        spot: spot,
                        map: map
                    )
                }

                if var map {
                    map.updatePostLevelValues(post: postObject)
                    mapService.uploadMap(
                        map: map,
                        post: postObject,
                        spot: spot
                    )
                }
            }

            postService.uploadPost(post: postObject, spot: spot, map: map)

            userService.setUserValues(
                poster: UserDataModel.shared.uid,
                post: postObject
            )

            Mixpanel.mainInstance().track(event: "SuccessfulPostUpload")
        }

        //MARK: Configure passback to SpotController
        DispatchQueue.main.async {
            // enable upload animation to finish
            HapticGenerator.shared.play(.soft)
            self.delegate?.finishUpload(post: postObject)
            self.navigationController?.popViewController(animated: true)
        }
    }

    private func getCaptionWithUsername() -> String {
        if let usernameText, replyToID != parentPosterID {
            return usernameText + postCaption
        }
        return postCaption
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

    private func setSpotCity() {
        guard let locationService = try? ServiceContainer.shared.service(for: \.locationService), let spot = spot else {
            return
        }

        Task {
            let city = await locationService.getCityFromLocation(location: spot.location, zoomLevel: .city)
            print("city", city)
            self.spot?.city = city
        }
    }
}

//MARK: Choose spot / map methods
extension CreatePostController {
    @objc func chooseSpotTap() {
        let vc = ChooseSpotController(viewModel: ChooseSpotViewModel(serviceContainer: ServiceContainer.shared), delegate: self, selectedSpot: spot)
        DispatchQueue.main.async {
            self.present(vc, animated: true)
        }
    }

    @objc func chooseMapTap() {
        if let map, map.newMap {
            DispatchQueue.main.async {
                let vc = NewMapController(mapObject: map, delegate: self)
                self.present(vc, animated: true)
            }

        } else {
            DispatchQueue.main.async {
                let vc = ChooseMapController(viewModel: ChooseMapViewModel(serviceContainer: ServiceContainer.shared), delegate: self, selectedMap: self.map)
                self.present(vc, animated: true)
            }
        }
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
                Mixpanel.mainInstance().track(event: "CreatePostGalleryOpen")
                self?.launchImagePicker()
            }
        )

        alert.addAction(
            UIAlertAction(title: "Gallery", style: .default) { [weak self] _ in
                Mixpanel.mainInstance().track(event: "CreatePostCameraOpen")
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

extension CreatePostController: ChooseSpotDelegate {
    func selectedSpot(spot: Spot) {
        self.spot = spot
        spotAndMapView.configure(spotName: spot.spotName, mapName: map?.mapName)
    }
}

extension CreatePostController: ChooseMapDelegate {
    func selectedMap(map: CustomMap) {
        self.map = map
        spotAndMapView.configure(spotName: spot?.spotName, mapName: map.mapName)
    }
}

extension CreatePostController: NewMapDelegate {
    func finishPassing(map: CustomMap) {
        self.map = map
        spotAndMapView.configure(spotName: spot?.spotName, mapName: map.mapName)
    }
}

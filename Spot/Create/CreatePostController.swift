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

class CreatePostController: UIViewController {
    private let spot: MapSpot
    private let parentPostID: String?
    private let replyUsername: String?
    private var openCamera: Bool = false

    var firstOpen = true
    let textViewPlaceholder = "sup..."

    private lazy var replyUsernameView = ReplyUsernameView()

    private lazy var avatarImage = UIImageView()

    private lazy var textView: UITextView = {
        let view = UITextView()
        view.backgroundColor = nil
        view.textColor = UIColor(red: 0.954, green: 0.954, blue: 0.954, alpha: 1)
        view.font = UIFont(name: "SFCompactText-Regular", size: 22.5)
        view.alpha = 0.6
        view.tintColor = UIColor(named: "SpotGreen")
        view.text = textViewPlaceholder
        view.returnKeyType = .done
        view.isScrollEnabled = false
        view.textContainer.maximumNumberOfLines = 8
        view.textContainer.lineBreakMode = .byTruncatingHead
        view.isUserInteractionEnabled = true
        return view
    }()

    private(set) lazy var tagFriendsView = TagFriendsView()

    private lazy var cameraButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "CreatePostCameraButton"), for: .normal)
        button.addTarget(self, action: #selector(cameraTap), for: .touchUpInside)
        return button
    }()

    weak var cameraPicker: UIImagePickerController?
    weak var galleryPicker: PHPickerViewController?

    init(spot: MapSpot, parentPostID: String?, replyUsername: String?, openCamera: Bool) {
        self.spot = spot
        self.parentPostID = parentPostID
        self.replyUsername = replyUsername
        self.openCamera = openCamera
        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1.00)

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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableKeyboardMethods()

        if openCamera {
            openCamera = false
            launchCamera()

        } else if firstOpen {
            textView.becomeFirstResponder()
        }
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
        navigationItem.rightBarButtonItem?.isEnabled = false
    }

    @objc func cameraTap() {
        launchCamera()
    }

    @objc func postTap() {
        // 1. Update UX to reflect upload state (progress view + disable user interaction)
        // 2. Configure new, simplified upload to DB function
        // 3. Configure passback to SpotController
    }
}

extension CreatePostController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == textViewPlaceholder { textView.text = ""; textView.alpha = 1.0 }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text == "" { textView.text = textViewPlaceholder; textView.alpha = 0.6 }
    }

    func textViewDidChange(_ textView: UITextView) {
        let cursor = textView.getCursorPosition()
        let text = textView.text ?? ""
        let tagTuple = text.getTagUserString(cursorPosition: cursor)
        let tagString = tagTuple.text
        let containsAt = tagTuple.containsAt
        if !containsAt {
            removeTagTable()
            textView.autocorrectionType = .default
        } else {
            addTagTable(tagString: tagString)
            textView.autocorrectionType = .no
        }

        navigationItem.rightBarButtonItem?.isEnabled = textView.text.count > 0
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // return on done button tap
        if text == "\n" { textView.endEditing(true); return false }
        return textView.shouldChangeText(range: range, replacementText: text, maxChar: 140)
    }

    func enableKeyboardMethods() {
        IQKeyboardManager.shared.enableAutoToolbar = false
        IQKeyboardManager.shared.enable = false
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    func disableKeyboardMethods() {
        IQKeyboardManager.shared.enableAutoToolbar = true
        IQKeyboardManager.shared.enable = true
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    @objc func keyboardWillShow(_ notification: NSNotification) {
        view.animateWithKeyboard(notification: notification) { keyboardFrame in
            self.cameraButton.snp.removeConstraints()
            self.cameraButton.snp.makeConstraints {
                $0.centerX.equalToSuperview()
                $0.bottom.equalToSuperview().offset(-keyboardFrame.height - 5)
            }
        }
    }

    @objc func keyboardWillHide(_ notification: NSNotification) {
        view.animateWithKeyboard(notification: notification) { _ in
            self.cameraButton.snp.removeConstraints()
            self.cameraButton.snp.makeConstraints {
                $0.centerX.equalToSuperview()
                $0.bottom.equalToSuperview().offset(-100)
            }
        }
    }
}

extension CreatePostController: TagFriendsDelegate {
    func removeTagTable() {
        tagFriendsView.removeFromSuperview()
    }

    func addTagTable(tagString: String) {
        tagFriendsView.setUp(userList: UserDataModel.shared.userInfo.friendsList, textColor: .white, delegate: self, allowSearch: true, tagParent: .ImagePreview, searchText: tagString)
        view.addSubview(tagFriendsView)
        tagFriendsView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(120)
            $0.top.equalTo(textView.snp.bottom)
        }
    }

    func finishPassing(selectedUser: UserProfile) {
        textView.addUsernameAtCursor(username: selectedUser.username)
        removeTagTable()
    }
}

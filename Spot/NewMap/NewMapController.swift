//
//  NewMapController.swift
//  Spot
//
//  Created by Kenny Barone on 6/23/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import IQKeyboardManagerSwift
import Mixpanel
import UIKit

protocol NewMapDelegate: AnyObject {
    func finishPassing(map: CustomMap)
}

class NewMapController: UIViewController {
    let uid: String = UserDataModel.shared.uid
    var mapObject: CustomMap?
    var delegate: NewMapDelegate?

    private lazy var nameField: UITextField = {
        let view = PaddedTextField()
        view.textColor = UIColor.black.withAlphaComponent(0.8)
        view.backgroundColor = UIColor(red: 0.983, green: 0.983, blue: 0.983, alpha: 1)
        view.layer.borderColor = UIColor(red: 0.925, green: 0.925, blue: 0.925, alpha: 1).cgColor
        view.layer.borderWidth = 1
        view.layer.cornerRadius = 14
        view.attributedPlaceholder = NSAttributedString(string: "Map name", attributes: [NSAttributedString.Key.foregroundColor: UIColor.black.withAlphaComponent(0.4)])
        view.font = UIFont(name: "SFCompactText-Heavy", size: 22)
        view.textAlignment = .left
        view.tintColor = UIColor(named: "SpotGreen")
        view.autocapitalizationType = .sentences
        view.delegate = self
        return view
    }()
    private lazy var collaboratorLabel: UILabel = {
        let label = UILabel()
        label.text = "Add friends"
        label.textColor = UIColor(red: 0.521, green: 0.521, blue: 0.521, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 14)
        return label
    }()
    private lazy var collaboratorsCollection: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 18
        layout.itemSize = CGSize(width: 62, height: 85)
        layout.sectionInset = UIEdgeInsets(top: 0, left: margin, bottom: 0, right: margin)

        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .white
        view.delegate = self
        view.dataSource = self
        view.showsHorizontalScrollIndicator = false
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 100)
        view.register(MapMemberCell.self, forCellWithReuseIdentifier: "MapMemberCell")
        view.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Default")
        return view
    }()
    private lazy var secretLabel: UILabel = {
        let label = UILabel()
        label.text = "Secret map"
        label.textColor = UIColor(red: 0.521, green: 0.521, blue: 0.521, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 14)
        return label
    }()
    private lazy var secretSublabel: UILabel = {
        let label = UILabel()
        label.text = "Only invited friends will see this map"
        label.textColor = UIColor(red: 0.658, green: 0.658, blue: 0.658, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 12.5)
        return label
    }()
    private lazy var secretToggle: UIButton = {
        let button = UIButton()
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    private lazy var secretIndicator: UILabel = {
        let label = UILabel()
        label.text = "OFF"
        label.textColor = UIColor(red: 0.851, green: 0.851, blue: 0.851, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Black", size: 14)
        return label
    }()

    private var exitButton: UIButton?
    private var nextButton: UIButton?
    private var createButton: UIButton?

    lazy var keyboardPan: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(keyboardPan(_:)))
        pan.isEnabled = false
        return pan
    }()
    var readyToDismiss = true
    var presentedModally = false

    let margin: CGFloat = 18
    var actionButton: UIButton {
        return presentedModally ? nextButton ?? UIButton() : createButton ?? UIButton()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if mapObject == nil { addMapObject() }
        setUpView()
        presentationController?.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if presentedModally { setUpNavBar() }
        enableKeyboardMethods()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nameField.becomeFirstResponder()
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        disableKeyboardMethods()
    }

    func addMapObject() {
        guard let post = UploadPostModel.shared.postObject else { return }
        // most values will be set in updatePostLevelValues
        mapObject = CustomMap(
            id: UUID().uuidString,
            founderID: uid,
            imageURL: "",
            likers: [uid],
            mapName: "",
            memberIDs: [uid],
            posterDictionary: [:],
            posterIDs: [],
            posterUsernames: [],
            postIDs: [],
            postImageURLs: [],
            postLocations: [],
            postTimestamps: [],
            secret: false,
            spotIDs: [],
            memberProfiles: [UserDataModel.shared.userInfo],
            coverImage: UIImage()
        )
        if !(post.addedUsers?.isEmpty ?? true) {
            mapObject?.memberIDs.append(contentsOf: post.addedUsers ?? [])
            mapObject?.likers.append(contentsOf: post.addedUsers ?? [])
            mapObject?.memberProfiles?.append(contentsOf: post.addedUserProfiles ?? [])
        }
    }

    func setUpView() {
        view.backgroundColor = .white
        // back button will show if pushed directly on map
        if !presentedModally {
            exitButton = UIButton {
                $0.setImage(UIImage(named: "CancelButtonDark"), for: .normal)
                $0.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
                $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
                view.addSubview($0)
            }
            exitButton?.snp.makeConstraints {
                $0.top.equalTo(10)
                $0.left.equalTo(10)
                $0.height.width.equalTo(35)
            }
        }

        nameField.delegate = self
        nameField.text = mapObject?.mapName ?? ""
        view.addSubview(nameField)
        let screenSizeOffset: CGFloat = UserDataModel.shared.screenSize == 2 ? 20 : 0
        let topOffset: CGFloat = presentedModally ? 25 + screenSizeOffset : 60 + screenSizeOffset
        nameField.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(margin)
            $0.trailing.equalToSuperview().offset(-30)
            $0.top.equalTo(topOffset)
            $0.height.equalTo(50)
        }

        view.addSubview(collaboratorLabel)
        collaboratorLabel.snp.makeConstraints {
            $0.leading.equalTo(margin)
            $0.top.equalTo(nameField.snp.bottom).offset(31)
            $0.height.equalTo(18)
        }

        collaboratorsCollection.delegate = self
        collaboratorsCollection.dataSource = self
        view.addSubview(collaboratorsCollection)
        collaboratorsCollection.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(collaboratorLabel.snp.bottom).offset(8)
            $0.height.equalTo(90)
        }

        view.addSubview(secretLabel)
        secretLabel.snp.makeConstraints {
            $0.leading.equalTo(margin)
            $0.top.equalTo(collaboratorsCollection.snp.bottomMargin).offset(35)
            $0.height.equalTo(18)
        }

        view.addSubview(secretIndicator)
        secretIndicator.snp.makeConstraints {
            $0.leading.equalTo(secretLabel.snp.trailing).offset(4)
            $0.centerY.equalTo(secretLabel.snp.centerY)
        }

        view.addSubview(secretSublabel)
        secretSublabel.snp.makeConstraints {
            $0.leading.equalTo(margin)
            $0.top.equalTo(secretLabel.snp.bottom).offset(2)
            $0.height.equalTo(18)
        }

        secretToggle.addTarget(self, action: #selector(togglePrivacy(_:)), for: .touchUpInside)
        view.addSubview(secretToggle)
        secretToggle.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(17)
            $0.top.equalTo(secretLabel.snp.top)
            $0.width.equalTo(68)
            $0.height.equalTo(38)
        }

        if presentedModally {
            nextButton = NextButton {
                $0.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
                $0.isEnabled = false
                view.addSubview($0)
            }
            nextButton?.snp.makeConstraints {
                $0.bottom.equalToSuperview().offset(-100)
                $0.leading.trailing.equalToSuperview().inset(margin)
                $0.height.equalTo(51)
                $0.centerX.equalToSuperview()
            }

        } else {
            createButton = CreateMapButton {
                $0.addTarget(self, action: #selector(createTapped), for: .touchUpInside)
                $0.isEnabled = false
                view.addSubview($0)
            }
            createButton?.snp.makeConstraints {
                $0.bottom.equalToSuperview().offset(-100)
                $0.leading.trailing.equalToSuperview().inset(margin)
                $0.height.equalTo(51)
                $0.centerX.equalToSuperview()
            }
        }
        view.addGestureRecognizer(keyboardPan)

        let tag = mapObject?.secret ?? false ? 0 : 1
        togglePrivacy(tag: tag)
    }

    func setUpNavBar() {
        title = "Create a map"
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.tintColor = .black
        navigationController?.navigationBar.addWhiteBackground()

        let barButtonItem = UIBarButtonItem(image: UIImage(named: "BackArrowDark"), style: .plain, target: self, action: #selector(backTapped))
        navigationItem.leftBarButtonItem = barButtonItem

        if let mapNav = navigationController as? MapNavigationController {
            mapNav.requiredStatusBarStyle = .darkContent
        }
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

    @objc func togglePrivacy(_ sender: UIButton) {
        HapticGenerator.shared.play(.light)
        togglePrivacy(tag: sender.tag)
    }

    func togglePrivacy(tag: Int) {
        switch tag {
        case 0:
            Mixpanel.mainInstance().track(event: "NewMapPrivateMapOn")
            secretToggle.setImage(UIImage(named: "PrivateMapOn"), for: .normal)
            secretToggle.tag = 1
            secretIndicator.text = "ON"
            secretIndicator.textColor = UIColor(red: 1, green: 0.446, blue: 0.845, alpha: 1)
            mapObject?.secret = true
        case 1:
            Mixpanel.mainInstance().track(event: "NewMapPrivateMapOff")
            secretToggle.setImage(UIImage(named: "PrivateMapOff"), for: .normal)
            secretToggle.tag = 0
            secretIndicator.text = "OFF"
            secretIndicator.textColor = UIColor(red: 0.851, green: 0.851, blue: 0.851, alpha: 1)
            mapObject?.secret = false
        default: return
        }
    }

    func setFinalMapValues() {
        var text = nameField.text ?? ""
        while text.last?.isWhitespace ?? false { text = String(text.dropLast()) }
        mapObject?.mapName = text
        let lowercaseName = text.lowercased()
        mapObject?.lowercaseName = lowercaseName
        mapObject?.searchKeywords = lowercaseName.getKeywordArray()
        mapObject?.coverImage = UploadPostModel.shared.postObject?.postImage.first ?? UIImage()
        if presentedModally { UploadPostModel.shared.postObject?.hideFromFeed = mapObject?.secret ?? false }
    }

    @objc func nextTapped() {
        Mixpanel.mainInstance().track(event: "NewMapNextTap")
        setFinalMapValues()
        UploadPostModel.shared.setMapValues(map: mapObject)
        DispatchQueue.main.async {
            if let vc = self.storyboard?.instantiateViewController(withIdentifier: "AVCameraController") as? AVCameraController {
                vc.newMapMode = true
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    @objc func createTapped() {
        Mixpanel.mainInstance().track(event: "NewMapCreateTap")
        setFinalMapValues()
        guard let mapObject else { return }
        delegate?.finishPassing(map: mapObject)
        DispatchQueue.main.async { self.dismiss(animated: true) }
    }

    @objc func backTapped() {
        // destroy on return to map
        UploadPostModel.shared.destroy()
        DispatchQueue.main.async { self.navigationController?.popViewController(animated: true) }
    }

    @objc func cancelTapped() {
        Mixpanel.mainInstance().track(event: "NewMapCancelTap")
        if let mapVC = navigationController?.viewControllers.first as? MapController { mapVC.uploadMapReset() }
        DispatchQueue.main.async { self.dismiss(animated: true) }
    }

    @objc func keyboardPan(_ sender: UIPanGestureRecognizer) {
        if abs(sender.translation(in: view).y) > abs(sender.translation(in: view).x) {
            nameField.resignFirstResponder()
        }
    }

    @objc func keyboardWillShow(_ notification: NSNotification) {
        animateWithKeyboard(notification: notification) { keyboardFrame in
            self.actionButton.snp.removeConstraints()
            self.actionButton.snp.makeConstraints {
                $0.bottom.equalToSuperview().offset(-keyboardFrame.height - 10)
                $0.leading.trailing.equalToSuperview().inset(self.margin)
                $0.height.equalTo(51)
                $0.centerX.equalToSuperview()
            }
        }
    }

    @objc func keyboardWillHide(_ notification: NSNotification) {
        animateWithKeyboard(notification: notification) { _ in
            self.actionButton.snp.removeConstraints()
            self.actionButton.snp.makeConstraints {
                $0.bottom.equalToSuperview().offset(-60)
                $0.leading.trailing.equalToSuperview().inset(self.margin)
                $0.height.equalTo(51)
                $0.centerX.equalToSuperview()
            }
        }
    }
}

extension NewMapController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        return updatedText.count <= 50
    }

    func textFieldDidChangeSelection(_ textField: UITextField) {
        createButton?.isEnabled = textField.text?.trimmingCharacters(in: .whitespaces).count ?? 0 > 0
        nextButton?.isEnabled = textField.text?.trimmingCharacters(in: .whitespaces).count ?? 0 > 0
     //   textField.attributedText = NSAttributedString(string: textField.text ?? "")
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        keyboardPan.isEnabled = true
        readyToDismiss = false
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        keyboardPan.isEnabled = false
        readyToDismiss = true
    }
}

extension NewMapController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (mapObject?.memberIDs.count ?? 0) + 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MapMemberCell", for: indexPath) as? MapMemberCell else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "Default", for: indexPath)
        }
        if indexPath.row == 0 {
            let user = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: "")
            cell.cellSetUp(user: user)
        } else {
            guard let profile = mapObject?.memberProfiles?[safe: indexPath.row - 1] else { return cell }
            cell.cellSetUp(user: profile)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let friendsList = UserDataModel.shared.userInfo.getSelectedFriends(memberIDs: mapObject?.memberIDs ?? [])
        let vc = FriendsListController(
            allowsSelection: true,
            showsSearchBar: true,
            friendIDs: UserDataModel.shared.userInfo.friendIDs,
            friendsList: friendsList,
            confirmedIDs: UploadPostModel.shared.postObject?.addedUsers ?? []
        )
        
        vc.delegate = self
        present(vc, animated: true)
    }
}

extension NewMapController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        return readyToDismiss
    }
}

extension NewMapController: FriendsListDelegate {
    func finishPassing(selectedUsers: [UserProfile]) {
        var members = selectedUsers
        members.append(UserDataModel.shared.userInfo)
        let memberIDs = members.map({ $0.id ?? "" })
        mapObject?.memberIDs = memberIDs
        mapObject?.likers = memberIDs
        mapObject?.memberProfiles = members
        DispatchQueue.main.async { self.collaboratorsCollection.reloadData() }
    }
}

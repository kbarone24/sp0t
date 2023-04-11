//
//  EditMapController.swift
//  Spot
//
//  Created by Arnold on 7/29/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFirestore
import FirebaseStorage
import Mixpanel
import UIKit
import SDWebImage

class EditMapController: UIViewController {
    private lazy var privacyLevel: UploadPrivacyLevel = .Private
    private var mapData: CustomMap?
    private var mapCoverChanged = false
    private var memberIDsOnOpen: [String] = []

    private let db = Firestore.firestore()
    public unowned var customMapVC: CustomMapController?

    private lazy var editLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SFCompactText-Heavy", size: 19)
        label.text = "Edit map"
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private lazy var backButton: UIButton = {
        let button = UIButton()
        button.setTitle("Cancel", for: .normal)
        button.setTitleColor(UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1), for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Medium", size: 14)
        button.addTarget(self, action: #selector(dismissAction), for: .touchUpInside)
        return button
    }()

    private lazy var doneButton: UIButton = {
        let button = UIButton()
        button.setTitle("Done", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
        button.contentEdgeInsets = UIEdgeInsets(top: 9, left: 18, bottom: 9, right: 18)
        button.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
        button.clipsToBounds = true
        button.layer.cornerRadius = 37 / 2
        button.addTarget(self, action: #selector(saveAction(_:)), for: .touchUpInside)
        return button
    }()

    private lazy var mapCoverImage: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.cornerRadius = 22.85
        imageView.layer.masksToBounds = true
        imageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(mapImageSelectionAction))
        imageView.addGestureRecognizer(tap)
        return imageView
    }()

    private lazy var coverImageButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "EditPencil"), for: .normal)
        button.setTitle("", for: .normal)
        button.addTarget(self, action: #selector(mapImageSelectionAction), for: .touchUpInside)
        return button
    }()

    private lazy var mapNameTextField: UITextField = {
        let view = UITextField()
        view.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        view.attributedPlaceholder = NSAttributedString(string: "Name map...", attributes: [NSAttributedString.Key.foregroundColor: UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 0.6)])
        view.font = UIFont(name: "SFCompactText-Heavy", size: 22)
        view.textAlignment = .center
        view.tintColor = UIColor(named: "SpotGreen")
        view.autocapitalizationType = .sentences
        view.spellCheckingType = .no
        view.delegate = self
        return view
    }()

    private lazy var mapDescription: UITextView = {
        let textView = UITextView()
        textView.delegate = self
        textView.tintColor = .white
        textView.textAlignment = .center
        textView.backgroundColor = nil
        textView.font = UIFont(name: "SFCompactText-Medium", size: 14.5)
        textView.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        textView.isScrollEnabled = false
        textView.textContainer.maximumNumberOfLines = 3
        textView.textContainer.lineBreakMode = .byTruncatingHead
        return textView
    }()

    private lazy var mapTypeLabel: UILabel = {
        let label = UILabel()
        label.text = "Map type"
        label.textColor = UIColor(red: 0.587, green: 0.587, blue: 0.587, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 14)
        return label
    }()
    lazy var mapPrivacySlider = MapPrivacySlider()
    lazy var mapPrivacyView = MapPrivacyView()

    private lazy var collaboratorLabel: UILabel = {
        let label = UILabel()
        label.text = "Add sp0tters"
        label.textColor = UIColor(red: 0.521, green: 0.521, blue: 0.521, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 14)
        return label
    }()

    lazy var collaboratorsCollection: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 18
        layout.itemSize = CGSize(width: 62, height: 84)
        layout.sectionInset = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)

        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = nil
        view.delegate = self
        view.dataSource = self
        view.showsHorizontalScrollIndicator = false
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 100)
        view.register(MapMemberCell.self, forCellWithReuseIdentifier: "MapMemberCell")
        view.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Default")
        return view
    }()

    private var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView()
        indicator.isHidden = true
        return indicator
    }()

    lazy var userService: UserServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.userService)
        return service
    }()

    init(mapData: CustomMap) {
        self.mapData = mapData
        self.memberIDsOnOpen = mapData.memberIDs
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewSetup()
        DispatchQueue.global().async {
            self.getMapMembers()
        }
    }

    @objc func dismissAction() {
        Mixpanel.mainInstance().track(event: "EditMapCancel")
        UIView.animate(withDuration: 0.15) {
            self.backButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { (_) in
            UIView.animate(withDuration: 0.15) {
                self.backButton.transform = .identity
            }
        }
        dismiss(animated: true)
    }

    @objc func mapImageSelectionAction() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.overrideUserInterfaceStyle = .light
        let takePicAction = UIAlertAction(title: "Take picture", style: .default) { _ in
            let picker = UIImagePickerController()
            picker.allowsEditing = true
            picker.delegate = self
            picker.sourceType = .camera
            self.present(picker, animated: true)
        }
        takePicAction.titleTextColor = .black
        let choosePicAction = UIAlertAction(title: "Choose from gallery", style: .default) { _ in
            let picker = UIImagePickerController()
            picker.allowsEditing = true
            picker.delegate = self
            picker.sourceType = .photoLibrary
            self.present(picker, animated: true)
        }
        choosePicAction.titleTextColor = .black
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        cancelAction.titleTextColor = .black
        alertController.addAction(takePicAction)
        alertController.addAction(choosePicAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true)
    }

    @objc func saveAction(_ sender: UIButton) {
        guard let mapID = mapData?.id else { return }
        Mixpanel.mainInstance().track(event: "EditMapSave")

        sender.isEnabled = false
        activityIndicator.startAnimating()

        let mapsRef = db.collection("maps").document(mapID)
        let mapName = mapNameTextField.text ?? ""
        let lowercaseName = mapName.lowercased()
        
        if mapData?.mapName != mapName, let mapPostService = try? ServiceContainer.shared.service(for: \.mapPostService) {
            mapPostService.updateMapNameInPosts(mapID: mapID, newName: mapNameTextField.text ?? "")
        }
        
        mapData?.mapName = mapName
        mapData?.mapDescription = mapDescription.text == "Add a map bio..." ? "" : mapDescription.text
        mapData?.secret = privacyLevel == .Private
        mapData?.communityMap = privacyLevel == .Community
        mapData?.lowercaseName = lowercaseName
        mapData?.searchKeywords = lowercaseName.getKeywordArray()

        guard let mapData = mapData else { return }
        mapsRef.updateData([
            "communityMap": mapData.communityMap ?? false,
            "mapName": mapData.mapName,
            "mapDescription": (mapData.mapDescription ?? "") as Any,
            "secret": mapData.secret,
            "lowercaseName": (mapData.lowercaseName ?? "") as Any,
            "searchKeywords": (mapData.searchKeywords ?? []) as Any,
            "updateUsername": UserDataModel.shared.userInfo.username,
            "memberIDs": mapData.memberIDs,
            "likers": mapData.likers
        ])

        self.updateUserInfo()

        if mapCoverChanged {
            updateMapCover()
        } else {
            activityIndicator.stopAnimating()
            dismiss(animated: true)
        }
    }

    func updateUserInfo() {
        // might be better to send notification to update mapscollection with cover image change
        NotificationCenter.default.post(Notification(name: Notification.Name("EditMap"), object: nil, userInfo: ["map": mapData as Any]))

    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
}

extension EditMapController {
    private func viewSetup() {
        view.backgroundColor = UIColor(named: "SpotBlack")

        view.addSubview(editLabel)
        editLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(55)
            $0.leading.trailing.equalToSuperview()
        }

        view.addSubview(backButton)
        backButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(22)
            $0.top.equalTo(editLabel)
        }

        view.addSubview(doneButton)
        doneButton.snp.makeConstraints {
            $0.centerY.equalTo(editLabel)
            $0.trailing.equalToSuperview().inset(20)
        }

        let transformer = SDImageResizingTransformer(size: CGSize(width: 150, height: 150), scaleMode: .aspectFill)
        mapCoverImage.sd_setImage(
            with: URL(string: mapData?.imageURL ?? ""),
            placeholderImage: UIImage(color: UIColor(named: "BlankImage") ?? .darkGray),
            options: .highPriority,
            context: [.imageTransformer: transformer])
        view.addSubview(mapCoverImage)
        mapCoverImage.snp.makeConstraints {
            $0.width.height.equalTo(107)
            $0.top.equalTo(editLabel.snp.bottom).offset(21)
            $0.centerX.equalToSuperview()
        }

        view.addSubview(coverImageButton)
        coverImageButton.snp.makeConstraints {
            $0.width.height.equalTo(42)
            $0.trailing.equalTo(mapCoverImage).offset(16)
            $0.bottom.equalTo(mapCoverImage).offset(13)
        }

        mapNameTextField.text = mapData?.mapName ?? ""
        view.addSubview(mapNameTextField)
        mapNameTextField.snp.makeConstraints {
            $0.top.equalTo(mapCoverImage.snp.bottom).offset(31)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.height.equalTo(50)
        }

        let bio = mapData?.mapDescription ?? ""
        mapDescription.text = bio == "" ? "Add a map bio..." : bio
        mapDescription.alpha = bio == "" ? 0.6 : 1
        view.addSubview(mapDescription)
        mapDescription.snp.makeConstraints {
            $0.top.equalTo(mapNameTextField.snp.bottom).offset(8)
            $0.leading.trailing.equalToSuperview().inset(29)
            $0.height.equalTo(70)
        }

        view.addSubview(mapTypeLabel)
        mapTypeLabel.snp.makeConstraints {
            $0.leading.equalTo(18)
            $0.top.equalTo(mapDescription.snp.bottomMargin).offset(20)
            $0.height.equalTo(18)
        }

        mapPrivacySlider.delegate = self
        view.addSubview(mapPrivacySlider)
        mapPrivacySlider.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(mapTypeLabel.snp.bottom).offset(8)
            $0.height.equalTo(28)
        }

        view.addSubview(mapPrivacyView)
        mapPrivacyView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(mapPrivacySlider.snp.bottom).offset(12)
            $0.height.equalTo(40)
        }

        let position = (mapData?.secret ?? false) ? 2 : (mapData?.communityMap ?? false) ? 0 : 1
        mapPrivacySlider.setSelected(position: MapPrivacySlider.SliderPosition(rawValue: position) ?? .right)
        mapPrivacyView.set(privacyLevel: UploadPrivacyLevel(rawValue: position) ?? .Private)

        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.top.equalTo(mapNameTextField.snp.bottom).offset(20)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(30)
        }

        view.addSubview(collaboratorLabel)
        collaboratorLabel.snp.makeConstraints {
            $0.leading.equalTo(18)
            $0.top.equalTo(mapPrivacyView.snp.bottom).offset(34)
            $0.height.equalTo(18)
        }

        collaboratorsCollection.delegate = self
        collaboratorsCollection.dataSource = self
        view.addSubview(collaboratorsCollection)
        collaboratorsCollection.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(collaboratorLabel.snp.bottom).offset(8)
            $0.height.equalTo(85)
        }

    }

    private func updateMapCover() {
        let imageId = UUID().uuidString
        let storageRef = Storage.storage().reference().child("spotPics-dev").child("\(imageId)")
        let image = mapCoverImage.image
        guard var imageData = image?.jpegData(compressionQuality: 0.5) else { return }

        if imageData.count > 1_000_000 {
            imageData = image?.jpegData(compressionQuality: 0.3) ?? Data()
        }

        var urlStr: String = ""
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        storageRef.putData(imageData, metadata: metadata) {metadata, error in

            if error == nil, metadata != nil {
                // get download url
                storageRef.downloadURL(completion: { [weak self] url, error in
                    if let error = error {
                        print("\(error.localizedDescription)")
                    }
                    urlStr = (url?.absoluteString) ?? ""
                    guard let self = self else { return }
                    let values = ["imageURL": urlStr]
                    self.db.collection("maps").document(self.mapData?.id ?? "").setData(values, merge: true)
                    self.mapData?.imageURL = urlStr
                    self.updateUserInfo()
                    self.activityIndicator.stopAnimating()
                    self.dismiss(animated: true)
                    return
                })
            } else { print("handle error")}
        }
    }

    private func getMapMembers() {
        Task {
            // fetch profiles for the first four map members
            var memberProfiles: [UserProfile] = []
            for memberID in mapData?.memberIDs ?? [] {
                guard let user = try? await userService?.getUserInfo(userID: memberID) else {
                    continue
                }
                memberProfiles.append(user)
            }

            memberProfiles.sort(by: { $0.id == mapData?.founderID && $1.id != mapData?.founderID })
            mapData?.memberProfiles = memberProfiles
            DispatchQueue.main.async { self.collaboratorsCollection.reloadData() }
        }
    }
}

extension EditMapController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == "Add a map bio..." {
            textView.text = ""
            textView.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
            textView.alpha = 1
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text == "" {
            textView.text = "Add a map bio..."
            textView.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
            textView.alpha = 0.4
        }
    }
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        return textView.shouldChangeText(range: range, replacementText: text, maxChar: 140)
    }
}

extension EditMapController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        return updatedText.count < currentText.count || updatedText.count <= 50
    }
}

extension EditMapController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard let image = info[.editedImage] as? UIImage else { return }
        Mixpanel.mainInstance().track(event: "EditMapEditCoverImage")
        mapCoverImage.image = image
        mapCoverChanged = true
        dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }
}

extension EditMapController: PrivacySliderDelegate {
    func finishPassing(rawPosition: Int) {
        privacyLevel = UploadPrivacyLevel(rawValue: rawPosition) ?? .Private
        mapPrivacyView.set(privacyLevel: privacyLevel)
    }
}

extension EditMapController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (mapData?.memberIDs.count ?? 0) + 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MapMemberCell", for: indexPath) as? MapMemberCell else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "Default", for: indexPath)
        }
        if indexPath.row == 0 {
            let user = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: "")
            cell.cellSetUp(user: user)
        } else {
            guard let profile = mapData?.memberProfiles?[safe: indexPath.row - 1] else { return cell }
            cell.cellSetUp(user: profile)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let friendsList = UserDataModel.shared.userInfo.getSelectedFriends(memberIDs: mapData?.memberIDs ?? [])
        let vc = FriendsListController(
            parentVC: .mapAdd,
            allowsSelection: true,
            showsSearchBar: true,
            canAddFriends: false,
            friendIDs: UserDataModel.shared.userInfo.friendIDs,
            friendsList: friendsList,
            confirmedIDs: memberIDsOnOpen
        )
        vc.delegate = self
        present(vc, animated: true)
    }

}

extension EditMapController: FriendsListDelegate {
    func finishPassing(openProfile: UserProfile) {
        return
    }

    func finishPassing(selectedUsers: [UserProfile]) {
        var members = selectedUsers
        members.append(UserDataModel.shared.userInfo)
        let memberIDs = members.map({ $0.id ?? "" })
        mapData?.memberIDs = memberIDs
        mapData?.likers = memberIDs
        mapData?.memberProfiles = members
        DispatchQueue.main.async { self.collaboratorsCollection.reloadData() }
    }
}

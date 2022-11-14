//
//  EditMapController.swift
//  Spot
//
//  Created by Arnold on 7/29/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseUI
import Mixpanel
import UIKit

class EditMapController: UIViewController {
    private var mapData: CustomMap?
    private var mapCoverChanged = false
    private var memberList: [UserProfile] = []

    private let db = Firestore.firestore()
    public unowned var customMapVC: CustomMapController?

    private lazy var editLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
        label.text = "Edit map"
        label.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
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
        return imageView
    }()

    private lazy var coverImageButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "EditProfilePicture"), for: .normal)
        button.setTitle("", for: .normal)
        button.addTarget(self, action: #selector(mapImageSelectionAction), for: .touchUpInside)
        return button
    }()

    private lazy var mapNameTextField: UITextField = {
        let textField = UITextField()
        textField.font = UIFont(name: "SFCompactText-Bold", size: 21)
        textField.textColor = .black
        textField.delegate = self
        textField.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
        textField.layer.cornerRadius = 5
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor(red: 0.929, green: 0.929, blue: 0.929, alpha: 1).cgColor
        textField.textAlignment = .center
        return textField
    }()

    private lazy var mapDescription: UITextView = {
        let textView = UITextView()
        textView.delegate = self
        textView.textAlignment = .center
        textView.backgroundColor = .white
        textView.font = UIFont(name: "SFCompactText-Medium", size: 14.5)
        textView.textColor = UIColor(red: 0.292, green: 0.292, blue: 0.292, alpha: 1)
        textView.isScrollEnabled = false
        textView.textContainer.maximumNumberOfLines = 3
        textView.textContainer.lineBreakMode = .byTruncatingHead
        return textView
    }()

    private lazy var privateLabel: UILabel = {
        let label = UILabel()
        label.text = "Make this map secret"
        label.font = UIFont(name: "SFCompactText-Bold", size: 14)
        label.textColor = UIColor(red: 0.521, green: 0.521, blue: 0.521, alpha: 1)
        return label
    }()

    private lazy var privateDescriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "Only invited friends will see this map"
        label.textColor = UIColor(red: 0.658, green: 0.658, blue: 0.658, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 12.5)
        return label
    }()

    private var privateButton: UIButton = {
        let button = UIButton()
        button.setTitle("", for: .normal)
        return button
    }()

    private var activityIndicator: CustomActivityIndicator = {
        let indicator = CustomActivityIndicator()
        indicator.isHidden = true
        return indicator
    }()

    init(mapData: CustomMap) {
        self.mapData = mapData
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewSetup()
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
        if mapData?.mapName != mapName { updateMapNameInPosts(mapID: mapID, newName: mapNameTextField.text ?? "") }
        mapData?.mapName = mapName
        mapData?.mapDescription = mapDescription.text == "Add a map bio..." ? "" : mapDescription.text
        mapData?.secret = privateButton.image(for: .normal) == UIImage(named: "PrivateMapOff") ? false : true
        mapData?.lowercaseName = lowercaseName
        mapData?.searchKeywords = lowercaseName.getKeywordArray()

        guard let mapData = mapData else { return }
        mapsRef.updateData([
            "mapName": mapData.mapName,
            "mapDescription": (mapData.mapDescription ?? "") as Any,
            "secret": mapData.secret,
            "lowercaseName": (mapData.lowercaseName ?? "") as Any,
            "searchKeywords": (mapData.searchKeywords ?? []) as Any,
            "updateUsername": UserDataModel.shared.userInfo.username
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

    @objc func privateMapSwitchAction() {
        HapticGenerator.shared.play(.light)
        privateButton.setImage(UIImage(named: privateButton.image(for: .normal) == UIImage(named: "PrivateMapOff") ? "PrivateMapOn" : "PrivateMapOff"), for: .normal)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
}

extension EditMapController {
    private func viewSetup() {
        view.backgroundColor = .white

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
            placeholderImage: UIImage(color: UIColor(named: "BlankImage") ?? .white),
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
            $0.top.equalTo(mapNameTextField.snp.bottom).offset(21)
            $0.leading.trailing.equalToSuperview().inset(29)
            $0.height.equalTo(70)
        }

        view.addSubview(privateLabel)
        privateLabel.snp.makeConstraints {
            $0.top.equalTo(mapDescription.snp.bottom).offset(33)
            $0.leading.equalTo(16)
        }

        privateButton.setImage(UIImage(named: mapData?.secret == false ? "PrivateMapOff" : "PrivateMapOn"), for: .normal)
        privateButton.addTarget(self, action: #selector(privateMapSwitchAction), for: .touchUpInside)
        view.addSubview(privateButton)
        privateButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(17)
            $0.top.equalTo(privateLabel)
            $0.width.equalTo(68)
            $0.height.equalTo(38)
        }

        view.addSubview(privateDescriptionLabel)
        privateDescriptionLabel.snp.makeConstraints {
            $0.top.equalTo(privateLabel.snp.bottom).offset(1)
            $0.leading.equalTo(privateLabel)
            $0.trailing.equalTo(privateButton.snp.leading).offset(-14)
        }

        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.top.equalTo(mapNameTextField.snp.bottom).offset(20)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(30)
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
}

extension EditMapController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == "Add a map bio..." {
            textView.text = ""
            textView.textColor = UIColor(red: 0.292, green: 0.292, blue: 0.292, alpha: 1)
            textView.alpha = 1
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text == "" {
            textView.text = "Add a map bio..."
            textView.textColor = UIColor(red: 165 / 255, green: 165 / 255, blue: 165 / 255, alpha: 1)
            textView.alpha = 0.4
        }
    }
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let currentText = textView.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: text)
        return updatedText.count < textView.text.count || updatedText.count <= 140
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

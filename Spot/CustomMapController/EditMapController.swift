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
    private var editLabel: UILabel!
    private var backButton: UIButton!
    private var doneButton: UIButton!
    private var mapCoverImage: UIImageView!
    private var mapCoverImageSelectionButton: UIButton!
    private var mapNameTextField: UITextField!
    private var locationTextfield: UITextField!
    private var mapDescription: UITextView!
    private var privateLabel: UILabel!
    private var privateDescriptionLabel: UILabel!
    private var privateButton: UIButton!
    private var activityIndicator: CustomActivityIndicator!

    private var mapData: CustomMap?
    private var mapCoverChanged = false
    private var memberList: [UserProfile] = []

    private let db = Firestore.firestore()
    public unowned var customMapVC: CustomMapController?

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
        Mixpanel.mainInstance().track(event: "EditMapSave")
        sender.isEnabled = false
        activityIndicator.startAnimating()
        let mapsRef = db.collection("maps").document(mapData!.id!)

        if mapData!.mapName != mapNameTextField.text! { updateMapNameInPosts(mapID: mapData!.id!, newName: mapNameTextField.text!) }
        mapData!.mapName = mapNameTextField.text!
        mapData!.mapDescription = mapDescription.text == "Add a map bio..." ? "" : mapDescription.text
        mapData!.secret = privateButton.image(for: .normal) == UIImage(named: "PrivateMapOff") ? false : true
        mapData!.lowercaseName = mapData!.mapName.lowercased()
        mapData!.searchKeywords = mapData!.lowercaseName!.getKeywordArray()

        mapsRef.updateData(["mapName": mapNameTextField.text!, "mapDescription": mapData!.mapDescription!, "secret": mapData!.secret, "lowercaseName": mapData!.lowercaseName!, "searchKeywords": mapData!.searchKeywords!, "updateUserID": UserDataModel.shared.uid, "updateUsername": UserDataModel.shared.userInfo.username])

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

        editLabel = UILabel {
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
            $0.text = "Edit map"
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            $0.textAlignment = .center
            view.addSubview($0)
        }
        editLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(55)
            $0.leading.trailing.equalToSuperview()
        }

        backButton = UIButton {
            $0.setTitle("Cancel", for: .normal)
            $0.setTitleColor(UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1), for: .normal)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Medium", size: 14)
            $0.addTarget(self, action: #selector(dismissAction), for: .touchUpInside)
            view.addSubview($0)
        }
        backButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(22)
            $0.top.equalTo(editLabel)
        }

        doneButton = UIButton {
            $0.setTitle("Done", for: .normal)
            $0.setTitleColor(.black, for: .normal)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
            $0.contentEdgeInsets = UIEdgeInsets(top: 9, left: 18, bottom: 9, right: 18)
            $0.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            $0.clipsToBounds = true
            $0.layer.cornerRadius = 37 / 2
            $0.addTarget(self, action: #selector(saveAction(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        doneButton.snp.makeConstraints {
            $0.centerY.equalTo(editLabel)
            $0.trailing.equalToSuperview().inset(20)
        }

        mapCoverImage = UIImageView {
            $0.layer.cornerRadius = 22.85
            $0.layer.masksToBounds = true
            let transformer = SDImageResizingTransformer(size: CGSize(width: 150, height: 150), scaleMode: .aspectFill)
            $0.sd_setImage(with: URL(string: mapData!.imageURL), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
            view.addSubview($0)
        }
        mapCoverImage.snp.makeConstraints {
            $0.width.height.equalTo(107)
            $0.top.equalTo(editLabel.snp.bottom).offset(21)
            $0.centerX.equalToSuperview()
        }

        mapCoverImageSelectionButton = UIButton {
            $0.setImage(UIImage(named: "EditProfilePicture"), for: .normal)
            $0.setTitle("", for: .normal)
            $0.addTarget(self, action: #selector(mapImageSelectionAction), for: .touchUpInside)
            view.addSubview($0)
        }
        mapCoverImageSelectionButton.snp.makeConstraints {
            $0.width.height.equalTo(42)
            $0.trailing.equalTo(mapCoverImage).offset(16)
            $0.bottom.equalTo(mapCoverImage).offset(13)
        }

        mapNameTextField = UITextField {
            $0.text = mapData!.mapName
            $0.font = UIFont(name: "SFCompactText-Bold", size: 21)
            $0.textColor = .black
            $0.delegate = self
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            $0.layer.cornerRadius = 5
            $0.layer.borderWidth = 1
            $0.layer.borderColor = UIColor(red: 0.929, green: 0.929, blue: 0.929, alpha: 1).cgColor
            $0.textAlignment = .center
            view.addSubview($0)
        }
        mapNameTextField.snp.makeConstraints {
            $0.top.equalTo(mapCoverImage.snp.bottom).offset(31)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.height.equalTo(50)
        }

        mapDescription = UITextView {
            $0.text = (mapData!.mapDescription == "" || mapData!.mapDescription == nil) ? "Add a map bio..." : mapData!.mapDescription
            $0.delegate = self
            $0.textAlignment = .center
            $0.backgroundColor = .white
            $0.font = UIFont(name: "SFCompactText-Medium", size: 14.5)
            $0.textColor = UIColor(red: 0.292, green: 0.292, blue: 0.292, alpha: 1)
            $0.alpha = (mapData!.mapDescription == "" || mapData!.mapDescription == nil) ? 0.6 : 1
            $0.isScrollEnabled = false
            $0.textContainer.maximumNumberOfLines = 3
            $0.textContainer.lineBreakMode = .byTruncatingHead
            view.addSubview($0)
        }
        mapDescription.snp.makeConstraints {
            $0.top.equalTo(mapNameTextField.snp.bottom).offset(21)
            $0.leading.trailing.equalToSuperview().inset(29)
            $0.height.equalTo(70)
        }

        privateLabel = UILabel {
            $0.text = "Make this map secret"
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.textColor = UIColor(red: 0.521, green: 0.521, blue: 0.521, alpha: 1)
            view.addSubview($0)
        }
        privateLabel.snp.makeConstraints {
            $0.top.equalTo(mapDescription.snp.bottom).offset(33)
            $0.leading.equalTo(16)
        }

        privateButton = UIButton {
            $0.setTitle("", for: .normal)
            $0.setImage(UIImage(named: mapData?.secret == false ? "PrivateMapOff" : "PrivateMapOn"), for: .normal)
            $0.addTarget(self, action: #selector(privateMapSwitchAction), for: .touchUpInside)
            view.addSubview($0)
        }
        privateButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(17)
            $0.top.equalTo(privateLabel)
            $0.width.equalTo(68)
            $0.height.equalTo(38)
        }

        privateDescriptionLabel = UILabel {
            $0.text = "Only invited friends will see this map"
            $0.textColor = UIColor(red: 0.658, green: 0.658, blue: 0.658, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 12.5)
            view.addSubview($0)
        }
        privateDescriptionLabel.snp.makeConstraints {
            $0.top.equalTo(privateLabel.snp.bottom).offset(1)
            $0.leading.equalTo(privateLabel)
            $0.trailing.equalTo(privateButton.snp.leading).offset(-14)
        }

        activityIndicator = CustomActivityIndicator {
            $0.isHidden = true
            view.addSubview($0)
        }
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
        guard var imageData = image!.jpegData(compressionQuality: 0.5) else {return}

        if imageData.count > 1_000_000 {
            imageData = image!.jpegData(compressionQuality: 0.3)!
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
                    urlStr = (url?.absoluteString)!
                    guard let self = self else { return }
                    let values = ["imageURL": urlStr]
                    self.db.collection("maps").document(self.mapData!.id!).setData(values, merge: true)
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

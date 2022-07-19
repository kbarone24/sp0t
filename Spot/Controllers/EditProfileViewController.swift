//
//  EditProfileViewController.swift
//  Spot
//
//  Created by Arnold on 7/8/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import Firebase
import FirebaseFunctions

class EditProfileViewController: UIViewController {
    
    private var editLabel: UILabel!
    private var backButton: UIButton!
    private var doneButton: UIButton!
    private var profileImage: UIImageView!
    private var profilePicSelectionButton: UIButton!
    private var avatarLabel: UILabel!
    private var avatarImage: UIImageView!
    private var avatarEditButton: UIButton!
    private var nameLabel: UILabel!
    private var nameTextfield: UITextField!
    private var locationLabel: UILabel!
    private var locationTextfield: UITextField!
    private var logoutButton: UIButton!
    
    private var nameChanged: Bool = false
    private var locationChanged: Bool = false
    private var profileChanged: Bool = false
    
    public var profileVC: ProfileViewController?
    private var userProfile: UserProfile?
    private let db = Firestore.firestore()
    
    init(userProfile: UserProfile? = nil) {
        self.userProfile = userProfile == nil ? UserDataModel.shared.userInfo : userProfile
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
        UIView.animate(withDuration: 0.15) {
            self.backButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { (Bool) in
            UIView.animate(withDuration: 0.15) {
                self.backButton.transform = .identity
            }
        }
        dismiss(animated: true)
    }
    
    @objc func profilePicSelectionAction() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let takePicAction = UIAlertAction(title: "Take picture", style: .default) { takePic in
            let picker = UIImagePickerController()
            picker.allowsEditing = true
            picker.delegate = self
            picker.sourceType = .camera
            self.present(picker, animated: true)
        }
        takePicAction.titleTextColor = .black
        let choosePicAction = UIAlertAction(title: "Choose from gallery", style: .default) { choosePic in
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
    
    @objc func avatarEditAction() {
        
    }
    
    @objc func saveAction() {
        let userRef = db.collection("users").document(userProfile!.id!)
        do {
            if nameChanged {
                userProfile?.name = nameTextfield.text!
            }
            if locationChanged {
                userProfile?.currentLocation = locationTextfield.text!
            }
            try userRef.setData(from: userProfile, merge: true)

            profileChanged ? updateProfileImage() : self.dismiss(animated: true)
        } catch {
            //handle error
        }
    }
    
    func updateProfileImage(){
        let imageId = UUID().uuidString
        let storageRef = Storage.storage().reference().child("spotPics-dev").child("\(imageId)")
        let image = profileImage.image
        guard var imageData = image!.jpegData(compressionQuality: 0.5) else {return}
        
        if imageData.count > 1000000 {
            imageData = image!.jpegData(compressionQuality: 0.3)!
        }
        
        var urlStr: String = ""
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        storageRef.putData(imageData, metadata: metadata){metadata, error in
            
            if error == nil, metadata != nil {
                //get download url
                storageRef.downloadURL(completion: { [weak self] url, error in
                    if let error = error{
                        print("\(error.localizedDescription)")
                    }
                    
                    urlStr = (url?.absoluteString)!
                    guard let self = self else { return }
                    
                    let values = ["imageURL": urlStr]
                    self.db.collection("users").document(self.userProfile!.id!).setData(values, merge: true)
                    self.dismiss(animated: true) {
                        self.profileVC?.userProfile = UserDataModel.shared.userInfo
                    }
                    return
                })
            } else { print("handle error")}
        }
    }
    
    @objc func logoutAction() {
        self.dismiss(animated: false, completion: {
            self.profileVC?.containerDrawerView?.closeAction()
            UserDataModel.shared.destroy()
            self.present(LandingPageController(), animated: true)
        })
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        if textField == nameTextfield {
            nameChanged = true
        }
        
        if textField == locationTextfield {
            locationChanged = true
        }
    }
    
}

extension EditProfileViewController {
    private func viewSetup() {
        view.backgroundColor = .white
        
        editLabel = UILabel {
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
            $0.text = "Edit profile"
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
            $0.addTarget(self, action: #selector(saveAction), for: .touchUpInside)
            view.addSubview($0)
        }
        doneButton.snp.makeConstraints {
            $0.centerY.equalTo(editLabel)
            $0.trailing.equalToSuperview().inset(20)
        }
        
        profileImage = UIImageView {
            $0.layer.cornerRadius = 51.5
            $0.layer.masksToBounds = true
            $0.sd_setImage(with: URL(string: userProfile!.imageURL))
            view.addSubview($0)
        }
        profileImage.snp.makeConstraints {
            $0.width.height.equalTo(103)
            $0.top.equalTo(editLabel.snp.bottom).offset(21)
            $0.centerX.equalToSuperview()
        }
        
        profilePicSelectionButton = UIButton {
            $0.setImage(UIImage(named: "EditProfilePicture"), for: .normal)
            $0.setTitle("", for: .normal)
            $0.addTarget(self, action: #selector(profilePicSelectionAction), for: .touchUpInside)
            view.addSubview($0)
        }
        profilePicSelectionButton.snp.makeConstraints {
            $0.width.height.equalTo(42)
            $0.trailing.equalTo(profileImage).offset(5)
            $0.bottom.equalTo(profileImage).offset(3)
        }
        
        avatarLabel = UILabel {
            $0.text = "Avatar"
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            view.addSubview($0)
        }
        avatarLabel.snp.makeConstraints {
            $0.top.equalTo(profileImage.snp.bottom).offset(6)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
        
        avatarImage = UIImageView {
            $0.contentMode = .scaleAspectFit
            view.addSubview($0)
        }
        avatarImage.sd_setImage(with: URL(string: userProfile!.avatarURL!)) { image, Error, cache, url  in
            self.avatarImage.image = image?.withHorizontallyFlippedOrientation()
        }
        avatarImage.snp.makeConstraints {
            $0.top.equalTo(avatarLabel.snp.bottom).offset(2)
            $0.leading.equalToSuperview().offset(16)
            $0.width.equalTo(43)
            $0.height.equalTo(56.5)
        }
        
        avatarEditButton = UIButton {
            $0.setImage(UIImage(named: "EditAvatar"), for: .normal)
            $0.setTitle("", for: .normal)
            $0.addTarget(self, action: #selector(avatarEditAction), for: .touchUpInside)
            view.addSubview($0)
        }
        avatarEditButton.snp.makeConstraints {
            $0.leading.equalTo(avatarImage.snp.trailing).offset(1)
            $0.centerY.equalTo(avatarImage)
            $0.width.height.equalTo(22)
        }
        
        nameLabel = UILabel {
            $0.text = "Name"
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            view.addSubview($0)
        }
        nameLabel.snp.makeConstraints {
            $0.top.equalTo(avatarImage.snp.bottom).offset(18.56)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
        
        nameTextfield = UITextField {
            $0.text = userProfile!.name
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            $0.layer.cornerRadius = 11
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 16)
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            $0.tintColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            $0.setLeftPaddingPoints(8)
            $0.setRightPaddingPoints(8)
            $0.addTarget(self, action: #selector(EditProfileViewController.textFieldDidChange(_:)), for: .editingChanged)
            view.addSubview($0)
        }
        nameTextfield.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(1)
            $0.leading.equalToSuperview().offset(14)
            $0.trailing.equalToSuperview().inset(63)
            $0.height.equalTo(36)
        }
        
        locationLabel = UILabel {
            $0.text = "Location"
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            view.addSubview($0)
        }
        locationLabel.snp.makeConstraints {
            $0.top.equalTo(nameTextfield.snp.bottom).offset(18)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
        
        locationTextfield = UITextField {
            $0.text = userProfile!.currentLocation
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            $0.layer.cornerRadius = 11
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 16)
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            $0.tintColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            $0.setLeftPaddingPoints(8)
            $0.setRightPaddingPoints(8)
            $0.addTarget(self, action: #selector(EditProfileViewController.textFieldDidChange(_:)), for: .editingChanged)
            view.addSubview($0)
        }
        locationTextfield.snp.makeConstraints {
            $0.top.equalTo(locationLabel.snp.bottom).offset(1)
            $0.leading.equalToSuperview().offset(14)
            $0.trailing.equalToSuperview().inset(63)
            $0.height.equalTo(36)
        }
        
        logoutButton = UIButton {
            $0.setTitle("Log out", for: .normal)
            $0.setTitleColor(UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1), for: .normal)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 17.5)
            $0.addTarget(self, action: #selector(logoutAction), for: .touchUpInside)
            view.addSubview($0)
        }
        logoutButton.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(73)
            $0.centerX.equalToSuperview()
        }
    }
}

extension EditProfileViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.editedImage] as? UIImage else { return }
        profileImage.image = image
        profileChanged = true
        dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }
}

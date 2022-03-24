//
//  EditProfileViewController.swift
//  Spot
//
//  Created by kbarone on 4/17/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import UIKit
import Firebase
import Photos
import RSKImageCropper
import Mixpanel

class EditProfileViewController: UIViewController {
    /*
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    let db = Firestore.firestore()
    
    unowned var profileVC: ProfileViewController!
    var usernameText = ""
    
    var newProfilePic: UIImage!
    var newName, newUsername, newCity, newBio: String! /// use separate values for changed fields to avoid mixing up with original profile values
    
    var imageView: UIImageView!
    var statusIcon: UIImageView!
    var nameField, usernameField, cityField: UITextField!
    
    var editBio = false
    var bioContainer: UIView!
    var bioView: UITextView!
    var line4: UIView!
    
    var errorBox: UIView!
    var errorLabel: UILabel!
    var saveButton: UIButton!
    
    var usernameIndicator: CustomActivityIndicator!
    var loadingIndicator: CustomActivityIndicator!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addHeader()
        addImageView()
        addTextViews()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(false)
        Mixpanel.mainInstance().track(event: "EditProfileOpen")
    }
    
    func addHeader() {
        
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 40))
        headerView.backgroundColor = nil
        view.addSubview(headerView)
        
        let titleLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 60, y: 11, width: 120, height: 22))
        titleLabel.text = "Edit Profile"
        titleLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        titleLabel.font = UIFont(name: "SFCompactText-Regular", size: 18)
        titleLabel.textAlignment = .center
        headerView.addSubview(titleLabel)
        
        let cancelButton = UIButton(frame: CGRect(x: 12, y: 10, width: 60, height: 26))
        cancelButton.titleEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1), for: .normal)
        cancelButton.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 12.5)
        cancelButton.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
        headerView.addSubview(cancelButton)
        
        saveButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 66, y: 7, width: 62, height: 30))
        saveButton.titleEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        saveButton.setTitle("Save", for: .normal)
        saveButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        saveButton.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 14)
        saveButton.addTarget(self, action: #selector(saveTap(_:)), for: .touchUpInside)
        headerView.addSubview(saveButton)
    }
    
    func addImageView() {
        
        let imageContainer = UIView(frame: CGRect(x: 0, y: 60, width: UIScreen.main.bounds.width, height: 150))
        imageContainer.backgroundColor = nil
        view.addSubview(imageContainer)
                
        imageView = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 58, y: 0, width: 116, height: 116))
        imageView.image = profileVC.userInfo.profilePic
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = imageView.frame.width/2
        imageContainer.addSubview(imageView)
        
        let gradient = CAGradientLayer()
        gradient.frame = imageView.bounds
        gradient.colors = [
          UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
          UIColor(red: 0, green: 0, blue: 0, alpha: 0.81).cgColor
        ]
        gradient.locations = [0, 1]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        imageView.layer.addSublayer(gradient)
        
        let changeLabel = UILabel(frame: CGRect(x: 0, y: imageView.bounds.maxY - 33, width: imageView.bounds.width, height: 18))
        changeLabel.text = "Change"
        changeLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        changeLabel.font = UIFont(name: "SFCompactText-Semibold", size: 12)
        changeLabel.textAlignment = .center
        imageView.addSubview(changeLabel)
        
        let imageButton = UIButton(frame: CGRect(x: imageView.frame.minX - 10, y: imageView.frame.minY - 10, width: imageView.frame.width + 20, height: imageView.frame.height + 20))
        imageButton.backgroundColor = nil
        imageButton.addTarget(self, action: #selector(openCamera(_:)), for: .touchUpInside)
        imageContainer.addSubview(imageButton)
    }
    
    func addTextViews() {
        /// add name fields
        let nameContainer = UIView(frame: CGRect(x: 0, y: 210, width: UIScreen.main.bounds.width, height: 55))
        nameContainer.backgroundColor = nil
        view.addSubview(nameContainer)
                
        let nameLabel = UILabel(frame: CGRect(x: 14, y: 0, width: 60, height: 12))
        nameLabel.text = "Name"
        nameLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        nameLabel.font = UIFont(name: "SFCompactText-Semibold", size: 12)
        nameContainer.addSubview(nameLabel)
        
        nameField = UITextField(frame: CGRect(x: 14, y: nameLabel.frame.maxY + 3, width: UIScreen.main.bounds.width - 28, height: 28))
        nameField.backgroundColor = nil
        nameField.tag = 0
        nameField.autocapitalizationType = .words
        nameField.autocorrectionType = .no
        nameField.text = profileVC.userInfo.name
        nameField.font = UIFont(name: "SFCompactText-Regular", size: 17)
        nameField.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        nameContainer.addSubview(nameField)
        
        let line1 = UIView(frame: CGRect(x: 0, y: 53.5, width: UIScreen.main.bounds.width, height: 1.5))
        line1.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
        nameContainer.addSubview(line1)

        /// add username fields
        let usernameContainer = UIView(frame: CGRect(x: 0, y: nameContainer.frame.maxY, width: UIScreen.main.bounds.width, height: 70))
        usernameContainer.backgroundColor = nil
        view.addSubview(usernameContainer)
                
        let usernameLabel = UILabel(frame: CGRect(x: 14, y: 16.5, width: 65, height: 12))
        usernameLabel.text = "Username"
        usernameLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        usernameLabel.font = UIFont(name: "SFCompactText-Semibold", size: 12)
        usernameContainer.addSubview(usernameLabel)
                
        let atLabel = UILabel(frame: CGRect(x: 14, y: usernameLabel.frame.maxY + 10, width: 18, height: 16))
        atLabel.text = "@"
        atLabel.textColor =  UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        atLabel.font = UIFont(name: "SFCompactText-Regular", size: 17)
        usernameContainer.addSubview(atLabel)
        
        usernameField = UITextField(frame: CGRect(x: atLabel.frame.maxX, y: usernameLabel.frame.maxY + 7, width: UIScreen.main.bounds.width - 102, height: 22))
        usernameField.backgroundColor = nil
        usernameField.tag = 1
        usernameField.autocorrectionType = .no
        usernameField.autocapitalizationType = .none
        usernameField.delegate = self
        usernameField.text = profileVC.userInfo.username
        usernameField.font = UIFont(name: "SFCompactText-Regular", size: 17)
        usernameField.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        usernameField.addTarget(self, action: #selector(usernameChanged(_:)), for: .editingChanged)
        usernameContainer.addSubview(usernameField)
        
        statusIcon = UIImageView(frame: CGRect(x: usernameField.frame.maxX + 10, y: usernameField.frame.minY + 1, width: 20, height: 20))
        statusIcon.image = UIImage()
        usernameContainer.addSubview(statusIcon)
                
        let line2 = UIView(frame: CGRect(x: 0, y: 68.5, width: UIScreen.main.bounds.width, height: 1.5))
        line2.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
        usernameContainer.addSubview(line2)

        /// add city fields
        
        let cityContainer = UIView(frame: CGRect(x: 0, y: usernameContainer.frame.maxY, width: UIScreen.main.bounds.width, height: 70))
        cityContainer.backgroundColor = nil
        view.addSubview(cityContainer)
                
        let cityLabel = UILabel(frame: CGRect(x: 14, y: 16.5, width: 65, height: 12))
        cityLabel.text = "Home city"
        cityLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        cityLabel.font = UIFont(name: "SFCompactText-Semibold", size: 12)
        cityContainer.addSubview(cityLabel)
        
        let cityIcon = UIImageView(frame: CGRect(x: 14, y: cityLabel.frame.maxY + 9, width: 12.14, height: 16.35))
        cityIcon.image = UIImage(named: "ProfileCityIcon")
        cityContainer.addSubview(cityIcon)

        cityField = UITextField(frame: CGRect(x: cityIcon.frame.maxX + 6, y: cityLabel.frame.maxY + 7, width: UIScreen.main.bounds.width - 102, height: 22))
        cityField.tag = 2
        cityField.delegate = self
        cityField.text = profileVC.userInfo.currentLocation
        cityField.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        cityField.font = UIFont(name: "SFCompactText-Regular", size: 17)
        cityField.backgroundColor = nil
        cityContainer.addSubview(cityField)
        
        let line3 = UIView(frame: CGRect(x: 0, y: 68.5, width: UIScreen.main.bounds.width, height: 1.5))
        line3.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
        cityContainer.addSubview(line3)
        
        bioContainer = UIView(frame: CGRect(x: 0, y: cityContainer.frame.maxY, width: UIScreen.main.bounds.width, height: 70))
        bioContainer.backgroundColor = nil
        view.addSubview(bioContainer)
                
        let bioLabel = UILabel(frame: CGRect(x: 14, y: 16.5, width: 65, height: 12))
        bioLabel.text = "Bio"
        bioLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        bioLabel.font = UIFont(name: "SFCompactText-Semibold", size: 12)
        bioContainer.addSubview(bioLabel)
        
        bioView = UITextView(frame: CGRect(x: 10, y: bioLabel.frame.maxY + 3, width: UIScreen.main.bounds.width - 28, height: 28))
        bioView.backgroundColor = nil
        bioView.delegate = self
        bioView.isScrollEnabled = false
        bioView.text = profileVC.userInfo.userBio == " " ? "" : profileVC.userInfo.userBio
        bioView.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        bioView.font = UIFont(name: "SFCompactText-Regular", size: 17)
        bioView.keyboardDistanceFromTextField = 60
        bioContainer.addSubview(bioView)
        
        if editBio { bioView.becomeFirstResponder() }
                
        line4 = UIView(frame: CGRect(x: 0, y: 48.5, width: UIScreen.main.bounds.width, height: 1.5))
        line4.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
        bioContainer.addSubview(line4)
        
        resizeTextView()
        
        /// add error box
        errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 150, width: UIScreen.main.bounds.width, height: 32))
        errorBox.backgroundColor = UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1)
        view.addSubview(errorBox)
        errorBox.isHidden = true
        
        //Load error text
        errorLabel = UILabel(frame: CGRect(x: 0, y: 6, width: UIScreen.main.bounds.width, height: 18))
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.numberOfLines = 0
        errorLabel.textColor = UIColor.white
        errorLabel.textAlignment = .center
        errorLabel.text = "this is a generic placeholder error message"
        errorLabel.font = UIFont(name: "SFCompactText-Regular", size: 14)!
        errorBox.addSubview(errorLabel)
        errorLabel.isHidden = true
        
        usernameIndicator = CustomActivityIndicator(frame: CGRect(x: UIScreen.main.bounds.width/2 - 29, y: 149, width: 20, height: 20))
        usernameIndicator.isHidden = true
        view.addSubview(usernameIndicator)

        loadingIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 250, width: UIScreen.main.bounds.width, height: 30))
        loadingIndicator.isHidden = true
        view.addSubview(loadingIndicator)
        
        setAvailable()
    }
    
    func setAvailable() {
        usernameIndicator.stopAnimating()
        statusIcon.image = UIImage(named: "UsernameAvailable")
        saveButton.alpha = 1.0
    }
    
    func setUnavailable() {
        usernameIndicator.stopAnimating()
        statusIcon.image = UIImage(named: "UsernameTaken")
        saveButton.alpha = 0.65
    }
    
    func setEmpty() {
        usernameIndicator.stopAnimating()
        statusIcon.image = UIImage()
        saveButton.alpha = 0.65
    }

    
    @objc func cancelTap(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func saveTap(_ sender: UIButton) {
        
        newName = nameField.text ?? ""
        newCity = cityField.text ?? ""
        newBio = bioView.text ?? ""
        if newBio == "" { newBio = " " }
                
        sender.isEnabled = false
        loadingIndicator.startAnimating()

        guard var username = usernameField.text?.lowercased() else { return }
        username = username.trimmingCharacters(in: .whitespaces)
        if username == profileVC.userInfo.username { updateUserInfo(); return }
        
        usernameAvailable(username: username) { [weak self] (errorMessage) in
            guard let self = self else { return }
            
            if errorMessage != "" {
                self.errorBox.isHidden = false
                self.errorLabel.isHidden = false
                self.errorLabel.text = errorMessage
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    guard let self = self else { return }
                    self.errorLabel.isHidden = true
                    self.errorBox.isHidden = true
                }
                
            } else {
                
                Mixpanel.mainInstance().track(event: "EditProfileSave")
                
                let oldUsername = self.profileVC.userInfo.username
                
                DispatchQueue.global(qos: .utility).async {
                    self.removeFromUsernames(username: oldUsername)
                    self.updateUserTags(oldUsername: oldUsername, newUsername: username)
                }
                
                self.newUsername = username
                
                let usernameID = UUID().uuidString
                self.db.collection("usernames").document(usernameID).setData(["username" : username])
                self.updateUserInfo()
            }
        }
    }
    
    @objc func usernameChanged(_ sender: UITextField) {
        
        setEmpty()

        var lowercaseUsername = sender.text?.lowercased() ?? ""
        lowercaseUsername = lowercaseUsername.trimmingCharacters(in: .whitespaces)

        usernameText = lowercaseUsername
        if usernameText == "" { return }

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(runUsernameQuery), object: nil)
        perform(#selector(runUsernameQuery), with: nil, afterDelay: 0.4)
    }
    
    @objc func backTapped(_ sender: UIButton){
        navigationController?.popViewController(animated: true)
    }
        
    @objc func runUsernameQuery() {
        
        let localUsername = usernameText
        setEmpty()
        usernameIndicator.startAnimating()
        
        usernameAvailable(username: localUsername) { [weak self] (errorMessage) in
            
            guard let self = self else { return }
            if localUsername != self.usernameText { return }
            
            if errorMessage != "" {
                self.setUnavailable()
            } else {
                self.setAvailable()
            }
        }
    }
    
    func usernameAvailable(username: String, completion: @escaping(_ err: String) -> Void) {
        
        if username == "" { completion("Invalid username"); return }
        if username == profileVC.userInfo.username { completion(""); return } /// users original username
        if !isValidUsername(username: username) { completion("invalid username"); return }
        
        let db = Firestore.firestore()
        let usersRef = db.collection("usernames")
        let query = usersRef.whereField("username", isEqualTo: username)
        
        query.getDocuments(completion: { [weak self] (snap, err) in
            
            guard let self = self else { return }
            if err != nil { completion("an error occurred"); return }
            if username != self.usernameText { completion("username already in use"); return }
            
            if (snap?.documents.count)! > 0 {
                completion("Username already in use")
            } else {
                completion("")
            }
        })
    }
    
    func removeFromUsernames(username: String) {
        let query = db.collection("usernames").whereField("username", isEqualTo: username)
        query.getDocuments { [weak self](snap, err) in
            guard let self = self else { return }
            if err == nil {
                for doc in snap!.documents { self.db.collection("usernames").document(doc.documentID).delete() }
            }
        }
    }

    
    func showErrorMessage(message: String) {
        
        errorBox.isHidden = false
        errorLabel.isHidden = false
        errorLabel.text = message
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            self.errorLabel.isHidden = true
            self.errorBox.isHidden = true
        }
        saveButton.isEnabled = true
    }
        
    
    func updateUserInfo() {
        
        let lowercaseName = newName!.lowercased()
        let nameKeywords = lowercaseName.getKeywordArray()
        
        let ref = db.collection("users").document(uid)
        ref.updateData(["name" : newName!,
                        "currentLocation" : newCity!,
                        "lowercaseName": lowercaseName,
                        "nameKeywords": nameKeywords,
                        "userBio": newBio!])
                
        profileVC.userInfo.name = newName
        profileVC.userInfo.currentLocation = newCity
        profileVC.userInfo.userBio = newBio

        if newUsername != nil {
            profileVC.userInfo.username = newUsername
            let usernameKeywords = newUsername.getKeywordArray()
            ref.updateData(["username" : newUsername!, "usernameKeywords": usernameKeywords])
        }
        
        if newProfilePic == nil  {
            profileVC.reloadProfile()
            saveButton.isEnabled = true
            dismiss(animated: true, completion: nil)
            return
        }
        
        profileVC.userInfo.profilePic = newProfilePic
        updateProfileImage()
    }
    
    func updateProfileImage(){
        
        let imageId = UUID().uuidString
        let storageRef = Storage.storage().reference().child("spotPics-dev").child("\(imageId)")
        let image = imageView.image
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
                    self.db.collection("users").document(self.uid).setData(values, merge: true)
                    
                    self.profileVC.userInfo.imageURL = urlStr
                    self.profileVC.userInfo.profilePic = self.newProfilePic ?? UIImage()
                    self.profileVC.reloadProfile()
                    self.saveButton.isEnabled = true
                    self.dismiss(animated: true, completion: nil)
                    return

                })
            } else { print("handle error")}
        }
    }
    
    @objc func openCamera(_ sender: UIButton) {

        /// use editProfileCamera to allow for imageCropVC + remove drafts button
        if let cameraController = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "EditProfileCamera") as? EditProfileCameraController {
            cameraController.modalPresentationStyle = .fullScreen
            cameraController.editProfileVC = self
            present(cameraController, animated: true, completion: nil)
        }
    }
}

extension EditProfileViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate, RSKImageCropViewControllerDelegate, RSKImageCropViewControllerDataSource {
    
    func imageCropViewControllerCustomMaskRect(_ controller: RSKImageCropViewController) -> CGRect {
        
        let aspectRatio = CGSize(width: 16, height: 16)
        
        let viewWidth = controller.view.frame.width
        let viewHeight = controller.view.frame.height
        
        var maskWidth = viewWidth
        
        let maskHeight = maskWidth * aspectRatio.height / aspectRatio.width;
        maskWidth = maskWidth - 1
        
        while maskHeight != floor(maskHeight) {
            maskWidth = maskWidth + 1
        }
        
        let maskSize = CGSize(width: maskWidth, height: maskHeight)
        
        let maskRect = CGRect(x: (viewWidth - maskSize.width) * 0.5, y: (viewHeight - maskSize.height) * 0.5, width: maskSize.width, height: maskSize.height)
        
        return maskRect
    }
    
    
    func imageCropViewControllerCustomMaskPath(_ controller: RSKImageCropViewController) -> UIBezierPath {
        let rect = controller.maskRect;
        
        let point1 = CGPoint(x: rect.minX, y: rect.maxY)
        let point2 = CGPoint(x: rect.maxX, y: rect.maxY)
        let point3 = CGPoint(x: rect.maxX, y: rect.minY)
        let point4 = CGPoint(x: rect.minX, y: rect.minY)
        
        let rectangle = UIBezierPath()
        
        rectangle.move(to: point1)
        rectangle.addLine(to: point2)
        rectangle.addLine(to: point3)
        rectangle.addLine(to: point4)
        rectangle.close()
        
        return rectangle;
    }
    
    func imageCropViewControllerCustomMovementRect(_ controller: RSKImageCropViewController) -> CGRect {
        return controller.maskRect;
    }
    
    
    func imageCropViewControllerDidCancelCrop(_ controller: RSKImageCropViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    func imageCropViewController(_ controller: RSKImageCropViewController, didCropImage croppedImage: UIImage, usingCropRect cropRect: CGRect, rotationAngle: CGFloat) {
        imageView.image = croppedImage
        newProfilePic = croppedImage
        profileVC.userInfo.profilePic = croppedImage
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        var image : UIImage = (info[UIImagePickerController.InfoKey.originalImage] as? UIImage) ?? UIImage()
        if picker.sourceType == .camera && picker.cameraDevice == .front {
            image = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: UIImage.Orientation.leftMirrored)
        }
        
        picker.dismiss(animated: false, completion: { () -> Void in
            
            var imageCropVC : RSKImageCropViewController!
            imageCropVC = RSKImageCropViewController(image: image, cropMode: RSKImageCropMode.circle)
            imageCropVC.isRotationEnabled = false
            imageCropVC.delegate = self
            imageCropVC.dataSource = self
            imageCropVC.cancelButton.setTitleColor(.systemBlue, for: .normal)
            imageCropVC.chooseButton.setTitleColor(.systemBlue, for: .normal)
            imageCropVC.chooseButton.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 18)
            imageCropVC.cancelButton.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 18)
            imageCropVC.cancelButton.setTitle("Back", for: .normal)
            imageCropVC.moveAndScaleLabel.text = "Preview Image"
            imageCropVC.moveAndScaleLabel.font = UIFont(name: "SFCompactText-Regular", size: 20)
            
            self.present(imageCropVC, animated: true, completion: nil)
        })
    }
}

extension EditProfileViewController: UITextFieldDelegate, UITextViewDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)

        switch textField.tag {
        
        case 0:
            return updatedText.count <= 25
            
        case 1:
            return updatedText.count <= 16
            
        case 2:
            return updatedText.count <= 40
            
        default:
            return false
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        
        let currentText = textView.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: text)
        
        resizeTextView()
        return updatedText.count <= 62
    }
    
    func resizeTextView() {
        var size = bioView.sizeThatFits(CGSize(width: bioView.frame.size.width, height: 200))
        /// resize to adjust textView to line changes
        if size.height == 30 { size = CGSize(width: size.width, height: 22) }
        if size.height != bioView.frame.size.height {
            let diff = size.height - bioView.frame.height
            bioContainer.frame = CGRect(x: bioContainer.frame.minX, y: bioContainer.frame.minY, width: bioContainer.frame.width, height: bioContainer.frame.height + diff)
            bioView.frame = CGRect(x: bioView.frame.minX, y: bioView.frame.minY, width: bioView.frame.width, height: bioView.frame.height + diff)
            line4.frame = CGRect(x: line4.frame.minX, y: bioContainer.frame.height - 1.5, width: line4.frame.width, height: line4.frame.height)
        }
    } */
}


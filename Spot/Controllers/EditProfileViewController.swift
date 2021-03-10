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

class EditProfileViewController: UIViewController, UITextFieldDelegate {
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    let db = Firestore.firestore()
    
    unowned var profileVC: ProfileViewController!
    var didOpenPicker = false
    
    var imageView: UIImageView!
    
    var bioContainer: UIView!
    var nameView, usernameView, cityView, bioView: UITextView!
    var line5: UIView!
    
    var errorBox: UIView!
    var errorText: UILabel!
    var saveButton: UIButton!
    
    ///let stockProfilePicURL = "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2FProfileActive3x.png?alt=media&token=91e9cab9-70a8-4d31-9866-c3861c8b7b89"
    
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
        titleLabel.font = UIFont(name: "SFCamera-Regular", size: 18)
        titleLabel.textAlignment = .center
        headerView.addSubview(titleLabel)
        
        let cancelButton = UIButton(frame: CGRect(x: 12, y: 10, width: 60, height: 26))
        cancelButton.titleEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1), for: .normal)
        cancelButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        cancelButton.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
        headerView.addSubview(cancelButton)
        
        saveButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 60, y: 13, width: 50, height: 18))
        saveButton.titleEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        saveButton.setTitle("Save", for: .normal)
        saveButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        saveButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
        saveButton.addTarget(self, action: #selector(saveTap(_:)), for: .touchUpInside)
        headerView.addSubview(saveButton)
    }
    
    func addImageView() {
        
        let imageContainer = UIView(frame: CGRect(x: 0, y: 60, width: UIScreen.main.bounds.width, height: 100))
        imageContainer.backgroundColor = nil
        view.addSubview(imageContainer)
        
        let profileLabel = UILabel(frame: CGRect(x: 14, y: 0, width: 100, height: 17))
        profileLabel.text = "Profile pic"
        profileLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        profileLabel.font = UIFont(name: "SFCamera-Semibold", size: 12)
        imageContainer.addSubview(profileLabel)
        
        imageView = UIImageView(frame: CGRect(x: 14, y: 27, width: 64, height: 64))
        imageView.image = profileVC.userInfo.profilePic
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 32
        imageView.isUserInteractionEnabled = true 
        imageContainer.addSubview(imageView)
        
        let imageMask = UIView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        imageMask.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        imageView.addSubview(imageMask)
        
        /// add edge insets so add icon covers everything and receives all touches
        let addIcon = UIButton(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        addIcon.imageEdgeInsets = UIEdgeInsets(top: 15, left: 21, bottom: 15, right: 21)
        addIcon.setImage(UIImage(named: "EditProfilePic"), for: .normal)
        addIcon.imageView?.contentMode = .scaleAspectFill
        addIcon.addTarget(self, action: #selector(openCamera(_:)), for: .touchUpInside)
        imageView.addSubview(addIcon)
    }
    
    func addTextViews() {
        
        let nameContainer = UIView(frame: CGRect(x: 0, y: 160, width: UIScreen.main.bounds.width, height: 48.5))
        nameContainer.backgroundColor = nil
        view.addSubview(nameContainer)
        
        let line = UIView(frame: CGRect(x: 14, y: 0, width: UIScreen.main.bounds.width - 28, height: 1.5))
        line.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
        nameContainer.addSubview(line)
        
        let nameLabel = UILabel(frame: CGRect(x: 14, y: 16.5, width: 60, height: 17))
        nameLabel.text = "Name"
        nameLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        nameLabel.font = UIFont(name: "SFCamera-Semibold", size: 12)
        nameContainer.addSubview(nameLabel)
        
        nameView = UITextView(frame: CGRect(x: 88, y: 11, width: UIScreen.main.bounds.width - 102, height: 22))
        nameView.backgroundColor = nil
        nameView.tag = 0
        nameView.autocorrectionType = .no
        nameView.text = profileVC.userInfo.name
        nameView.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        nameContainer.addSubview(nameView)
        
        let usernameContainer = UIView(frame: CGRect(x: 0, y: 208.5, width: UIScreen.main.bounds.width, height: 48.5))
        usernameContainer.backgroundColor = nil
        view.addSubview(usernameContainer)
        
        let line1 = UIView(frame: CGRect(x: 14, y: 0, width: UIScreen.main.bounds.width - 28, height: 1.5))
        line1.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
        usernameContainer.addSubview(line1)
        
        let usernameLabel = UILabel(frame: CGRect(x: 14, y: 16.5, width: 65, height: 17))
        usernameLabel.text = "Username"
        usernameLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        usernameLabel.font = UIFont(name: "SFCamera-Semibold", size: 12)
        usernameContainer.addSubview(usernameLabel)
        
        usernameView = UITextView(frame: CGRect(x: 88, y: 11, width: UIScreen.main.bounds.width - 102, height: 22))
        usernameView.backgroundColor = nil
        usernameView.tag = 1
        usernameView.autocorrectionType = .no
        usernameView.autocapitalizationType = .none
        usernameView.delegate = self
        usernameView.text = profileVC.userInfo.username
        usernameView.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        usernameContainer.addSubview(usernameView)
        
        let cityContainer = UIView(frame: CGRect(x: 0, y: 257, width: UIScreen.main.bounds.width, height: 48.5))
        cityContainer.backgroundColor = nil
        view.addSubview(cityContainer)
        
        let line2 = UIView(frame: CGRect(x: 14, y: 0, width: UIScreen.main.bounds.width - 28, height: 1.5))
        line2.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
        cityContainer.addSubview(line2)
        
        let cityLabel = UILabel(frame: CGRect(x: 14, y: 16.5, width: 65, height: 17))
        cityLabel.text = "Home city"
        cityLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        cityLabel.font = UIFont(name: "SFCamera-Semibold", size: 12)
        cityContainer.addSubview(cityLabel)
        
        cityView = UITextView(frame: CGRect(x: 88, y: 11, width: UIScreen.main.bounds.width - 102, height: 22))
        cityView.tag = 2
        cityView.delegate = self
        cityView.text = profileVC.userInfo.currentLocation
        cityView.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        cityView.backgroundColor = nil
        cityContainer.addSubview(cityView)
                
        bioContainer = UIView(frame: CGRect(x: 0, y: 305.5, width: UIScreen.main.bounds.width, height: 50))
        bioContainer.backgroundColor = nil
        view.addSubview(bioContainer)
        
        let line4 = UIView(frame: CGRect(x: 14, y: 0, width: UIScreen.main.bounds.width - 28, height: 1.5))
        line4.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
        bioContainer.addSubview(line4)
        
        let bioLabel = UILabel(frame: CGRect(x: 14, y: 16.5, width: 65, height: 17))
        bioLabel.text = "Bio"
        bioLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        bioLabel.font = UIFont(name: "SFCamera-Semibold", size: 12)
        bioContainer.addSubview(bioLabel)
        
        bioView = UITextView(frame: CGRect(x: 88, y: 11, width: UIScreen.main.bounds.width - 102, height: 22))
        bioView.backgroundColor = nil
        bioView.tag = 4
        bioView.delegate = self
        bioView.isScrollEnabled = false
        bioView.text = profileVC.userInfo.userBio
        bioView.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        bioContainer.addSubview(bioView)
                
        line5 = UIView(frame: CGRect(x: 14, y: 48.5, width: UIScreen.main.bounds.width - 28, height: 1.5))
        line5.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
        bioContainer.addSubview(line5)
        
        resizeTextView()
        
        errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 150, width: UIScreen.main.bounds.width, height: 32))
        errorBox.backgroundColor = UIColor(red:0.35, green:0, blue:0.04, alpha:1)
        view.addSubview(errorBox)
        errorBox.isHidden = true
        
        //Load error text
        errorText = UILabel(frame: CGRect(x: 0, y: 6, width: UIScreen.main.bounds.width, height: 18))
        errorText.lineBreakMode = .byWordWrapping
        errorText.numberOfLines = 0
        errorText.textColor = UIColor.white
        errorText.textAlignment = .center
        errorText.text = "this is a generic placeholder error message"
        errorText.font = UIFont(name: "SFCamera-Regular", size: 14)!
        errorBox.addSubview(errorText)
        errorText.isHidden = true
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func saveTap(_ sender: UIButton) {
        
        saveButton.isEnabled = false
        
        if nameView.text!.isEmpty { nameView.text = "" }
        if cityView.text!.isEmpty { cityView.text = "" }
        if bioView.text!.isEmpty { bioView.text = "" }
        
        profileVC.userInfo.name = nameView.text
        profileVC.userInfo.currentLocation = cityView.text
        profileVC.userInfo.userBio = bioView.text

        if didOpenPicker { updateProfileImage() }
        
        ///check for valid username
        let whiteSpace = " "
        if usernameView.text == profileVC.userInfo.username {
            self.updateUserInfo()
            return
        } else if (usernameView.text.contains(whiteSpace)) {
            self.showErrorMessage(message: "Please enter a valid username (no spaces)")
        } else if self.containsSpecialCharacters(username: usernameView.text) {
            self.showErrorMessage(message: "Please enter a valid username (no special characters)")
        } else if usernameView.text!.isEmpty {
            self.showErrorMessage(message: "Please enter a valid username")
        } else {
            Mixpanel.mainInstance().track(event: "EditProfileSave")
            
            usernameView.text! = usernameView.text!.lowercased()
            let usersRef = db.collection("usernames");
            let query = usersRef.whereField("username", isEqualTo: usernameView.text!)
            
            query.getDocuments(completion: { [weak self] (snap, err) in
                guard let self = self else { return }
                
                if err != nil {
                    self.updateUserInfo()
                    return
                }
                
                if (snap?.documents.count)! > 0 {
                    self.showErrorMessage(message: "Username already in use")
                
                } else {
                    self.removeFromUsernames(username: self.profileVC.userInfo.username)
                    
                    self.profileVC.userInfo.username = self.usernameView.text!
                    let usernameID = UUID().uuidString
                    self.db.collection("usernames").document(usernameID).setData(["username" : self.profileVC.userInfo.username])
                    
                    self.updateUserInfo()
                }
            })
        }
    }
    
    func showErrorMessage(message: String) {
        errorBox.isHidden = false
        errorText.isHidden = false
        errorText.text = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            self.errorText.isHidden = true
            self.errorBox.isHidden = true
        }
        saveButton.isEnabled = true
    }
    
    func containsSpecialCharacters(username: String) -> Bool {
        let characterset = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        if username.rangeOfCharacter(from: characterset.inverted) != nil {
            return true
        }
        return false
    }
    
    func removeFromUsernames(username: String) {
        let query = db.collection("usernames").whereField("username", isEqualTo: username)
        query.getDocuments { (snap, err) in
            if err == nil {
                for doc in snap!.documents {
                    print("remove from usernames", username)
                    self.db.collection("usernames").document(doc.documentID).delete()
                }
            }
        }
    }
    
    func updateUserInfo() {
        
        let ref = self.db.collection("users").document(self.uid)
        ref.updateData(["name" : profileVC.userInfo.name,
                        "currentLocation" : profileVC.userInfo.currentLocation,
                        "phone": profileVC.userInfo.phone ?? "",
                        "userBio" : profileVC.userInfo.userBio,
                        "username" : profileVC.userInfo.username])
                
        self.profileVC.reloadProfile()
        self.saveButton.isEnabled = true
        
        self.dismiss(animated: true, completion: nil)
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
            
            if error == nil, metadata != nil{
                //get download url
                storageRef.downloadURL(completion: { url, error in
                    if let error = error{
                        print("\(error.localizedDescription)")
                    }
                    //url
                    urlStr = (url?.absoluteString)!
                    print(urlStr)
                    
                    if self.profileVC != nil {
                        self.profileVC.userInfo.imageURL = urlStr
                        self.profileVC.reloadProfile()
                    }

                    let values = ["imageURL": urlStr]
                    self.db.collection("users").document(self.uid).setData(values, merge:true)
                })
            }
        }
    }
    
    @objc func openCamera(_ sender: UIButton) {

        if let cameraController = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "EditProfileCamera") as? EditProfileCameraController {
            cameraController.modalPresentationStyle = .fullScreen
            cameraController.editProfileVC = self
            self.present(cameraController, animated: true, completion: nil)
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
        self.dismiss(animated: true, completion: nil)
    }
    
    func imageCropViewController(_ controller: RSKImageCropViewController, didCropImage croppedImage: UIImage, usingCropRect cropRect: CGRect, rotationAngle: CGFloat) {
        self.imageView.image = croppedImage
        self.profileVC.userInfo.profilePic = croppedImage
        self.didOpenPicker = true
        self.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        var image : UIImage = (info[UIImagePickerController.InfoKey.originalImage] as? UIImage)!
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
            imageCropVC.chooseButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 18)
            imageCropVC.cancelButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 18)
            imageCropVC.cancelButton.setTitle("Back", for: .normal)
            imageCropVC.moveAndScaleLabel.text = "Preview Image"
            imageCropVC.moveAndScaleLabel.font = UIFont(name: "SFCamera-Regular", size: 20)
            
            self.present(imageCropVC, animated: true, completion: nil)
        })
    }
}

extension EditProfileViewController: UITextViewDelegate {
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        
        let currentText = textView.text ?? ""
        
        guard let stringRange = Range(range, in: currentText) else { return false }
        
        let updatedText = currentText.replacingCharacters(in: stringRange, with: text)
        
        switch textView.tag {
        case 0:
            return updatedText.count <= 25
        case 1:
            return updatedText.count <= 16
        case 2:
            return updatedText.count <= 25
        case 3:
            return true
        default:
            resizeTextView()
            return updatedText.count <= 170
        }
    }
    
    func resizeTextView() {
        var size = bioView.sizeThatFits(CGSize(width: bioView.frame.size.width, height: 200))
        /// resize to adjust textView to line changes
        if size.height == 30 { size = CGSize(width: size.width, height: 22) }
        if size.height != bioView.frame.size.height {
            let diff = size.height - bioView.frame.height
            bioContainer.frame = CGRect(x: bioContainer.frame.minX, y: bioContainer.frame.minY, width: bioContainer.frame.width, height: bioContainer.frame.height + diff)
            bioView.frame = CGRect(x: bioView.frame.minX, y: bioView.frame.minY, width: bioView.frame.width, height: bioView.frame.height + diff)
            line5.frame = CGRect(x: 14, y: bioContainer.frame.height - 1.5, width: UIScreen.main.bounds.width - 28, height: 1.5)
        }
    }
}


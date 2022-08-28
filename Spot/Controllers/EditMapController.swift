//
//  EditMapController.swift
//  Spot
//
//  Created by Arnold on 7/29/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import Mixpanel
import Firebase
import FirebaseUI

class EditMapController: UIViewController {
    private var editLabel: UILabel!
    private var backButton: UIButton!
    private var doneButton: UIButton!
    private var mapCoverImage: UIImageView!
    private var mapCoverImageSelectionButton: UIButton!
    private var mapNameTextField: UITextField!
    private var memberLabel: UILabel!
    private var locationTextfield: UITextField!
    private var mapDescription: UITextView!
    private var mapMemberCollectionView: UICollectionView!
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
        DispatchQueue.global(qos: .userInitiated).async {
            self.getMembers()
        }
    }
    
    @objc func dismissAction() {
        Mixpanel.mainInstance().track(event: "EditMapCancel")
        UIView.animate(withDuration: 0.15) {
            self.backButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { (Bool) in
            UIView.animate(withDuration: 0.15) {
                self.backButton.transform = .identity
            }
        }
        dismiss(animated: true)
    }
    
    @objc func mapImageSelectionAction() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.overrideUserInterfaceStyle = .light
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
    
    @objc func saveAction() {
        Mixpanel.mainInstance().track(event: "EditMapSave")
        activityIndicator.startAnimating()
        let userRef = db.collection("maps").document(mapData!.id!)
        do {
            mapData?.mapName = mapNameTextField.text!
            mapData?.mapDescription = mapDescription.text == "Add a map bio..." ? "" : mapDescription.text
            mapData?.secret = privateButton.image(for: .normal) == UIImage(named: "PrivateMapOff") ? false : true
            try userRef.setData(from: mapData, merge: true)
            
            if mapCoverChanged == false {
                updateMapCover()
            } else {
                customMapVC?.mapData = mapData
                activityIndicator.stopAnimating()
                dismiss(animated: true)
            }

        } catch {
            //handle error
        }
    }
    
    @objc func privateMapSwitchAction() {
        HapticGenerator.shared.play(.light)
        privateButton.setImage(UIImage(named: privateButton.image(for: .normal) == UIImage(named: "PrivateMapOff") ? "PrivateMapOn" : "PrivateMapOff"), for: .normal)
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
            $0.addTarget(self, action: #selector(saveAction), for: .touchUpInside)
            view.addSubview($0)
        }
        doneButton.snp.makeConstraints {
            $0.centerY.equalTo(editLabel)
            $0.trailing.equalToSuperview().inset(20)
        }
        
        mapCoverImage = UIImageView {
            $0.layer.cornerRadius = 22.85
            $0.layer.masksToBounds = true
            $0.sd_setImage(with: URL(string: mapData!.imageURL))
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
            $0.font = UIFont(name: "SFCompactText-Medium", size: 14.5)
            $0.backgroundColor = .white
            $0.textColor = mapData!.mapDescription == "" ? UIColor(red: 165/255, green: 165/255, blue: 165/255, alpha: 1) : UIColor(red: 0.292, green: 0.292, blue: 0.292, alpha: 1)
            $0.textContainer.maximumNumberOfLines = 2
            $0.textContainer.lineBreakMode = .byTruncatingTail
            view.addSubview($0)
        }
        mapDescription.snp.makeConstraints {
            $0.top.equalTo(mapNameTextField.snp.bottom).offset(21)
            $0.leading.trailing.equalToSuperview().inset(29)
            $0.height.equalTo(34)
        }

        memberLabel = UILabel {
            $0.text = "MEMBERS (\(mapData!.memberIDs.count))"
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.textColor = UIColor(red: 0.587, green: 0.587, blue: 0.587, alpha: 1)
            view.addSubview($0)
        }
        memberLabel.snp.makeConstraints {
            $0.top.equalTo(mapNameTextField.snp.bottom).offset(84)
            $0.leading.equalToSuperview().inset(16)
        }
        
        mapMemberCollectionView = {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .horizontal
            let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
            view.contentInset.left = 16
            view.delegate = self
            view.dataSource = self
            view.backgroundColor = .white
            view.showsHorizontalScrollIndicator = false
            view.register(MapMemberCell.self, forCellWithReuseIdentifier: "MapMemberCell")
            return view
        }()
        view.addSubview(mapMemberCollectionView)
        mapMemberCollectionView.snp.makeConstraints {
            $0.top.equalTo(memberLabel.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(85)
        }

        privateLabel = UILabel {
            $0.text = "PRIVATE MAP"
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.textColor = UIColor(red: 0.587, green: 0.587, blue: 0.587, alpha: 1)
            view.addSubview($0)
        }
        privateLabel.snp.makeConstraints {
            $0.top.equalTo(mapMemberCollectionView.snp.bottom).offset(33)
            $0.leading.equalTo(memberLabel)
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
        }
        
        privateDescriptionLabel = UILabel {
            $0.text = "Only invited members can see this map"
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
            $0.textColor = UIColor(red: 0.683, green: 0.683, blue: 0.683, alpha: 1)
            view.addSubview($0)
        }
        privateDescriptionLabel.snp.makeConstraints {
            $0.top.equalTo(privateLabel.snp.bottom).offset(1)
            $0.leading.equalTo(privateLabel)
            $0.trailing.equalTo(privateButton.snp.leading).offset(-14)
        }
        
        activityIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 165, width: UIScreen.main.bounds.width, height: 30))
        activityIndicator.isHidden = true
        view.addSubview(activityIndicator)
    }
    
    private func updateMapCover(){
        let imageId = UUID().uuidString
        let storageRef = Storage.storage().reference().child("spotPics-dev").child("\(imageId)")
        let image = mapCoverImage.image
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
                    self.db.collection("maps").document(self.mapData!.id!).setData(values, merge: true)
                    self.mapData?.imageURL = urlStr
                    self.customMapVC?.mapData = self.mapData
                    self.activityIndicator.stopAnimating()
                    self.dismiss(animated: true)
                    return
                })
            } else { print("handle error")}
        }
    }
    
    private func getMembers() {
        let db: Firestore = Firestore.firestore()
        let dispatch = DispatchGroup()
        memberList.removeAll()
        for id in mapData!.memberIDs {
            dispatch.enter()
            db.collection("users").document(id).getDocument { [weak self] snap, err in
                do {
                    guard let self = self else { return }
                    let unwrappedInfo = try snap?.data(as: UserProfile.self)
                    guard var userInfo = unwrappedInfo else { dispatch.leave(); return }
                    userInfo.id = id
                    self.memberList.append(userInfo)
                    dispatch.leave()
                } catch let parseError {
                    print("JSON Error \(parseError.localizedDescription)")
                    dispatch.leave()
                }
            }
        }
        dispatch.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.mapMemberCollectionView.reloadData()
        }
    }
}

extension EditMapController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == "Add a map bio..." {
            textView.text = ""
            textView.textColor = UIColor(red: 0.292, green: 0.292, blue: 0.292, alpha: 1)
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text == "" {
            textView.text = "Add a map bio..."
            textView.textColor = UIColor(red: 165/255, green: 165/255, blue: 165/255, alpha: 1)
        }
    }
}

extension EditMapController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return memberList.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MapMemberCell", for: indexPath) as! MapMemberCell
        if indexPath.row == 0 {
            let user = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: "")
            cell.cellSetUp(user: user)
        } else {
            cell.cellSetUp(user: memberList[indexPath.row - 1])
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.row == 0 else { return }
        let collectionCell = collectionView.cellForItem(at: indexPath)
        UIView.animate(withDuration: 0.15) {
            collectionCell?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { success in
            let friendsList = UserDataModel.shared.userInfo.getSelectedFriends(memberIDs: self.mapData!.memberIDs)
            let vc = FriendsListController(fromVC: self, allowsSelection: true, showsSearchBar: true, friendIDs: UserDataModel.shared.userInfo.friendIDs, friendsList: friendsList, confirmedIDs: self.mapData!.memberIDs)
            vc.delegate = self
            self.present(vc, animated: true)
            UIView.animate(withDuration: 0.15) {
                collectionCell?.transform = .identity
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 62, height: 85)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 28
    }

    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        guard indexPath.row == 0 else { return }
        let collectionCell = collectionView.cellForItem(at: indexPath)
        UIView.animate(withDuration: 0.15) {
            collectionCell?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        guard indexPath.row == 0 else { return }
        let collectionCell = collectionView.cellForItem(at: indexPath)
        UIView.animate(withDuration: 0.15) {
            collectionCell?.transform = .identity
        }
    }
}

extension EditMapController: FriendsListDelegate {
    func finishPassing(selectedUsers: [UserProfile]) {
        Mixpanel.mainInstance().track(event: "EditMapInviteFriends")
        mapData?.memberIDs.append(contentsOf: selectedUsers.map({$0.id!}))
        mapData?.likers.append(contentsOf: selectedUsers.map({$0.id!}))
        memberList.append(contentsOf: selectedUsers)
        memberLabel.text = "MEMBERS (\(mapData!.memberIDs.count))"
        DispatchQueue.main.async { self.mapMemberCollectionView.reloadData() }
    }
}

extension EditMapController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
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

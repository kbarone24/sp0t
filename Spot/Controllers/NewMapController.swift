//
//  NewMapController.swift
//  Spot
//
//  Created by Kenny Barone on 6/23/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import FirebaseUI
import IQKeyboardManagerSwift
import Mixpanel

protocol NewMapDelegate {
    func finishPassing(map: CustomMap)
}

class NewMapController: UIViewController {
    var delegate: NewMapDelegate?
    
    var exitButton: UIButton?
    var nameField: UITextField!
    var collaboratorLabel: UILabel!
    var collaboratorsCollection: UICollectionView!
    var secretLabel: UILabel!
    var secretSublabel: UILabel!
    var secretToggle: UIButton!
    
    var nextButton: UIButton?
    var createButton: UIButton?
    
    var keyboardPan: UIPanGestureRecognizer!
    var readyToDismiss = true
    
    let uid: String = UserDataModel.shared.uid
    var mapObject: CustomMap!
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
        if nameField != nil { nameField.becomeFirstResponder() }
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        disableKeyboardMethods()
    }
    
    func addMapObject() {
        let post = UploadPostModel.shared.postObject!
        mapObject = CustomMap(id: UUID().uuidString, founderID: uid, imageURL: "", likers: [uid], mapName: "", memberIDs: [uid], posterDictionary: [post.id! : [uid]], posterIDs: [uid], posterUsernames: [UserDataModel.shared.userInfo.username], postIDs: [post.id!], postImageURLs: [], postLocations: [["lat": post.postLat, "long": post.postLong]], postTimestamps: [], secret: false, spotIDs: [], memberProfiles: [UserDataModel.shared.userInfo], coverImage: UIImage())
        if !(post.addedUsers?.isEmpty ?? true) { mapObject.memberIDs.append(contentsOf: post.addedUsers!); mapObject.likers.append(contentsOf: post.addedUsers!); mapObject.memberProfiles!.append(contentsOf: post.addedUserProfiles!); mapObject.posterDictionary[post.id!]?.append(contentsOf: post.addedUsers!) }
    }
    
    func setUpView() {
        view.backgroundColor = .white
        
        /// back button will show if pushed directly on map
        if !presentedModally {
            exitButton = UIButton {
                $0.setImage(UIImage(named: "CancelButtonDark"), for: .normal)
                $0.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
                $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
                view.addSubview($0)
            }
            exitButton!.snp.makeConstraints {
                $0.top.equalTo(10)
                $0.left.equalTo(10)
                $0.height.width.equalTo(35)
            }
        }
        
        nameField = PaddedTextField {
            $0.text = mapObject.mapName
            $0.textColor = UIColor.black.withAlphaComponent(0.8)
            $0.backgroundColor = UIColor(red: 0.983, green: 0.983, blue: 0.983, alpha: 1)
            $0.layer.borderColor = UIColor(red: 0.925, green: 0.925, blue: 0.925, alpha: 1).cgColor
            $0.layer.borderWidth = 1
            $0.layer.cornerRadius = 14
            $0.attributedPlaceholder = NSAttributedString(string: "Map name", attributes: [NSAttributedString.Key.foregroundColor: UIColor.black.withAlphaComponent(0.4)])
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 22)
            $0.textAlignment = .left
            $0.tintColor = UIColor(named: "SpotGreen")
            $0.autocapitalizationType = .sentences
            $0.delegate = self
            view.addSubview($0)
        }
        let screenSizeOffset: CGFloat = UserDataModel.shared.screenSize == 2 ? 20 : 0
        let topOffset: CGFloat = presentedModally ? 25 + screenSizeOffset : 60 + screenSizeOffset
        nameField.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(margin)
            $0.trailing.equalToSuperview().offset(-30)
            $0.top.equalTo(topOffset)
            $0.height.equalTo(50)
        }
        
        collaboratorLabel = UILabel {
            $0.text = "Add friends"
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            view.addSubview($0)
        }
        collaboratorLabel.snp.makeConstraints {
            $0.leading.equalTo(margin)
            $0.top.equalTo(nameField.snp.bottom).offset(31)
            $0.height.equalTo(18)
        }
        
        let layout = UICollectionViewFlowLayout {
            $0.scrollDirection = .horizontal
            $0.minimumInteritemSpacing = 18
            $0.itemSize = CGSize(width: 62, height: 85)
            $0.sectionInset = UIEdgeInsets(top: 0, left: margin, bottom: 0, right: margin)
        }

        collaboratorsCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collaboratorsCollection.backgroundColor = .white
        collaboratorsCollection.delegate = self
        collaboratorsCollection.dataSource = self
        collaboratorsCollection.showsHorizontalScrollIndicator = false
        collaboratorsCollection.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 100)
        collaboratorsCollection.register(MapMemberCell.self, forCellWithReuseIdentifier: "MapMemberCell")
        view.addSubview(collaboratorsCollection)
        collaboratorsCollection.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(collaboratorLabel.snp.bottom).offset(8)
            $0.height.equalTo(90)
        }
        
        secretLabel = UILabel {
            $0.text = "Make this map secret"
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            view.addSubview($0)
        }
        secretLabel.snp.makeConstraints {
            $0.leading.equalTo(margin)
            $0.top.equalTo(collaboratorsCollection.snp.bottomMargin).offset(35)
            $0.height.equalTo(18)
        }
        
        secretSublabel = UILabel {
            $0.text = "Only you and invited friends will see this map"
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 12)
            view.addSubview($0)
        }
        secretSublabel.snp.makeConstraints {
            $0.leading.equalTo(margin)
            $0.top.equalTo(secretLabel.snp.bottom).offset(2)
            $0.height.equalTo(18)
        }
        
        secretToggle = UIButton {
            let tag = mapObject.secret ? 1 : 0
            let image = tag == 1 ? UIImage(named: "PrivateMapOn") : UIImage(named: "PrivateMapOff")
            $0.setImage(image, for: .normal)
            $0.tag = tag
            $0.imageView?.contentMode = .scaleAspectFit
            $0.addTarget(self, action: #selector(togglePrivacy(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        secretToggle.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(17)
            $0.top.equalTo(secretLabel.snp.top).offset(2)
            $0.width.equalTo(58.31)
            $0.height.equalTo(32)
        }
        
        if presentedModally {
            nextButton = NextButton {
                $0.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
                $0.isEnabled = false
                view.addSubview($0)
            }
            nextButton!.snp.makeConstraints {
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
            createButton!.snp.makeConstraints {
                $0.bottom.equalToSuperview().offset(-100)
                $0.leading.trailing.equalToSuperview().inset(margin)
                $0.height.equalTo(51)
                $0.centerX.equalToSuperview()
            }
        }
        
        keyboardPan = UIPanGestureRecognizer(target: self, action: #selector(keyboardPan(_:)))
        keyboardPan!.isEnabled = false
        view.addGestureRecognizer(keyboardPan!)
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
        switch sender.tag {
        case 0:
            Mixpanel.mainInstance().track(event: "NewMapPrivateMapOn")
            secretToggle.setImage(UIImage(named: "PrivateMapOn"), for: .normal)
            secretToggle.tag = 1
            mapObject.secret = true
        case 1:
            Mixpanel.mainInstance().track(event: "NewMapPrivateMapOff")
            secretToggle.setImage(UIImage(named: "PrivateMapOff"), for: .normal)
            secretToggle.tag = 0
            mapObject.secret = false
        default: return
        }
    }
    
    func setFinalMapValues() {
        var text = nameField.text ?? ""
        while text.last?.isWhitespace ?? false { text = String(text.dropLast()) }
        mapObject.mapName = text
        mapObject.lowercaseName = text.lowercased()
        mapObject.searchKeywords = mapObject.lowercaseName!.getKeywordArray()
        mapObject.coverImage = UploadPostModel.shared.postObject.postImage.first ?? UIImage()
        if presentedModally { UploadPostModel.shared.postObject.hideFromFeed = mapObject.secret }
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
        delegate?.finishPassing(map: mapObject)
        DispatchQueue.main.async { self.dismiss(animated: true) }
    }
    
    @objc func backTapped() {
        /// destroy on return to map
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
        animateWithKeyboard(notification: notification) { keyboardFrame in
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
        return mapObject.memberIDs.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MapMemberCell", for: indexPath) as! MapMemberCell
        if indexPath.row == 0 {
            let user = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: "")
            cell.cellSetUp(user: user)
        } else {
            guard let profile = mapObject.memberProfiles?[safe: indexPath.row - 1] else { return cell }
            cell.cellSetUp(user: profile)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let friendsList = UserDataModel.shared.userInfo.getSelectedFriends(memberIDs: mapObject.memberIDs)
        let vc = FriendsListController(fromVC: self, allowsSelection: true, showsSearchBar: true, friendIDs: UserDataModel.shared.userInfo.friendIDs, friendsList: friendsList, confirmedIDs: UploadPostModel.shared.postObject.addedUsers!, sentFrom: .NewMap)
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
        mapObject.memberIDs = members.map({$0.id!})
        mapObject.likers = mapObject.memberIDs
        mapObject.memberProfiles = members
        DispatchQueue.main.async { self.collaboratorsCollection.reloadData() }
    }
}

class NextButton: UIButton {
    var label: UILabel!
    
    override var isEnabled: Bool {
        didSet {
            alpha = isEnabled ? 1.0 : 0.4
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(named: "SpotGreen")
        layer.cornerRadius = 9
     
        label = UILabel {
            $0.text = "Next"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Bold", size: 16)
            addSubview($0)
        }
        label.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class CreateMapButton: UIButton {
    var chooseLabel: UILabel!
    
    override var isEnabled: Bool {
        didSet {
            alpha = isEnabled ? 1.0 : 0.4
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(named: "SpotGreen")
        layer.cornerRadius = 9
     
        chooseLabel = UILabel {
            $0.text = "Create Map"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Bold", size: 16)
            addSubview($0)
        }
        chooseLabel.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

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

protocol NewMapDelegate {
    func finishPassing(map: CustomMap)
}

class NewMapController: UIViewController {
    var delegate: NewMapDelegate?
    
    var exitButton: UIButton!
    var nameField: UITextField!
    var collaboratorLabel: UILabel!
    var collaboratorsCollection: UICollectionView!
    var secretLabel: UILabel!
    var secretSublabel: UILabel!
    var secretToggle: UIButton!
    var createButton: UIButton!
    
    var keyboardPan: UIPanGestureRecognizer!
    var readyToDismiss = true
    
    let uid: String = UserDataModel.shared.uid
    var mapObject: CustomMap!
  
    override func viewDidLoad() {
        super.viewDidLoad()
        addMapObject()
        setUpView()
        presentationController?.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        IQKeyboardManager.shared.enableAutoToolbar = false
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        IQKeyboardManager.shared.enableAutoToolbar = true
    }
    
    func addMapObject() {
        let post = UploadPostModel.shared.postObject!
        mapObject = CustomMap(id: UUID().uuidString, founderID: uid, imageURL: "", likers: [], mapName: "", memberIDs: [uid], posterDictionary: [post.id! : [uid]], posterIDs: [uid], posterUsernames: [UserDataModel.shared.userInfo.username], postIDs: [post.id!], postImageURLs: [], postLocations: [["lat": post.postLat, "long": post.postLong]], postTimestamps: [], secret: false, spotIDs: [], memberProfiles: [UserDataModel.shared.userInfo], coverImage: UploadPostModel.shared.postObject.postImage.first ?? UIImage(named: "BlankImage"))
        if !(post.addedUsers?.isEmpty ?? true) { mapObject.memberIDs.append(contentsOf: post.addedUsers!); mapObject.memberProfiles!.append(contentsOf: post.addedUserProfiles!); mapObject.posterDictionary[post.id!]?.append(contentsOf: post.addedUsers!) }
    }
    
    func setUpView() {
        view.backgroundColor = .white
        title = "Create map"
        let margin: CGFloat = 18
        
        exitButton = UIButton {
            $0.setImage(UIImage(named: "CancelButtonDark"), for: .normal)
            $0.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            view.addSubview($0)
        }
        exitButton.snp.makeConstraints {
            $0.top.equalTo(7)
            $0.left.equalTo(10)
            $0.height.width.equalTo(35)
        }
        
        nameField = UITextField {
            $0.textColor = UIColor.black.withAlphaComponent(0.8)
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            $0.layer.borderColor = UIColor(red: 0.929, green: 0.929, blue: 0.929, alpha: 1).cgColor
            $0.layer.borderWidth = 1
            $0.layer.cornerRadius = 5
            $0.keyboardDistanceFromTextField = 250
            $0.attributedPlaceholder = NSAttributedString(string: "Map name", attributes: [NSAttributedString.Key.foregroundColor: UIColor.black.withAlphaComponent(0.4)])
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 22)
            $0.textAlignment = .center
            $0.tintColor = UIColor(named: "SpotGreen")
            $0.autocapitalizationType = .sentences
            $0.delegate = self
            view.addSubview($0)
        }
        nameField.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(margin)
            $0.top.equalTo(60)
            $0.height.equalTo(50)
        }
        
        collaboratorLabel = UILabel {
            $0.text = "MEMBERS"
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
            $0.text = "PRIVATE MAP"
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
            $0.text = "Only invited members can see this map"
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
            $0.setImage(UIImage(named: "PrivateMapOff"), for: .normal)
            $0.imageView?.contentMode = .scaleAspectFit
            $0.addTarget(self, action: #selector(togglePrivacy(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        secretToggle.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(17)
            $0.top.equalTo(secretLabel.snp.top)
            $0.width.equalTo(68)
            $0.height.equalTo(38)
        }
        
        createButton = CreateMapButton {
            $0.addTarget(self, action: #selector(createTap(_:)), for: .touchUpInside)
            $0.isEnabled = false
            view.addSubview($0)
        }
        createButton.snp.makeConstraints {
            $0.top.equalTo(secretSublabel.snp.bottom).offset(38)
            $0.width.equalTo(219)
            $0.height.equalTo(51)
            $0.centerX.equalToSuperview()
        }
        
        keyboardPan = UIPanGestureRecognizer(target: self, action: #selector(keyboardPan(_:)))
        keyboardPan!.isEnabled = false
        view.addGestureRecognizer(keyboardPan!)
    }
    
    @objc func togglePrivacy(_ sender: UIButton) {
        switch sender.tag {
        case 0:
            secretToggle.setImage(UIImage(named: "PrivateMapOn"), for: .normal)
            secretToggle.tag = 1
            mapObject.secret = true
        case 1:
            secretToggle.setImage(UIImage(named: "PrivateMapOff"), for: .normal)
            secretToggle.tag = 0
            mapObject.secret = false
        default: return
        }
    }
    
    @objc func createTap(_ sender: UIButton) {
        var text = nameField.text ?? ""
        while text.last?.isWhitespace ?? false { text = String(text.dropLast()) }
        mapObject.mapName = text
        delegate?.finishPassing(map: mapObject)
        DispatchQueue.main.async { self.dismiss(animated: true) }
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        DispatchQueue.main.async { self.dismiss(animated: true) }
    }
    
    @objc func keyboardPan(_ sender: UIPanGestureRecognizer) {
        if abs(sender.translation(in: view).y) > abs(sender.translation(in: view).x) {
            nameField.resignFirstResponder()
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
        createButton.isEnabled = textField.text?.trimmingCharacters(in: .whitespaces).count ?? 0 > 0
        textField.attributedText = NSAttributedString(string: textField.text ?? "")
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
            cell.cellSetUp(user: mapObject.memberProfiles![indexPath.row - 1])
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let friendsList = UserDataModel.shared.userInfo.getSelectedFriends(memberIDs: mapObject.memberIDs)
        let vc = FriendsListController(fromVC: self, allowsSelection: true, showsSearchBar: true, friendIDs: UserDataModel.shared.userInfo.friendIDs, friendsList: friendsList, confirmedIDs: UploadPostModel.shared.postObject.addedUsers!)
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
        mapObject.memberProfiles = members
        DispatchQueue.main.async { self.collaboratorsCollection.reloadData() }
    }
}

class CreateMapButton: UIButton {
    var contentArea: UIView!
    var chooseLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(named: "SpotGreen")
        layer.cornerRadius = 20
     
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

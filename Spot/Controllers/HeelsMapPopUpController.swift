//
//  HeelsMapPopUpController.swift
//  Spot
//
//  Created by Shay Gyawali on 8/11/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//


import Foundation
import UIKit
import Firebase
import FirebaseUI
import Mixpanel
import IQKeyboardManagerSwift
import MapKit



class HeelsMapPopUpController: UIViewController {
    
    let db: Firestore = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
            
    var textFieldContainer: UIView!
    var textField: UITextField!
    var joinButton: UIButton!
    
    lazy var searchTextGlobal = ""
    
    var icon: UIImageView!
    var titleLabel: UILabel!
    var friendsJoined: UIButton!
    var subtitle: UILabel!
    var friendsText = ""
    var heelsMap: CustomMap!
    var heelsCount = 0

    var mapDelegate: MapControllerDelegate!
        
    override func viewDidLoad() {
        
        super.viewDidLoad()
        view.backgroundColor = .white
        getHeelsMap()
        loadInfoView()
        loadSearchView()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        IQKeyboardManager.shared.enableAutoToolbar = false
    }
    
    func loadInfoView(){
        icon = UIImageView {
            $0.image = UIImage(named: "HeelsMapPopUp")
            $0.contentMode = .scaleAspectFit
            view.addSubview($0)
        }
        
        icon.snp.makeConstraints {
            $0.top.equalToSuperview().offset(33)
            $0.centerX.equalToSuperview()
            $0.width.equalTo(103.05)
            $0.height.equalTo(100)
        }
        
        titleLabel = UILabel {
            $0.text = "Heelsmap"
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 28)
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            view.addSubview($0)
        }
        
        titleLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(icon.snp.bottom).offset(3)
        }
        
        friendsText = String(heelsCount) + " Joined"
        friendsJoined = UIButton {
            $0.setImage(UIImage(named: "Friends")?.alpha(0.5), for: .normal)
            let customButtonTitle = NSMutableAttributedString(string: friendsText, attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15)!,
                NSAttributedString.Key.foregroundColor: UIColor(red: 0.712, green: 0.712, blue: 0.712, alpha: 1)
            ])
            $0.setAttributedTitle(customButtonTitle, for: .normal)
            $0.titleLabel?.adjustsFontSizeToFitWidth = true
            $0.setTitleColor(UIColor(red: 0.712, green: 0.712, blue: 0.712, alpha: 1), for: .normal)
            $0.titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: -5)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 15)
            view.addSubview($0)
        }
        
        friendsJoined.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(titleLabel.snp.bottom).offset(8)
        }
        
        subtitle = UILabel {
            $0.text = "Join UNC's community map"
            $0.font = UIFont(name: "SFCompactText-Medium", size: 19)
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            view.addSubview($0)
        }
        
        subtitle.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(friendsJoined.snp.bottom).offset(13)
        }
        
        let cancel = UIButton {
            $0.setImage(UIImage(named: "XFriendRequest"), for: .normal)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.addTarget(self, action: #selector(self.close(_:)), for: .touchUpInside)
            $0.isHidden = false
            view.addSubview($0)
        }
        
        cancel.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-5)
            $0.top.equalToSuperview().offset(5)
            $0.height.width.equalTo(40)
        }
        
    }
    
        
    func loadSearchView() {
        
        textFieldContainer = UIView {
            $0.backgroundColor = nil
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        textFieldContainer.snp.makeConstraints{
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(subtitle.snp.bottom).offset(20)
            $0.width.equalToSuperview()
            $0.height.equalTo(50)
        }
        
        textField = UITextField {
            $0.borderStyle = .roundedRect
            $0.backgroundColor = UIColor(red: 0.945, green: 0.945, blue: 0.949, alpha: 1)
            var placeholderText = NSMutableAttributedString()
            placeholderText = NSMutableAttributedString(string: "Enter school email", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Medium", size: 21) as Any,
                    NSAttributedString.Key.foregroundColor: UIColor(red: 0.733, green: 0.733, blue: 0.733, alpha: 1)
            ])
            $0.attributedPlaceholder = placeholderText
            $0.textContentType = .emailAddress
            $0.keyboardType = .emailAddress
            $0.autocorrectionType = .no
            $0.autocapitalizationType = .none
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 21)
            $0.textColor = UIColor(red: 0.292, green: 0.292, blue: 0.292, alpha: 1)
            $0.textAlignment = .center
            $0.delegate = self
            textFieldContainer.addSubview($0)
        }
        
        textField.snp.makeConstraints{
            $0.leading.equalToSuperview().offset(16)
            $0.trailing.equalToSuperview().offset(-16)
            $0.top.bottom.equalToSuperview()
        }
        
        joinButton = UIButton {
            $0.layer.cornerRadius = 15
            $0.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            var customButtonTitle = NSMutableAttributedString()
            customButtonTitle = NSMutableAttributedString(string: "Join", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Heavy", size: 14.5) as Any,
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ])
            $0.setAttributedTitle(customButtonTitle, for: .normal)
            $0.setImage(nil, for: .normal)
            $0.alpha = 0.5
            view.addSubview($0)
        }
        
        joinButton.snp.makeConstraints{
            $0.leading.trailing.equalToSuperview().inset(50)
            $0.height.equalTo(49)
            $0.top.equalTo(textFieldContainer.snp.bottom).offset(25)
        }
    }
    
    func validateEmail(){
        let allLower = searchTextGlobal.lowercased()
        if(allLower.contains("unc.edu")) {
            joinButton.alpha = 1.0
            joinButton.addTarget(self, action: #selector(addHeelsMap(_:)), for: .touchUpInside)
        } else {
            joinButton.alpha = 0.5
            joinButton.removeTarget(self, action: #selector(addHeelsMap(_:)), for: .touchUpInside)
        }
    }
    
    func getHeelsMap() {
         self.db.collection("maps").document("9ECABEF9-0036-4082-A06A-C8943428FFF4").getDocument { (heelsMapSnap, err) in
             do {
                 let mapIn = try heelsMapSnap?.data(as: CustomMap.self)
                 guard var mapInfo = mapIn else { return;}
                 /// append spots to show on map even if there's no post attached
                 if !mapInfo.spotIDs.isEmpty {
                     for i in 0...mapInfo.spotIDs.count - 1 {
                         let coordinate = CLLocationCoordinate2D(latitude: mapInfo.spotLocations[safe: i]?["lat"] ?? 0.0, longitude: mapInfo.spotLocations[safe: i]?["long"] ?? 0.0)
                         mapInfo.postGroup.append(MapPostGroup(id: mapInfo.spotIDs[i], coordinate: coordinate, spotName: mapInfo.spotNames[safe: i] ?? "", postIDs: []))
                     }
                 }
                 self.heelsMap = mapInfo
                 self.friendsText = String(mapInfo.memberIDs.count) + " Friends"
                 let customButtonTitle = NSMutableAttributedString(string: self.friendsText, attributes: [
                     NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15)!,
                     NSAttributedString.Key.foregroundColor: UIColor(red: 0.712, green: 0.712, blue: 0.712, alpha: 1)
                 ])
                 self.friendsJoined.setAttributedTitle(customButtonTitle, for: .normal)
                                 
             } catch {
                 /// remove broken friend object
                 return
             }
         }
     }
    
    @objc func addHeelsMap(_ sender: UIButton){
        Mixpanel.mainInstance().track(event: "HeelsMapAddUser")
        let schoolEmail = searchTextGlobal.lowercased().trimmingCharacters(in: .whitespaces)
        db.collection("users").document(uid).updateData(["schoolEmail" : schoolEmail])
        mapDelegate.addHeelsMap(heelsMap: self.heelsMap)
        DispatchQueue.main.async { self.dismiss(animated: true, completion: nil) }
    }
    
    @objc func close(_ sender: UIButton){
        Mixpanel.mainInstance().track(event: "HeelsMapCloseTap")
        dismiss(animated: true)
    }
}
    

// MARK: - HeelsMap UITextFieldDelegate
extension HeelsMapPopUpController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return false
    }
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        searchTextGlobal = textField.text!
        validateEmail()
    }
}




//
//  ConfirmCodeController.swift
//  Spot
//
//  Created by Kenny Barone on 3/24/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel
import IQKeyboardManagerSwift

class ConfirmCodeController: UIViewController {
    
    var phoneNumber: String!
    var rawNumber: String!
    var newUser: NewUser!
    var codeType: CodeType!
    
    var verificationID: String!
    var label: UILabel!
    var codeField: UITextField!
    var confirmButton: UIButton!
    
    var activityIndicator: CustomActivityIndicator!
    var errorBox: UIView!
    var errorLabel: UILabel!
    
    var cancelOnDismiss = false

    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableKeyboardMethods()
        if codeField != nil { codeField.becomeFirstResponder() }
        Mixpanel.mainInstance().track(event: "ConfirmCodeOpen")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        IQKeyboardManager.shared.enable = true
        disableKeyboardMethods()
    }
    
    func enableKeyboardMethods() {
        cancelOnDismiss = false
        IQKeyboardManager.shared.enableAutoToolbar = false
        IQKeyboardManager.shared.enable = false /// disable for textView sticking to keyboard
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    }
    
    func disableKeyboardMethods() {
        cancelOnDismiss = true
        IQKeyboardManager.shared.enable = true
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
        setUpNavBar()
    }
    
    func setUpNavBar(){
        navigationController!.navigationBar.barTintColor = UIColor.white
        navigationController!.navigationBar.isTranslucent = false
        navigationController!.navigationBar.barStyle = .black
        navigationController!.navigationBar.tintColor = UIColor.black
        navigationController?.view.backgroundColor = .white
        navigationController?.navigationBar.addWhiteBackground()
        
        let logo = UIImage(named: "OnboardingLogo")
        let imageView = UIImageView(image:logo)
        //imageView.contentMode = .scaleToFill
        imageView.snp.makeConstraints{
            $0.height.equalTo(32.9)
            $0.width.equalTo(78)

        }
        self.navigationItem.titleView = imageView

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "BackArrow-1"),
            style: .plain,
            target: self,
            action: #selector(backTapped(_:))
        )
    }
    func setUpViews(){
        view.backgroundColor = .white
        
        let labelText = "Verify your phone number"
        let minX: CGFloat = codeType == .multifactor ? 27 : 10
        
        label = UILabel {
            $0.text = labelText
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 20)
            view.addSubview($0)
        }
        label.snp.makeConstraints{
            $0.top.equalToSuperview().offset(114)
            $0.centerX.equalToSuperview()
        }
        
        codeField = PaddedTextField {
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 27.5)
            $0.textAlignment = .center
            $0.tintColor = UIColor(named: "SpotGreen")
            $0.textColor = .black
            var placeholderText = NSMutableAttributedString()
            placeholderText = NSMutableAttributedString(string: "00000", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Medium", size: 27.5),
                    NSAttributedString.Key.foregroundColor: UIColor(red: 0.733, green: 0.733, blue: 0.733, alpha: 1)
            ])
            $0.attributedPlaceholder = placeholderText
            $0.addTarget(self, action: #selector(codeChanged(_:)), for: .editingChanged)
            view.addSubview($0)
        }
        codeField.snp.makeConstraints{
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.top.equalTo(label.snp.bottom).offset(30)
            $0.height.equalTo(40)
        }
        
        let bottomLine = UIView {
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            view.addSubview($0)
        }
        bottomLine.snp.makeConstraints{
            $0.height.equalTo(1.5)
            $0.width.equalTo(codeField.snp.width)
            $0.top.equalTo(codeField.snp.bottom).offset(5)
            $0.centerX.equalToSuperview()
        }
        
        confirmButton = UIButton {
             $0.layer.cornerRadius = 9
             $0.backgroundColor = UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1)
             let customButtonTitle = NSMutableAttributedString(string: "Send code", attributes: [
                 NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 16) as Any,
                 NSAttributedString.Key.foregroundColor: UIColor(red: 0, green: 0, blue: 0, alpha: 1)
             ])
             $0.setAttributedTitle(customButtonTitle, for: .normal)
             $0.setImage(nil, for: .normal)
             $0.addTarget(self, action: #selector(confirmTapped(_:)), for: .touchUpInside)
             view.addSubview($0)
        }
        confirmButton.snp.makeConstraints{
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.height.equalTo(49)
            $0.bottom.equalToSuperview().offset(-30)
        }
                
        activityIndicator = CustomActivityIndicator {
            $0.isHidden = true
            view.addSubview($0)
        }
        activityIndicator.snp.makeConstraints{
            $0.top.equalTo(bottomLine.snp.bottom).offset(15)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(20)
        }

        errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 250, width: UIScreen.main.bounds.width, height: 32))
        errorBox.backgroundColor = UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1)
        errorBox.isHidden = true
        view.addSubview(errorBox)
        
        errorLabel = UILabel(frame: CGRect(x: 23, y: 7, width: UIScreen.main.bounds.width - 46, height: 18))
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.numberOfLines = 0
        errorLabel.textColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.00)
        errorLabel.textAlignment = .center
        errorLabel.font = UIFont(name: "SFCompactText-Regular", size: 14)
        errorLabel.text = "Invalid credentials, please try again."
        errorLabel.isHidden = true
        errorBox.addSubview(errorLabel)
    }
    
    @objc func backTapped(_ sender: UIButton) {
        self.dismiss(animated: false, completion: nil)
    }
    
    @objc func codeChanged(_ sender: UITextField) {
        confirmButton.alpha = sender.text?.count ?? 0 != 6 ? 0.65 : 1.0
    }
    
    @objc func keyboardWillShow(_ notification: NSNotification) {
        print("keyboard will show")
        if cancelOnDismiss { return }
        /// new spot name view editing when textview not first responder
        animateWithKeyboard(notification: notification) { keyboardFrame in
            self.confirmButton.snp.removeConstraints()
            self.confirmButton.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(18)
                $0.height.equalTo(49)
                $0.bottom.equalToSuperview().offset(-keyboardFrame.height - 20)
            }
        }
    }

    @objc func keyboardWillHide(_ notification: NSNotification) {
        /// new spot name view editing when textview not first responder
        if cancelOnDismiss { return }
        animateWithKeyboard(notification: notification) { keyboardFrame in
            self.confirmButton.snp.removeConstraints()
            self.confirmButton.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(18)
                $0.height.equalTo(49)
                $0.bottom.equalToSuperview().offset(-30)
            }
        }
    }
    
    @objc func confirmTapped(_ sender: UIButton) {
        
        self.view.endEditing(true)
        guard let code = codeField.text?.trimmingCharacters(in: .whitespaces) else { return }
        if code.count != 6 { showError(message: "Invalid code"); return }
        
        let phoneCredential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code)
        
        activityIndicator.startAnimating()
        sender.isUserInteractionEnabled = false
        
        if codeType == .multifactor {
            /// user either sent from email signin or from scene delegate with no validated phone number
            self.linkMultifactor(credential: phoneCredential)
            return
        }
        
         Auth.auth().signIn(with: phoneCredential) { (authResult, err) in
            
            if err == nil && authResult != nil {
                
                if self.codeType == .logIn {
                    self.animateToMap()
                    return
                } else if self.codeType == .newAccount {
                    let avi = AvatarSelectionController(sentFrom: "create")
                    self.navigationController!.pushViewController(avi, animated: true)
                }
                
                let user = authResult!.user

                sender.isUserInteractionEnabled = true
                self.showError(message: err?.localizedDescription ?? "")
                        
                Mixpanel.mainInstance().track(event: "ConfirmCodeInvalidAuth", properties: ["error": err?.localizedDescription ?? ""])
                        
                /// unlink phone number verification so that user doesnt' have half an acount created and can try again with this phone number
                Auth.auth().currentUser?.unlink(fromProvider: user.providerID, completion: nil)
            
            } else {
                Mixpanel.mainInstance().track(event: "ConfirmCodeInvalidCode")
                sender.isUserInteractionEnabled = true
                self.showError(message: "Invalid code")
            }
        }

    }
    
    func linkMultifactor(credential: PhoneAuthCredential) {
        
        guard let currentUser = Auth.auth().currentUser else {  return }
        
        currentUser.link(with: credential) { (authResult, err) in
            
            if err == nil && authResult != nil {
                
                let db = Firestore.firestore()
                guard let uid = Auth.auth().currentUser?.uid else { return }
                /// update to confirm user multiauth
                let phone = self.phoneNumber ?? ""
                db.collection("users").document(uid).updateData(["phone" : phone as Any, "verifiedPhone": true])
                
                let defaults = UserDefaults.standard
                defaults.set(true, forKey: "verifiedPhone")
                
                Mixpanel.mainInstance().track(event: "ConfirmCodeLinkUserMultifactorSuccess")

                self.animateToMap()
                
            } else {

                Mixpanel.mainInstance().track(event: "ConfirmCodeLinkUserMultifactorFailure")
                self.confirmButton.isUserInteractionEnabled = true
                self.showError(message: "Invalid code")
            }
        }
    }
    
    func showError(message: String) {
        
        self.activityIndicator.stopAnimating()
        self.errorBox.isHidden = false
        self.errorLabel.isHidden = false
        self.errorLabel.text = message
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            self.errorLabel.isHidden = true
            self.errorBox.isHidden = true
        }
    }

    func saveUserToFirebase() {
        
        let db = Firestore.firestore()
        guard let uid = Auth.auth().currentUser?.uid else{return}
        
        let tutorialList: [Bool] = [false, false, false, false]
                
        let lowercaseName = newUser.name.lowercased()
        let nameKeywords = lowercaseName.getKeywordArray()
        let usernameKeywords = newUser.username.getKeywordArray()
        
        let values = ["name" : newUser.name,
                      "username" : newUser.username,
                      "phone" : newUser.phone,
                      "userBio" : "",
                      "friendsList" :  [],
                      "spotScore" : 0,
                      "admin" : false,
                      "lowercaseName" : lowercaseName,
                      "imageURL" :  "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2FProfileActive3x.png?alt=media&token=91e9cab9-70a8-4d31-9866-c3861c8b7b89",
                      "currentLocation" : "",
                      "tutorialList" : tutorialList,
                      "verifiedPhone" : true,
                      "sentInvites" : [],
                      "pendingFriendRequests" : [],
                      "usernameKeywords": usernameKeywords,
                      "nameKeywords" : nameKeywords,
                      "topFriends": [:],
                      "avatarURL" : "",
            ] as [String : Any]
        
        db.collection("users").document(uid).setData(values, merge: true)
        
        let defaults = UserDefaults.standard /// save verfiied phone login to user defaults 
        defaults.set(true, forKey: "verifiedPhone")
        
        let docID = UUID().uuidString
        db.collection("usernames").document(docID).setData(["username" : newUser.username])
        
        let functions = Functions.functions()
        let phone = newUser.phone.formatNumber()
        functions.httpsCallable("addInitialFriends").call(["userID": uid, "username": newUser.username, "phone": phone]) { result, error in
            print(result?.data as Any, error as Any)
        }
    }
    
    func animateToMap() {
        
       let storyboard = UIStoryboard(name: "Map", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MapVC") as! MapController
        let navController = UINavigationController(rootViewController: vc)
        navController.modalPresentationStyle = .fullScreen
        
        let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow}).first
        keyWindow?.rootViewController = navController
        
       //let avi = AvatarSelectionController(sentFrom: "create")
       //navigationController!.pushViewController(avi, animated: true)
    }
    
    func presentSearchOverview() {
        
        /// replace animate to map logic with search contacts
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ContactsOverview") as? ContactsOverviewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

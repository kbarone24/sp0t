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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if codeField != nil { codeField.becomeFirstResponder() }
        Mixpanel.mainInstance().track(event: "ConfirmCodeOpen")
    }
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        navigationItem.title = codeType == .newAccount ? "Create account" : "Log in"

        let backArrow = UIImage(named: "BackArrow")?.withRenderingMode(.alwaysOriginal)
        navigationController?.navigationBar.backIndicatorImage = backArrow
        navigationController?.navigationBar.backIndicatorTransitionMaskImage = backArrow
        
        label = UILabel(frame: CGRect(x: 10, y: 134, width: UIScreen.main.bounds.width - 20, height: 18))
        label.text = "Enter your code:"
        label.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Regular", size: 15)
        label.textAlignment = .center
        view.addSubview(label)
        
        codeField = PaddedTextField(frame: CGRect(x: 27, y: label.frame.maxY + 31, width: UIScreen.main.bounds.width - 54, height: 60))
        codeField.backgroundColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
        codeField.font = UIFont(name: "SFCompactText-Semibold", size: 28)
        codeField.textAlignment = .center
        codeField.tintColor = UIColor(named: "SpotGreen")
        codeField.textColor = .black
        codeField.layer.cornerRadius = 15
        codeField.layer.borderWidth = 1
        codeField.layer.borderColor = UIColor(red: 0.158, green: 0.158, blue: 0.158, alpha: 1).cgColor
        codeField.textContentType = .oneTimeCode
        codeField.keyboardType = .numberPad
        codeField.addTarget(self, action: #selector(codeChanged(_:)), for: .editingChanged)
        view.addSubview(codeField)
        
        confirmButton = UIButton(frame: CGRect(x: (UIScreen.main.bounds.width - 217)/2, y: codeField.frame.maxY + 32, width: 217, height: 40))
        confirmButton.alpha = 0.65
        confirmButton.setImage(UIImage(named: "ConfirmButton"), for: .normal)
        confirmButton.addTarget(self, action: #selector(confirmTapped(_:)), for: .touchUpInside)
        view.addSubview(confirmButton)
        
        activityIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 165, width: UIScreen.main.bounds.width, height: 30))
        activityIndicator.isHidden = true
        view.addSubview(activityIndicator)

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
    
    @objc func codeChanged(_ sender: UITextField) {
        confirmButton.alpha = sender.text?.count ?? 0 != 6 ? 0.65 : 1.0
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
                }
                
                let user = authResult!.user
                let emailCredential = EmailAuthProvider.credential(withEmail: self.newUser.email, password: self.newUser.password)
                user.link(with: emailCredential) { (emailResult, err) in
                    
                    if err == nil && emailResult != nil {
                        self.activityIndicator.stopAnimating()
                        self.saveUserToFirebase()
                        self.presentSearchOverview()
                        
                    } else {
                        sender.isUserInteractionEnabled = true
                        self.showError(message: err?.localizedDescription ?? "")
                        
                        Mixpanel.mainInstance().track(event: "ConfirmCodeInvalidAuth", properties: ["error": err?.localizedDescription ?? ""])
                        
                        /// unlink phone number verification so that user doesnt' have half an acount created and can try again with this phone number
                        Auth.auth().currentUser?.unlink(fromProvider: user.providerID, completion: nil)
                    }
                }
                
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
                      "email" : newUser.email,
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
                      "tagDictionary": [:],
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
    }
    
    func presentSearchOverview() {
        
        /// replace animate to map logic with search contacts
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ContactsOverview") as? ContactsOverviewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

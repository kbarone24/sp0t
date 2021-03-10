//
//  SignUp2Controller.swift
//  Spot
//
//  Created by kbarone on 4/9/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel

class SignUp2Controller: UIViewController, UITextFieldDelegate {
    
    var usernameField: UITextField!
    var passwordField: UITextField!
    var cityField: UITextField!
    var errorBox: UIView!
    var errorTextLayer: UILabel!
    var nextButton: UIButton!
    
    var signUpObject: (name: String, email: String, phone: String, username: String, password: String, city: String) = ("", "", "", "", "", "")
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "SignUp2Open")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "SpotBlack")
        
        var heightAdjust: CGFloat = 0
        if (!(UIScreen.main.nativeBounds.height > 2300 || UIScreen.main.nativeBounds.height == 1792)) {
            heightAdjust = 20
        }
        let logoImage = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 45, y: 52 - heightAdjust, width: 90, height: 36))
        logoImage.image = UIImage(named: "MapSp0tLogo")
        logoImage.contentMode = .scaleAspectFit
        view.addSubview(logoImage)
        
        let arrow = UIButton(frame: CGRect(x: 0, y: 55 - heightAdjust, width: 40, height: 40))
        arrow.setImage(UIImage(named: "BackButton"), for: .normal)
        arrow.addTarget(self, action: #selector(backTapped(_:)), for: .touchUpInside)
        view.addSubview(arrow)
        
        let createText = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 95, y: logoImage.frame.maxY + 20, width: 190, height: 30))
        createText.textAlignment = .center
        createText.text = "Create account"
        createText.textColor = UIColor(red:0.64, green:0.64, blue:0.64, alpha:1.00)
        createText.font = UIFont(name: "SFCamera-Semibold", size: 18)
        view.addSubview(createText)
        
        addDotView(y: createText.frame.maxY + 4)
        
        let usernameLabel = UILabel(frame: CGRect(x: 37, y: createText.frame.maxY + 43, width: 100, height: 18))
        usernameLabel.text = "Username"
        usernameLabel.textColor = UIColor(named: "SpotGreen")
        usernameLabel.font = UIFont(name: "SFCamera-Semibold", size: 13)
        usernameLabel.sizeToFit()
        view.addSubview(usernameLabel)
        
        usernameField = UITextField(frame: CGRect(x: 28.5, y: usernameLabel.frame.maxY + 3, width: UIScreen.main.bounds.width - 57, height: 41))
        usernameField.layer.cornerRadius = 10
        usernameField.backgroundColor = UIColor(red:0.16, green:0.16, blue:0.16, alpha:0.5)
        usernameField.layer.borderColor = UIColor(red:0.21, green:0.21, blue:0.21, alpha:1).cgColor
        usernameField.layer.borderWidth = 1
        view.addSubview(usernameField)
        
        usernameField.text = signUpObject.username
        usernameField.textColor = UIColor.white
        usernameField.autocorrectionType = .no
        usernameField.autocapitalizationType = .none
        usernameField.accessibilityHint = "username"
        usernameField.delegate = self
        usernameField.textContentType = .username
        usernameField.font = UIFont(name: "SFCamera-regular", size: 16)!
        
        let usernamePad = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: self.usernameField.frame.height))
        usernameField.leftView = usernamePad
        usernameField.leftViewMode = UITextField.ViewMode.always
        
        let passwordLabel = UILabel(frame: CGRect(x: 37, y: usernameField.frame.maxY + 25, width: 100, height: 18))
        passwordLabel.text = "Password"
        passwordLabel.textColor = UIColor(named: "SpotGreen")
        passwordLabel.font = UIFont(name: "SFCamera-Semibold", size: 13)
        passwordLabel.sizeToFit()
        view.addSubview(passwordLabel)
        
        passwordField = UITextField(frame: CGRect(x: 28.5, y: passwordLabel.frame.maxY + 3, width: UIScreen.main.bounds.width - 57, height: 41))
        passwordField.layer.cornerRadius = 10
        passwordField.backgroundColor = UIColor(red:0.16, green:0.16, blue:0.16, alpha:0.5)
        passwordField.layer.borderColor = UIColor(red:0.21, green:0.21, blue:0.21, alpha:1).cgColor
        passwordField.layer.borderWidth = 1
        view.addSubview(passwordField)
        
        passwordField.text = signUpObject.password
        passwordField.isSecureTextEntry = true
        passwordField.textColor = UIColor.white
        passwordField.autocorrectionType = .no
        passwordField.autocapitalizationType = .none
        passwordField.font = UIFont(name: "SFCamera-regular", size: 16)!
        
        let passwordPad = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: self.passwordField.frame.height))
        passwordField.leftView = passwordPad
        passwordField.leftViewMode = UITextField.ViewMode.always
        
        let cityLabel = UILabel(frame: CGRect(x: 37, y: passwordField.frame.maxY + 25, width: 100, height: 18))
        cityLabel.text = "City"
        cityLabel.textColor = UIColor(named: "SpotGreen")
        cityLabel.font = UIFont(name: "SFCamera-Semibold", size: 13)
        cityLabel.sizeToFit()
        view.addSubview(cityLabel)
        
        cityField = UITextField(frame: CGRect(x: 28.5, y: cityLabel.frame.maxY + 3, width: UIScreen.main.bounds.width - 57, height: 41))
        cityField.layer.cornerRadius = 10
        cityField.backgroundColor = UIColor(red:0.16, green:0.16, blue:0.16, alpha:0.5)
        cityField.layer.borderColor = UIColor(red:0.21, green:0.21, blue:0.21, alpha:1).cgColor
        cityField.layer.borderWidth = 1
        view.addSubview(cityField)
        
        cityField.text = signUpObject.city
        cityField.textColor = UIColor.white
        cityField.autocorrectionType = .no
        cityField.autocapitalizationType = .words
        cityField.accessibilityHint = "phone"
        cityField.delegate = self
        cityField.textContentType = .telephoneNumber
        cityField.font = UIFont(name: "SFCamera-regular", size: 16)!
        
        let cityPad = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: self.cityField.frame.height))
        cityField.leftView = cityPad
        cityField.leftViewMode = UITextField.ViewMode.always
        
        nextButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 96, y: cityField.frame.maxY + 40, width: 192, height: 45))
        nextButton.setImage(UIImage(named: "OnboardNextButton"), for: .normal)
        nextButton.imageView?.contentMode = .scaleAspectFit
        nextButton.addTarget(self, action: #selector(nextTapped(_:)), for: .touchUpInside)
        view.addSubview(nextButton)
        
        errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 80, width: UIScreen.main.bounds.width, height: 32))
        errorBox.backgroundColor = UIColor(red:0.35, green:0, blue:0.04, alpha:1)
        view.addSubview(errorBox)
        errorBox.isHidden = true
        
        //Load error text
        errorTextLayer = UILabel(frame: CGRect(x: 23, y: UIScreen.main.bounds.height - 73, width: UIScreen.main.bounds.width - 46, height: 18))
        errorTextLayer.lineBreakMode = .byWordWrapping
        errorTextLayer.numberOfLines = 0
        errorTextLayer.textColor = UIColor.white
        errorTextLayer.textAlignment = .center
        errorTextLayer.font = UIFont(name: "SFCamera-regular", size: 14)
        errorTextLayer.text = "Invalid credentials, please try again."
        view.addSubview(errorTextLayer)
        errorTextLayer.isHidden = true
        //cityString
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        
        guard let stringRange = Range(range, in: currentText) else { return false }
        
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        
        if textField.accessibilityHint == "username" {
            return updatedText.count <= 16
        } else {
            return true
        }
    }
    
    @objc func backTapped(_ sender: UIButton){
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SignUp") as? SignUpViewController {
            vc.modalPresentationStyle = .fullScreen
            vc.signUpObject = self.signUpObject
            self.signUpObject.username = usernameField.text ?? ""
            self.signUpObject.password = passwordField.text ?? ""
            self.signUpObject.city = cityField.text ?? ""
            self.present(vc, animated: false, completion: nil)
        }
    }
    
    func addDotView(y: CGFloat) {
        let dotView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 16, y: y, width: 32, height: 10))
        dotView.backgroundColor = nil
        self.view.addSubview(dotView)
        
        let dot1 = UIImageView(frame: CGRect(x: 0, y: 0, width: 8, height: 8))
        dot1.layer.cornerRadius = 4
        dot1.image = UIImage(named: "ElipsesFilled")
        dotView.addSubview(dot1)
        
        let dot2 = UIImageView(frame: CGRect(x: 12, y: 0, width: 8, height: 8))
        dot2.layer.cornerRadius = 4
        dot2.image = UIImage(named: "ElipsesFilled")
        dotView.addSubview(dot2)
        
        let dot3 = UIImageView(frame: CGRect(x: 24, y: 0, width: 8, height: 8))
        dot3.layer.cornerRadius = 4
        dot3.image = UIImage(named: "ElipsesUnfilled")
        dotView.addSubview(dot3)
    }
    
    
    private func saveUserToFirebase(){
        let db = Firestore.firestore()
        
        guard let userId = Auth.auth().currentUser?.uid else{return}
        
        let tutorialList: [Bool] = [false, false, false, false, false, false]
        
        let botID = "T4KMLe3XlQaPBJvtZVArqXQvaNT2"
        
        var friendsList : [String] = []
        friendsList.append(botID)
        
        var city = signUpObject.city
        if city == "" {city = "sp0tw0rld, zy"}
        
        let values = ["name" : signUpObject.name,
                      "email" : signUpObject.email,
                      "username" : signUpObject.username,
                      "phone" : signUpObject.phone,
                      "userBio" : "",
                      "friendsList" :  friendsList,
                      "spotScore" : 0,
                      "admin" : false,
                      "lowercaseName:" : signUpObject.name.lowercased(),
                      "imageURL" :  "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2FProfileActive3x.png?alt=media&token=91e9cab9-70a8-4d31-9866-c3861c8b7b89",
                      "currentLocation" : signUpObject.city,
                      "tutorialList" : tutorialList,
            ] as [String : Any]
        
        db.collection("users").document(userId).setData(values, merge: true)
        
        let notiID = UUID().uuidString
        let acceptRef = db.collection("users").document(userId).collection("notifications").document(notiID)
        
        let timestamp = NSDate().timeIntervalSince1970
        let myTimeInterval = TimeInterval(timestamp)
        let time = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))
        
        acceptRef.setData(["status" : "accepted", "timestamp" : time, "senderID": "T4KMLe3XlQaPBJvtZVArqXQvaNT2", "type": "friendRequest", "seen": false])
        
        let ref = db.collection("users").document(botID)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let myDoc: DocumentSnapshot
            do {
                try myDoc = transaction.getDocument(ref)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            
            
            if var friendsList = myDoc.data()?["friendsList"] as? [String] {
                friendsList.append(userId)
                
                transaction.updateData([
                    "friendsList": friendsList
                ], forDocument: ref)
                return nil
            } else {
                return nil
            }
        }) { (object, error) in
            if let error = error {
                print("Transaction failed: \(error)")
            } else {
                print("Transaction successfully committed!")
            }
        }
    }
    @objc func nextTapped(_ sender: UIButton) {
        self.view.endEditing(true)

        guard var username = usernameField.text?.lowercased() else{return}
        username = username.trimmingCharacters(in: .whitespaces)
        guard let password = passwordField.text else{return}
        guard let city = cityField?.text else {return}
        
        if self.allFieldsComplete(username: username, password: password) {
            //avoid double tap
            nextButton.isUserInteractionEnabled = false

            let db = Firestore.firestore()
            
            signUpObject.username = username
            signUpObject.password = password
            signUpObject.city = city
            
            let usersRef = db.collection("usernames")
            let query = usersRef.whereField("username", isEqualTo: username)
            query.getDocuments(completion: { (snap, err) in
                print("ran query")
                if err != nil {
                    print (err?.localizedDescription as Any)
                    self.nextButton.isUserInteractionEnabled = true
                    return
                }
                if (snap?.documents.count)! > 0 {
                    self.errorBox.isHidden = false
                    self.errorTextLayer.isHidden = false
                    self.errorTextLayer.text = "Username already in use."
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                        guard let self = self else { return }
                        self.errorTextLayer.isHidden = true
                        self.errorBox.isHidden = true
                    }
                    self.nextButton.isUserInteractionEnabled = true
                    return
                }
           
            Auth.auth().createUser(withEmail: self.signUpObject.email, password: password){//authenticate user
                    user, error in
                    if error == nil && user != nil { //if no errors then create user
                        
                        self.saveUserToFirebase()
                        
                        let usernameID = UUID().uuidString
                        db.collection("usernames").document(usernameID).setData(["username" : username])
                      
                        self.nextButton.isUserInteractionEnabled = true

                        let sb = UIStoryboard(name: "Main", bundle: nil)
                        let vc = sb.instantiateViewController(withIdentifier: "SignUp3") as! SignUp3Controller
                        vc.modalPresentationStyle = .fullScreen
                        DispatchQueue.main.async {
                            self.present(vc, animated: false, completion: nil)
                        }
                        //Go to intro page
                    }else{
                        self.nextButton.isUserInteractionEnabled = true

                        print(error?.localizedDescription ?? "Sign-up Error")
                        
                        self.errorBox.isHidden = false
                        self.errorTextLayer.isHidden = false
                        self.errorTextLayer.text = "Create account error: your email may already be in use."
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                            guard let self = self else { return }
                            self.errorTextLayer.isHidden = true
                            self.errorBox.isHidden = true
                        }
                        
                    }
                }
            })
        }
    }
        
    private func allFieldsComplete(username: String, password: String) -> Bool {
        let whiteSpace = " "
        if (username.contains(whiteSpace)) {
            errorBox.isHidden = false
            errorTextLayer.isHidden = false
            errorTextLayer.text = "Please enter a valid username (no spaces)."
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self else { return }
                self.errorTextLayer.isHidden = true
                self.errorBox.isHidden = true
            }
            return false
            
        } else if username.isEmpty {
            errorBox.isHidden = false
            errorTextLayer.isHidden = false
            errorTextLayer.text = "Please enter a username."
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self else { return }
                self.errorTextLayer.isHidden = true
                self.errorBox.isHidden = true
            }
            return false
            
        } else if (!isValidUsername(username: username)) {
            errorBox.isHidden = false
            errorTextLayer.isHidden = false
            errorTextLayer.text = "Please enter a valid username (no special characters)."
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self else { return }
                self.errorTextLayer.isHidden = true
                self.errorBox.isHidden = true
            }
            return false
            
        } else if password.count < 6 {
            errorBox.isHidden = false
            errorTextLayer.isHidden = false
            errorTextLayer.text = "Please enter a valid password (6+ characters)"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self else { return }
                self.errorTextLayer.isHidden = true
                self.errorBox.isHidden = true
            }
            return false
        }
        return true
    }
    
}

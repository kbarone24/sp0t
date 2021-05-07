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

class UsernameController: UIViewController, UITextFieldDelegate {
    
    var usernameText = ""
    var usernameField: UITextField!
    var nextButton: UIButton!
    var statusIcon: UIImageView!
    var activityIndicator: CustomActivityIndicator!
    var errorBox: UIView!
    var errorLabel: UILabel!
    
    var newUser: NewUser!
    
        
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if usernameField != nil { usernameField.becomeFirstResponder() }
        Mixpanel.mainInstance().track(event: "SignUpUsernameOpen")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        navigationItem.title = "Create account"

        let backArrow = UIImage(named: "BackArrow")?.withRenderingMode(.alwaysOriginal)
        navigationController?.navigationBar.backIndicatorImage = backArrow
        navigationController?.navigationBar.backIndicatorTransitionMaskImage = backArrow
                
        let usernameLabel = UILabel(frame: CGRect(x: 50, y: 150, width: UIScreen.main.bounds.width - 100, height: 18))
        usernameLabel.text = "Pick your username!"
        usernameLabel.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        usernameLabel.font = UIFont(name: "SFCamera-Regular", size: 15)
        usernameLabel.textAlignment = .center
        view.addSubview(usernameLabel)
        
        usernameField = PaddedTextField(frame: CGRect(x: 60, y: usernameLabel.frame.maxY + 15, width: UIScreen.main.bounds.width - 120, height: 44))
        usernameField.backgroundColor = nil
        usernameField.textColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
        usernameField.autocorrectionType = .no
        usernameField.autocapitalizationType = .none
        usernameField.delegate = self
        usernameField.textAlignment = .center
        usernameField.font = UIFont(name: "SFCamera-Regular", size: 28)!
        usernameField.addTarget(self, action: #selector(usernameChanged(_:)), for: .editingChanged)
        view.addSubview(usernameField)
        
        statusIcon = UIImageView(frame: CGRect(x: usernameField.frame.maxX - 3, y: usernameField.frame.minY + 14, width: 20, height: 20))
        statusIcon.image = UIImage()
        view.addSubview(statusIcon)

        let bottomLine = UIView(frame: CGRect(x: 27, y: usernameField.frame.maxY + 5, width: UIScreen.main.bounds.width - 54, height: 1.25))
        bottomLine.layer.cornerRadius = 15
        bottomLine.backgroundColor = .white
        view.addSubview(bottomLine)
        
        nextButton = UIButton(frame: CGRect(x: (UIScreen.main.bounds.width - 217)/2, y: bottomLine.frame.maxY + 30, width: 217, height: 40))
        nextButton.alpha = 0.65
        nextButton.setImage(UIImage(named: "OnboardNextButton"), for: .normal)
        nextButton.addTarget(self, action: #selector(nextTapped(_:)), for: .touchUpInside)
        view.addSubview(nextButton)
        
        activityIndicator = CustomActivityIndicator(frame: CGRect(x: UIScreen.main.bounds.width/2 - 32, y: 98, width: 20, height: 20))
        activityIndicator.isHidden = true
        view.addSubview(activityIndicator)
        
        errorBox = UIView(frame: CGRect(x: 0, y: nextButton.frame.maxY + 30, width: UIScreen.main.bounds.width, height: 32))
        errorBox.backgroundColor = UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1)
        view.addSubview(errorBox)
        errorBox.isHidden = true
        
        errorLabel = UILabel(frame: CGRect(x: 23, y: 7, width: UIScreen.main.bounds.width - 46, height: 18))
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.numberOfLines = 0
        errorLabel.textColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.00)
        errorLabel.textAlignment = .center
        errorLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
        errorLabel.text = "Invalid credentials, please try again."
        errorBox.addSubview(errorLabel)
        errorLabel.isHidden = true
    }
    
    func setAvailable() {
        activityIndicator.stopAnimating()
        statusIcon.image = UIImage(named: "UsernameAvailable")
        nextButton.alpha = 1.0
    }
    
    func setUnavailable() {
        activityIndicator.stopAnimating()
        statusIcon.image = UIImage(named: "UsernameTaken")
        nextButton.alpha = 0.65
    }
    
    func setEmpty() {
        activityIndicator.stopAnimating()
        statusIcon.image = UIImage()
        nextButton.alpha = 0.65
    }
    
    /// max username = 16 char
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        
        guard let stringRange = Range(range, in: currentText) else { return false }
        
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        return updatedText.count <= 16
    }
    
    @objc func usernameChanged(_ sender: UITextField) {
        
        setEmpty()

        var lowercaseUsername = sender.text?.lowercased() ?? ""
        lowercaseUsername = lowercaseUsername.trimmingCharacters(in: .whitespaces)

        usernameText = lowercaseUsername
        if usernameText == "" { return }

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.runUsernameQuery), object: nil)
        self.perform(#selector(self.runUsernameQuery), with: nil, afterDelay: 0.4)
    }
    
    @objc func backTapped(_ sender: UIButton){
        self.navigationController?.popViewController(animated: true)
    }
        
    @objc func runUsernameQuery() {
        
        let localUsername = self.usernameText
        setEmpty()
        activityIndicator.startAnimating()
        
        usernameAvailable(username: localUsername) { (errorMessage) in
            
            if localUsername != self.usernameText { return } /// return if username field already changed
            
            if errorMessage != "" {
                self.setUnavailable()
            } else {
                self.setAvailable()
            }
        }
    }
    
    func usernameAvailable(username: String, completion: @escaping(_ err: String) -> Void) {
        
        if username == "" { completion("Invalid username"); return }
        if !isValidUsername(username: username) { completion("invalid username"); return }
        
        let db = Firestore.firestore()
        let usersRef = db.collection("usernames")
        let query = usersRef.whereField("username", isEqualTo: username)
        
        query.getDocuments(completion: { (snap, err) in

            if err != nil { completion("an error occurred"); return }
            if username != self.usernameText { completion("username already in use"); return }
            
            if (snap?.documents.count)! > 0 {
                completion("Username already in use")
            } else {
                completion("")
            }
        })
    }
    
    @objc func nextTapped(_ sender: UIButton) {
                
        self.view.endEditing(true)
        setEmpty()

        guard var username = usernameField.text?.lowercased() else { return }
        username = username.trimmingCharacters(in: .whitespaces)

        sender.isEnabled = false
        activityIndicator.startAnimating()
        
        /// check username status again on completion
        usernameAvailable(username: username) { (errorMessage) in
            
            if errorMessage != "" {
                
                Mixpanel.mainInstance().track(event: "SignUpUsernameError", properties: ["error": errorMessage])
                
                self.errorBox.isHidden = false
                self.errorLabel.isHidden = false
                self.errorLabel.text = errorMessage
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    guard let self = self else { return }
                    self.errorLabel.isHidden = true
                    self.errorBox.isHidden = true
                }
                
            } else {
                
                self.newUser.username = username
                
                if let vc = self.storyboard?.instantiateViewController(withIdentifier: "PhoneVC") as? PhoneController {
                    
                    Mixpanel.mainInstance().track(event: "SignUpUsernameSuccess")

                    vc.codeType = .newAccount
                    vc.newUser = self.newUser
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
            
            sender.isEnabled = true
            self.activityIndicator.stopAnimating()
        }
    }
}



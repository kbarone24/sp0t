//
//  ViewController.swift
//  Spot
//
//  Created by kbarone on 2/4/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import UIKit
import Firebase
import CoreLocation
import Mixpanel

class SignUpViewController: UIViewController, UITextFieldDelegate {
                
    var nameField: UITextField!
    var emailField: UITextField!
    var passwordField: UITextField!
    var nextButton: UIButton!

    var errorBox: UIView!
    var errorLabel: UILabel!
    var activityIndicator: CustomActivityIndicator!
        
    var newUser: NewUser!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "SignUp1Open")
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        navigationController?.navigationBar.setBackgroundImage(UIImage(color: UIColor(named: "SpotBlack")!), for: .default)
        
        navigationItem.title = "Create account"
        let backArrow = UIImage(named: "BackArrow")?.withRenderingMode(.alwaysOriginal)
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: backArrow, style: .plain, target: self, action: #selector(backTapped(_:)))
               
        newUser = NewUser(name: "", email: "", password: "", username: "", phone: "")
        
        let nameLabel = UILabel(frame: CGRect(x: 31, y: 40, width: 45, height: 12))
        nameLabel.text = "Name"
        nameLabel.textColor = UIColor(named: "SpotGreen")
        nameLabel.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        view.addSubview(nameLabel)
        
        nameField = PaddedTextField(frame: CGRect(x: 27, y: nameLabel.frame.maxY + 8, width: UIScreen.main.bounds.width - 54, height: 40))
        nameField.layer.cornerRadius = 7.5
        nameField.backgroundColor = UIColor.black
        nameField.layer.borderColor = UIColor(red: 0.158, green: 0.158, blue: 0.158, alpha: 1).cgColor
        nameField.layer.borderWidth = 1
        nameField.textColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.00)
        nameField.font = UIFont(name: "SFCamera-regular", size: 16)!
        nameField.autocorrectionType = .no
        nameField.autocapitalizationType = .words
        nameField.tag = 0
        nameField.delegate = self
        nameField.textContentType = .name
        nameField.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
        view.addSubview(nameField)

        let emailLabel = UILabel(frame: CGRect(x: 31, y: nameField.frame.maxY + 17, width: 40, height: 12))
        emailLabel.text = "Email"
        emailLabel.textColor = UIColor(named: "SpotGreen")
        emailLabel.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        view.addSubview(emailLabel)
        
        emailField = PaddedTextField(frame: CGRect(x: 27, y: emailLabel.frame.maxY + 8, width: UIScreen.main.bounds.width - 54, height: 40))
        emailField.layer.cornerRadius = 7.5
        emailField.backgroundColor = .black
        emailField.layer.borderColor = UIColor(red: 0.158, green: 0.158, blue: 0.158, alpha: 1).cgColor
        emailField.layer.borderWidth = 1
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        emailField.tag = 1
        emailField.delegate = self
        emailField.textColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.00)
        emailField.font = UIFont(name: "SFCamera-Regular", size: 16)!
        emailField.textContentType = .username
        emailField.keyboardType = .emailAddress
        emailField.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
        view.addSubview(emailField)

        let passwordLabel = UILabel(frame: CGRect(x: 31, y: emailField.frame.maxY + 17, width: 56, height: 12))
        passwordLabel.text = "Password"
        passwordLabel.textColor = UIColor(named: "SpotGreen")
        passwordLabel.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        view.addSubview(passwordLabel)
        
        //load username text field
        passwordField = PaddedTextField(frame: CGRect(x: 27, y: passwordLabel.frame.maxY + 8, width: UIScreen.main.bounds.width - 54, height: 40))
        passwordField.layer.cornerRadius = 7.5
        passwordField.backgroundColor = .black
        passwordField.layer.borderColor = UIColor(red: 0.158, green: 0.158, blue: 0.158, alpha: 1).cgColor
        passwordField.layer.borderWidth = 1
        passwordField.isSecureTextEntry = true
        passwordField.autocorrectionType = .no
        passwordField.autocapitalizationType = .none
        passwordField.tag = 2
        passwordField.delegate = self
        passwordField.textContentType = .newPassword
        passwordField.textColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.00)
        passwordField.font = UIFont(name: "SFCamera-Regular", size: 16)!
        passwordField.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
        view.addSubview(passwordField)

        nextButton = UIButton(frame: CGRect(x: (UIScreen.main.bounds.width - 217)/2, y: passwordField.frame.maxY + 22, width: 217, height: 40))
        nextButton.setImage(UIImage(named: "OnboardNextButton"), for: .normal)
        nextButton.addTarget(self, action: #selector(nextTapped(_:)), for: .touchUpInside)
        nextButton.alpha = 0.65
        view.addSubview(nextButton)
                
        let privacyNote = UITextView(frame: CGRect(x: (UIScreen.main.bounds.width - 252)/2, y: nextButton.frame.maxY + 50, width: 252, height: 50))
        privacyNote.backgroundColor = nil
        privacyNote.isEditable = false
        privacyNote.tintColor = UIColor(named: "SpotGreen")
        view.addSubview(privacyNote)
        
        let attString = NSMutableAttributedString(string: "By signing up, you are agreeing to sp0t’s privacy policy and terms of service")
        let termsRange = NSRange(location: attString.length - 16, length: 16)
        let totalRange = NSRange(location: 0, length: attString.length - 1)
        attString.addAttribute(.font, value: UIFont(name: "SFCamera-Semibold", size: 12)!, range: totalRange)
        
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment.center
        attString.addAttribute(.paragraphStyle, value: style, range: totalRange)
        
        attString.addAttribute(.foregroundColor, value: UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1), range: totalRange)
        attString.addAttribute(.link, value: "https://www.sp0t.app/legal", range: termsRange)
        attString.addAttribute(.foregroundColor, value: UIColor(named: "SpotGreen")!, range: termsRange)

        let privacyRange = NSRange(location: 42, length: 14)
        attString.addAttribute(.foregroundColor, value: UIColor(named: "SpotGreen")!, range: privacyRange)
        attString.addAttribute(.link, value: "https://www.sp0t.app/legal", range: privacyRange)

        privacyNote.attributedText = attString
        
        errorBox = UIView(frame: CGRect(x: 0, y: privacyNote.frame.maxY + 30, width: UIScreen.main.bounds.width, height: 32))
        errorBox.backgroundColor = UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1)
        view.addSubview(errorBox)
        errorBox.isHidden = true
        
        errorLabel = UILabel(frame: CGRect(x: 13, y: 7, width: UIScreen.main.bounds.width - 26, height: 18))
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.numberOfLines = 0
        errorLabel.textColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.00)
        errorLabel.textAlignment = .center
        errorLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
        errorLabel.text = "Invalid credentials, please try again."
        errorBox.addSubview(errorLabel)
        errorLabel.isHidden = true

        activityIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 165, width: UIScreen.main.bounds.width, height: 30))
        activityIndicator.isHidden = true 
        view.addSubview(activityIndicator)
    }
    
    @objc func textChanged(_ sender: UITextView) {
        let message = allFieldsComplete(name: nameField.text ?? "", email: emailField.text ?? "", password: passwordField.text ?? "")
        nextButton.alpha = message == "" ? 1.0 : 0.65
    }
        
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        UIApplication.shared.open(URL)
        return false
    }
  
    /// limit name field to 25 characters
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        
        guard let stringRange = Range(range, in: currentText) else { return false }
        
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        
        if textField.tag == 0 {
            return updatedText.count <= 25
        } else {
            return true
        }
    }
    
    @objc func backTapped(_ sender: UIButton) {
        self.dismiss(animated: false, completion: nil)
    }
        
    @objc func nextTapped(_ sender: UIButton){
        
        self.view.endEditing(true)

        //gets the text values from the text boxes
        guard let name = nameField.text else { return }
        guard let email = emailField.text?.trimmingCharacters(in: .whitespaces) else { return }
        guard let password = passwordField.text else { return }
        
        //Checks to see if there is text field without text entered into it
        
        let errorMessage = self.allFieldsComplete(name: name, email: email, password: password)
        
        if errorMessage == "" {
            
            activityIndicator.startAnimating()
            sender.isEnabled = false
            
            Auth.auth().fetchSignInMethods(forEmail: email, completion: {
                (providers, error) in
                
                self.activityIndicator.stopAnimating()
                sender.isEnabled = true
                
                if let error = error {
                    print(error.localizedDescription)
                    
                } else if providers != nil {
                    
                    Mixpanel.mainInstance().track(event: "SignUp1EmailInUse")
                    
                    self.errorBox.isHidden = false
                    self.errorLabel.isHidden = false
                    self.errorLabel.text = "Email already in use."
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                        guard let self = self else { return }
                        self.errorLabel.isHidden = true
                        self.errorBox.isHidden = true
                    }
                    return
                    
                } else {
                    
                    self.newUser.name = name
                    self.newUser.email = email
                    self.newUser.password = password
                    
                    if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "UsernameVC") as? UsernameController {
                        
                        Mixpanel.mainInstance().track(event: "SignUp1Success")
                        vc.newUser = self.newUser
                        self.navigationController?.pushViewController(vc, animated: true)
                    }
                }
            })
            
        } else {
            
            Mixpanel.mainInstance().track(event: "SignUp1InvalidFields", properties: ["error": errorMessage])

            errorBox.isHidden = false
            errorLabel.isHidden = false
            errorLabel.text = errorMessage
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self else { return }
                self.errorLabel.isHidden = true
                self.errorBox.isHidden = true
            }
        }
    }
    
    //add new user's account to firestore w/ uid key and name,email,username value pairs
    
    
    //Function checks to see if text is entered into all fields
    private func allFieldsComplete(name: String, email: String, password: String) -> String {
        
        var errorMessage = ""
        
        if name.isEmpty {
            errorMessage = "Please complete all fields."
            
        } else if !isValidEmail(email: email){
            errorMessage = "Please enter a valid email."

        } else if password.count < 6 {
            errorMessage = "Please enter a valid password (6+ characters)"
        }

        return errorMessage
    }
    
    func termsTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "SignUp1TermsTap")
        if let url = URL(string: "https://www.sp0t.app/legal") {
            UIApplication.shared.open(url)
        }
    }
    
    //Hide keyboard when user touches screen
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
}

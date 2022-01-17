//
//  LoginViewController.swift
//  Spot
//
//  Created by kbarone on 2/13/19.
//   Copyright © 2019 sp0t, LLC. All rights reserved.
//

import UIKit
import Firebase
import Mixpanel

//This file controls the loginView
class EmailLoginController: UIViewController {
        
    var emailField: UITextField!
    var passwordField: UITextField!
    var loginButton: UIButton!
    
    var errorBox: UIView!
    var errorLabel: UILabel!
    var activityIndicator: CustomActivityIndicator!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if emailField != nil { emailField.becomeFirstResponder() }
        Mixpanel.mainInstance().track(event: "LoginOpen")
    }
        
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        navigationController?.navigationBar.setBackgroundImage(UIImage(color: UIColor(named: "SpotBlack")!), for: .default)
        
        navigationItem.title = "Log in"
        let backArrow = UIImage(named: "BackArrow")?.withRenderingMode(.alwaysOriginal)
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: backArrow, style: .plain, target: self, action: #selector(backTapped(_:)))
        
        let emailLabel = UILabel(frame: CGRect(x: 31, y: 40, width: 40, height: 12))
        emailLabel.text = "Email"
        emailLabel.textColor = UIColor(named: "SpotGreen")
        emailLabel.font = UIFont(name: "SFCompactText-Regular", size: 12.5)
        view.addSubview(emailLabel)
        
        emailField = PaddedTextField(frame: CGRect(x: 27, y: emailLabel.frame.maxY + 8, width: UIScreen.main.bounds.width - 54, height: 40))
        emailField.layer.cornerRadius = 7.5
        emailField.backgroundColor = .black
        emailField.layer.borderColor = UIColor(red: 0.158, green: 0.158, blue: 0.158, alpha: 1).cgColor
        emailField.layer.borderWidth = 1
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        emailField.tag = 1
        emailField.textColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.00)
        emailField.font = UIFont(name: "SFCompactText-Regular", size: 16)!
        emailField.textContentType = .username
        emailField.keyboardType = .emailAddress
        view.addSubview(emailField)
        
        let passwordLabel = UILabel(frame: CGRect(x: 31, y: emailField.frame.maxY + 17, width: 56, height: 12))
        passwordLabel.text = "Password"
        passwordLabel.textColor = UIColor(named: "SpotGreen")
        passwordLabel.font = UIFont(name: "SFCompactText-Regular", size: 12.5)
        view.addSubview(passwordLabel)

        passwordField = PaddedTextField(frame: CGRect(x: 27, y: passwordLabel.frame.maxY + 8, width: UIScreen.main.bounds.width - 54, height: 40))
        passwordField.layer.cornerRadius = 7.5
        passwordField.backgroundColor = .black
        passwordField.layer.borderColor = UIColor(red: 0.158, green: 0.158, blue: 0.158, alpha: 1).cgColor
        passwordField.layer.borderWidth = 1
        passwordField.isSecureTextEntry = true
        passwordField.autocorrectionType = .no
        passwordField.autocapitalizationType = .none
        passwordField.tag = 2
        passwordField.textContentType = .password
        passwordField.textColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.00)
        passwordField.font = UIFont(name: "SFCompactText-Regular", size: 16)!
        passwordField.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
        view.addSubview(passwordField)
        
        let forgotPasswordButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 80, y: passwordField.frame.maxY + 20, width: 160, height: 21))
        forgotPasswordButton.setTitle("Forgot password?", for: .normal)
        forgotPasswordButton.setTitleColor(UIColor(red:0.78, green:0.78, blue:0.78, alpha:1.00), for: .normal)
        forgotPasswordButton.titleLabel?.textAlignment = .center
        forgotPasswordButton.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 14)
        forgotPasswordButton.addTarget(self, action: #selector(handleForgotPwd(_:)), for: .touchUpInside)
        view.addSubview(forgotPasswordButton)
        
        //Load 'LOG IN' button background
        loginButton = UIButton(frame: CGRect(x: (UIScreen.main.bounds.width - 217)/2, y: forgotPasswordButton.frame.maxY + 22, width: 217, height: 40))
        loginButton.setImage(UIImage(named: "LoginButton"), for: UIControl.State.normal)
        loginButton.imageView?.contentMode = .scaleAspectFit
        loginButton.alpha = 0.65
        loginButton.addTarget(self, action: #selector(handleLogin(_:)), for: .touchUpInside)
        view.addSubview(loginButton)
        
        errorBox = UIView(frame: CGRect(x: 0, y: loginButton.frame.maxY + 30, width: UIScreen.main.bounds.width, height: 45))
        errorBox.backgroundColor = UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1)
        view.addSubview(errorBox)
        errorBox.isHidden = true
        
        errorLabel = UILabel(frame: CGRect(x: 13, y: 5, width: UIScreen.main.bounds.width - 26, height: 18))
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.numberOfLines = 0
        errorLabel.textColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.00)
        errorLabel.textAlignment = .center
        errorLabel.font = UIFont(name: "SFCompactText-Regular", size: 14)
        errorLabel.text = "Invalid login. Double check your email and password and try again."
        errorLabel.sizeToFit()
        errorBox.addSubview(errorLabel)
        errorLabel.isHidden = true

        activityIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 165, width: UIScreen.main.bounds.width, height: 30))
        activityIndicator.isHidden = true
        view.addSubview(activityIndicator)
    }
        

    @objc func textChanged(_ sender: UITextView) {
        loginButton.alpha = allFieldsComplete(email: emailField.text ?? "", password: passwordField.text ?? "") ? 1.0 : 0.65
    }
    
    @objc func backTapped(_ sender: UIButton){
        self.dismiss(animated: false, completion: nil)
    }
    
    @objc func handleLogin(_ sender: UIButton){
        self.view.endEditing(true)

        guard let email = emailField.text else { return }
        guard let password = passwordField.text else { return }
        loginButton.isEnabled = false
        activityIndicator.startAnimating()
        
        //Authenticate login information
        Auth.auth().signIn(withEmail: email, password: password) { (user, error) in
            
            if error == nil && user != nil {//if no errors then allow login
                
                Mixpanel.mainInstance().track(event: "LoginSuccessful")
                self.errorBox.isHidden = true
                self.errorLabel.isHidden = true
                
                /// check to make sure user has 2 factor enabled
                self.checkForPhoneAuth(email: email)
                
            } else {
                Mixpanel.mainInstance().track(event: "LoginUnsuccessful")
                self.showErrorMessage(message: "Invalid login. Double check your email and password and try again.")
            }
        }
    }
    
    func showErrorMessage(message: String) {
        
        self.loginButton.isEnabled = true
        self.errorBox.isHidden = false
        self.errorLabel.isHidden = false
        self.errorLabel.text = message
        self.activityIndicator.stopAnimating()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            self.errorLabel.isHidden = true
            self.errorBox.isHidden = true
        }
    }
    
    func checkForPhoneAuth(email: String) {
        
        let defaults = UserDefaults.standard
        let verified = defaults.object(forKey: "verifiedPhone") as? Bool ?? false
        
        if verified {
            animateToMap()
            
        } else {
            
            let db = Firestore.firestore()
            let verifiedEmail = Auth.auth().currentUser?.email ?? ""
            
            db.collection("users").whereField("email", isEqualTo: Auth.auth().currentUser?.email ?? "").getDocuments { (snap, err) in
                if let doc = snap?.documents.first {
                    /// if user is verified but its not already saved to defaults, save it to defaults and send them to the map
                    let verified = doc.get("verifiedPhone") as? Bool ?? false
                    print("verified", verified)
                    if verified {
                        defaults.set(true, forKey: "verifiedPhone")
                        self.animateToMap()
                    } else {
                        self.sendUserToPhoneAuth()
                    }
                    
                } else {
                    /// this should never happen but user got signed in and their email in Firestore does not match the user in Auth. Here we update their email with the current one
                    
                    if verifiedEmail != "" { db.collection("users").document(Auth.auth().currentUser!.uid).updateData(["email" : verified])}
                    self.sendUserToPhoneAuth()
                }
            }
        }
    }
    
    func sendUserToPhoneAuth() {

        self.loginButton.isEnabled = true
        self.activityIndicator.stopAnimating()

        /// send user to phone auth if multifactor isn't enabled
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PhoneVC") as? PhoneController {
            vc.codeType = .multifactor
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func animateToMap() {
        
        self.loginButton.isEnabled = true
        self.activityIndicator.stopAnimating()

        /// animate to app if user has enabled multifactor
        let storyboard = UIStoryboard(name: "TabBar", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MapView") as! MapViewController
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
    
    
    @objc func handleForgotPwd(_ sender: UIButton){
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ForgotPassword") as? ResetViewController {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    private func allFieldsComplete(email: String, password: String) -> Bool {
        return isValidEmail(email: email) && password.count > 5
    }

    
}

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
class LoginViewController: UIViewController {
    
    //Change status bar theme color white
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    //Initializes text field variables
    var emailField: UITextField!
    var pwdField: UITextField!
    var errorBox: UIView!
    var errorTextLayer: UILabel!
    var loginBtn: UIButton!
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        var heightAdjust: CGFloat = 0
        if (!(UIScreen.main.nativeBounds.height > 2300 || UIScreen.main.nativeBounds.height == 1792)) {
            heightAdjust = 20
        }
        
        self.view.backgroundColor = UIColor(named: "SpotBlack")
        
        //Load Spot Logo
        let logoImage = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 45, y: 52 - heightAdjust, width: 90, height: 36))
        logoImage.image = UIImage(named: "MapSp0tLogo")
        logoImage.contentMode = .scaleAspectFit
        view.addSubview(logoImage)
        
        
        let sloganLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 75, y: logoImage.frame.maxY + 3, width: 150, height: 17))
        sloganLabel.text = "where places live"
        sloganLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
        sloganLabel.textColor = .white
        sloganLabel.textAlignment = .center
        view.addSubview(sloganLabel)
        
        let arrow = UIButton(frame: CGRect(x: 0, y: 50 - heightAdjust, width: 40, height: 40))
        arrow.setImage(UIImage(named: "BackButton"), for: .normal)
        arrow.addTarget(self, action: #selector(backTapped(_:)), for: .touchUpInside)
        view.addSubview(arrow)
        
        let loginLabel = UILabel(frame: CGRect(x: 32, y: sloganLabel.frame.maxY + 30, width: 100, height: 31))
        loginLabel.text = "Log in"
        loginLabel.font = UIFont(name: "SFCamera-Semibold", size: 22)
        loginLabel.textColor = UIColor(red:0.64, green:0.64, blue:0.64, alpha:1.00)
        loginLabel.sizeToFit()
        self.view.addSubview(loginLabel)
        
        let emailLabel = UILabel(frame: CGRect(x: 37, y: loginLabel.frame.maxY + 23, width: 100, height: 18))
        emailLabel.text = "Email"
        emailLabel.textColor = UIColor(named: "SpotGreen")
        emailLabel.font = UIFont(name: "SFCamera-Semibold", size: 13)
        emailLabel.sizeToFit()
        self.view.addSubview(emailLabel)
        
        //load email text field
        emailField = UITextField(frame: CGRect(x: 28.5, y: emailLabel.frame.maxY + 3, width: UIScreen.main.bounds.width - 57, height: 41))
        emailField.layer.cornerRadius = 10
        emailField.backgroundColor = UIColor(red:0.16, green:0.16, blue:0.16, alpha:0.5)
        emailField.layer.borderColor = UIColor(red:0.21, green:0.21, blue:0.21, alpha:1).cgColor
        emailField.layer.borderWidth = 1
        self.view.addSubview(emailField)
        
        emailField.textColor = UIColor.white
        emailField.font = UIFont(name: "SFCamera-regular", size: 16)!
        emailField.autocorrectionType = .no
        emailField.autocapitalizationType = .none
        emailField.textContentType = .username
        emailField.keyboardType = .emailAddress
        
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: self.emailField.frame.height))
        emailField.leftView = paddingView
        emailField.leftViewMode = UITextField.ViewMode.always
        
        let passwordLabel = UILabel(frame: CGRect(x: 37, y: emailField.frame.maxY + 23, width: 100, height: 18))
        passwordLabel.text = "Password"
        passwordLabel.textColor = UIColor(named: "SpotGreen")
        passwordLabel.font = UIFont(name: "SFCamera-Semibold", size: 13)
        passwordLabel.sizeToFit()
        self.view.addSubview(passwordLabel)
        
        
        //load password text field
        
        pwdField = UITextField(frame: CGRect(x: 28.5, y: passwordLabel.frame.maxY + 3, width: UIScreen.main.bounds.width - 57, height: 41))
        pwdField.layer.cornerRadius = 10
        pwdField.backgroundColor = UIColor(red:0.16, green:0.16, blue:0.16, alpha:0.5)
        pwdField.layer.borderColor = UIColor(red:0.21, green:0.21, blue:0.21, alpha:1).cgColor
        pwdField.layer.borderWidth = 1
        self.view.addSubview(pwdField)
        
        pwdField.isSecureTextEntry = true
        pwdField.textColor = UIColor.white
        pwdField.font = UIFont(name: "SFCamera-regular", size: 16)!
        pwdField.autocorrectionType = .no
        pwdField.autocapitalizationType = .none
        pwdField.textContentType = .password
        
        let pwdPad = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: self.pwdField.frame.height))
        pwdField.leftView = pwdPad
        pwdField.leftViewMode = UITextField.ViewMode.always
        
        let forgotPasswordButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 80, y: pwdField.frame.maxY + 23, width: 160, height: 21))
        forgotPasswordButton.setTitle("Forgot password?", for: .normal)
        forgotPasswordButton.setTitleColor(UIColor(red:0.78, green:0.78, blue:0.78, alpha:1.00), for: .normal)
        forgotPasswordButton.titleLabel?.textAlignment = .center
        forgotPasswordButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 16)
        forgotPasswordButton.addTarget(self, action: #selector(handleForgotPwd(_:)), for: .touchUpInside)
        view.addSubview(forgotPasswordButton)
        
        //Load 'LOG IN' button background
        loginBtn = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 96, y: forgotPasswordButton.frame.maxY + 52, width: 192, height: 45))
        loginBtn.setImage(UIImage(named: "LoginButton"), for: UIControl.State.normal)
        loginBtn.imageView?.contentMode = .scaleAspectFit
        loginBtn.addTarget(self, action: #selector(handleLogin(_:)), for: .touchUpInside)
        view.addSubview(loginBtn)
        
        //load Error box
        errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 80, width: UIScreen.main.bounds.width, height: 32))
        errorBox.backgroundColor = UIColor(red:0.35, green:0, blue:0.04, alpha:1)
        self.view.addSubview(errorBox)
        errorBox.isHidden = true
        
        //Load error text
        errorTextLayer = UILabel(frame: CGRect(x: 23, y: UIScreen.main.bounds.height - 73, width: UIScreen.main.bounds.width - 46, height: 18))
        errorTextLayer.lineBreakMode = .byWordWrapping
        errorTextLayer.numberOfLines = 0
        errorTextLayer.textColor = UIColor.white
        errorTextLayer.textAlignment = .center
        errorTextLayer.text = "Login failed, please try again."
        errorTextLayer.font = UIFont(name: "SFCamera-regular", size: 14)
        self.view.addSubview(errorTextLayer)
        errorTextLayer.isHidden = true
        
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(false)
        Mixpanel.mainInstance().track(event: "LoginOpen")
    }
    
    @objc func backTapped(_ sender: UIButton){
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "LandingPage") as? LandingPageController {
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }
    
    @objc func handleForgotPwd(_ sender: UIButton){
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ForgotPassword") as? ResetViewController {
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: false, completion: nil)
        }
        
    }
    
    @objc func handleLogin(_ sender: UIButton){
        self.view.endEditing(true)

        guard let email = emailField.text else{return}
        guard let password = pwdField.text else{return}
        self.loginBtn.isEnabled = false
        
        //Authenticate login information
        Auth.auth().signIn(withEmail: email, password: password) { (user, error) in
            
            if error == nil && user != nil {//if no errors then allow login
                
                self.errorBox.isHidden = true
                self.errorTextLayer.isHidden = true
                
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

            } else {
                self.loginBtn.isEnabled = true
                self.errorBox.isHidden = false
                self.errorTextLayer.isHidden = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    guard let self = self else { return }
                    self.errorTextLayer.isHidden = true
                    self.errorBox.isHidden = true
                }
            }
            
        }
    }
    
    //Hide keyboard when user touches screen
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
}

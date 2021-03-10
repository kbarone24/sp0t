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
    
    //Change status bar theme color white
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    private let locationManager = CLLocationManager()
    
    var scrollView: UIScrollView!
    
    var nameField: UITextField!
    var emailField: UITextField!
    var phoneField: UITextField!
    var errorBox: UIView!
    var errorTextLayer: UILabel!
    
    var nextButton: UIButton!
        
    var signUpObject: (name: String, email: String, phone: String, username: String, password: String, city: String) = ("", "", "", "", "", "")
    
    var authListener: AuthStateDidChangeListenerHandle?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "SignUp1Open")
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
        
        //Load 'name' label
        let nameLabel = UILabel(frame: CGRect(x: 37, y: createText.frame.maxY + 43, width: 100, height: 18))
        nameLabel.text = "Name"
        nameLabel.textColor = UIColor(named: "SpotGreen")
        nameLabel.font = UIFont(name: "SFCamera-Semibold", size: 13)
        nameLabel.sizeToFit()
        view.addSubview(nameLabel)
        
        //Load 'name' text field
        nameField = UITextField(frame: CGRect(x: 28.5, y: nameLabel.frame.maxY + 3, width: UIScreen.main.bounds.width - 57, height: 41))
        nameField.layer.cornerRadius = 10
        nameField.backgroundColor = UIColor(red:0.16, green:0.16, blue:0.16, alpha:0.5)
        nameField.layer.borderColor = UIColor(red:0.21, green:0.21, blue:0.21, alpha:1).cgColor
        nameField.layer.borderWidth = 1
        view.addSubview(nameField)
        
        nameField.text = signUpObject.name
        nameField.textColor = UIColor.white
        nameField.font = UIFont(name: "SFCamera-regular", size: 16)!
        nameField.autocorrectionType = .no
        nameField.autocapitalizationType = .words
        nameField.accessibilityHint = "name"
        nameField.delegate = self
        nameField.textContentType = .name
        
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: self.nameField.frame.height))
        nameField.leftView = paddingView
        nameField.leftViewMode = UITextField.ViewMode.always
        
        //Load email label
        let emailLabel = UILabel(frame: CGRect(x: 37, y: nameField.frame.maxY + 25, width: 100, height: 18))
        emailLabel.text = "Email"
        emailLabel.textColor = UIColor(named: "SpotGreen")
        emailLabel.font = UIFont(name: "SFCamera-Semibold", size: 13)
        emailLabel.sizeToFit()
        view.addSubview(emailLabel)
        
        
        //load email text field
        
        emailField = UITextField(frame: CGRect(x: 28.5, y: emailLabel.frame.maxY + 3, width: UIScreen.main.bounds.width - 57, height: 41))
        emailField.layer.cornerRadius = 10
        emailField.backgroundColor = UIColor(red:0.16, green:0.16, blue:0.16, alpha:0.5)
        emailField.layer.borderColor = UIColor(red:0.21, green:0.21, blue:0.21, alpha:1).cgColor
        emailField.layer.borderWidth = 1
        view.addSubview(emailField)
        
        emailField.text = signUpObject.email
        emailField.textColor = UIColor.white
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        emailField.font = UIFont(name: "SFCamera-regular", size: 16)!
        emailField.textContentType = .emailAddress
        emailField.keyboardType = .emailAddress
        
        let emailPad = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: self.emailField.frame.height))
        emailField.leftView = emailPad
        emailField.leftViewMode = UITextField.ViewMode.always
        
        //load username label
        let phoneNumber = UILabel(frame: CGRect(x: 37, y: emailField.frame.maxY + 25, width: 100, height: 18))
        phoneNumber.text = "Phone #"
        phoneNumber.textColor = UIColor(named: "SpotGreen")
        phoneNumber.font = UIFont(name: "SFCamera-Semibold", size: 13)
        phoneNumber.sizeToFit()
        view.addSubview(phoneNumber)
        
        
        //load username text field
        phoneField = UITextField(frame: CGRect(x: 28.5, y: phoneNumber.frame.maxY + 3, width: UIScreen.main.bounds.width - 57, height: 41))
        phoneField.layer.cornerRadius = 10
        phoneField.backgroundColor = UIColor(red:0.16, green:0.16, blue:0.16, alpha:0.5)
        phoneField.layer.borderColor = UIColor(red:0.21, green:0.21, blue:0.21, alpha:1).cgColor
        phoneField.layer.borderWidth = 1
        view.addSubview(phoneField)
        
        phoneField.text = signUpObject.phone
        phoneField.textColor = UIColor.white
        phoneField.autocorrectionType = .no
        phoneField.autocapitalizationType = .none
        phoneField.accessibilityHint = "phone"
        phoneField.delegate = self
        phoneField.textContentType = .telephoneNumber
        phoneField.keyboardType = UIKeyboardType.numberPad
        phoneField.font = UIFont(name: "SFCamera-regular", size: 16)!
        
        let phonePad = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: self.phoneField.frame.height))
        phoneField.leftView = phonePad
        phoneField.leftViewMode = UITextField.ViewMode.always
        
        //load username text field
        
        //Load 'Go' button background
        nextButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 96, y: phoneField.frame.maxY + 40, width: 192, height: 45))
        nextButton.setImage(UIImage(named: "OnboardNextButton"), for: .normal)
        nextButton.imageView?.contentMode = .scaleAspectFit
        nextButton.addTarget(self, action: #selector(nextTapped(_:)), for: .touchUpInside)
        view.addSubview(nextButton)
        
        
        //load Error box
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
        dot2.image = UIImage(named: "ElipsesUnfilled")
        dotView.addSubview(dot2)
        
        let dot3 = UIImageView(frame: CGRect(x: 24, y: 0, width: 8, height: 8))
        dot3.layer.cornerRadius = 4
        dot3.image = UIImage(named: "ElipsesUnfilled")
        dotView.addSubview(dot3)
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        
        guard let stringRange = Range(range, in: currentText) else { return false }
        
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        
        if textField.accessibilityHint == "name" {
            return updatedText.count <= 25
        } else {
            return true
        }
    }
    
    @objc func backTapped(_ sender: UIButton){
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "LandingPage") as? LandingPageController {
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }
    
    
    @objc func nextTapped(_ sender: UIButton){        self.view.endEditing(true)

        //gets the text values from the text boxes
        guard let name = nameField.text else{return}
        guard let email = emailField.text?.trimmingCharacters(in: .whitespaces) else{return}
        guard var number = phoneField.text?.trimmingCharacters(in: .whitespaces) else {return}
        var temp = ""
        for num in number {
            if num == "-" || num == " " || num == "(" || num == ")" {
                continue
            } else {
                temp.append(num)
            }
        }
        number = temp
        
        //Checks to see if there is text field without text entered into it
        
        if (self.allFieldsComplete(name: name, email: email, number: number)){
            Auth.auth().fetchSignInMethods(forEmail: email, completion: {
                (providers, error) in
                if let error = error {
                    print(error.localizedDescription)
                } else if providers != nil {
                    self.errorBox.isHidden = false
                    self.errorTextLayer.isHidden = false
                    self.errorTextLayer.text = "Email already in use."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                        guard let self = self else { return }
                        self.errorTextLayer.isHidden = true
                        self.errorBox.isHidden = true
                    }
                    return
                } else {
                    if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SignUp2") as? SignUp2Controller {
                        vc.signUpObject.name = name
                        vc.signUpObject.email = email
                        vc.signUpObject.phone = number
                        vc.modalPresentationStyle = .fullScreen
                        self.present(vc, animated: false, completion: nil)
                    }
                }
            })
            
        }
        
    }
    
    //add new user's account to firestore w/ uid key and name,email,username value pairs
    
    
    //Function checks to see if text is entered into all fields
    private func allFieldsComplete(name:String, email:String, number:String) -> Bool{
        errorBox.isHidden = true
        errorTextLayer.isHidden = true
        if name.isEmpty{
            errorBox.isHidden = false
            errorTextLayer.isHidden = false
            errorTextLayer.text = "Please enter your name."
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self else { return }
                self.errorTextLayer.isHidden = true
                self.errorBox.isHidden = true
            }
            return false
        }
        
        if !isValidEmail(email: email){
            errorBox.isHidden = false
            errorTextLayer.isHidden = false
            errorTextLayer.text = "Please enter a valid email."
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self else { return }
                self.errorTextLayer.isHidden = true
                self.errorBox.isHidden = true
            }
            return false;
        } else if number.count < 10 {
            errorBox.isHidden = false
            errorTextLayer.isHidden = false
            errorTextLayer.text = "Please enter a valid phone number."
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self else { return }
                self.errorTextLayer.isHidden = true
                self.errorBox.isHidden = true
            }
            return false
        } else {
            for num in number {
                if !num.isNumber {
                    errorBox.isHidden = false
                    errorTextLayer.isHidden = false
                    errorTextLayer.text = "Please enter a valid phone number."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                        guard let self = self else { return }
                        self.errorTextLayer.isHidden = true
                        self.errorBox.isHidden = true
                    }
                    return false
                }
            }
        }
        return true
    }
    
    //checks to see if valid email is entered
    func isValidEmail(email:String?) -> Bool {
        guard email != nil else { return false }
        let regEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let pred = NSPredicate(format:"SELF MATCHES %@", regEx)
        return pred.evaluate(with: email)
    }
    
    
    //Hide keyboard when user touches screen
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
}

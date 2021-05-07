//
//  SignUp3Controller.swift
//  Spot
//
//  Created by kbarone on 4/9/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel

enum CodeType {
    case newAccount
    case multifactor
    case logIn
}

class PhoneController: UIViewController {
    
    var root = false
    var newUser: NewUser!
    var country: CountryCode!

    var label: UILabel!
    var phoneField: UITextField!
    var countryCodeView: CountryCodeView!
    var paddingView: UIView!
    var sendButton: UIButton!
    
    var activityIndicator: CustomActivityIndicator!
    var errorBox: UIView!
    var errorLabel: UILabel!
    var codeType: CodeType!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "PhoneOpen")
        if phoneField != nil { phoneField.becomeFirstResponder() }
    }
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        navigationItem.title = codeType == .newAccount ? "Create account" : "Log in"

        let backArrow = UIImage(named: "BackArrow")?.withRenderingMode(.alwaysOriginal)
        
        /// log in isnt stacked on anything - presented directly form landing page
        if navigationController?.viewControllers.count ?? 0 == 1 {
            
            navigationController?.navigationBar.setBackgroundImage(UIImage(color: UIColor(named: "SpotBlack")!), for: .default)
            let action = !root ? #selector(backTapped(_:)) : #selector(rootBackTapped(_:))
            navigationItem.leftBarButtonItem = UIBarButtonItem(image: backArrow, style: .plain, target: self, action: action)

        } else {
            navigationController?.navigationBar.backIndicatorImage = backArrow
            navigationController?.navigationBar.backIndicatorTransitionMaskImage = backArrow
        }

        country = CountryCode(id: 224, code: "+1", name: "United States")
        
        let labelText = codeType == .newAccount ? "Almost done! \n We need your phone # to verify your account" : codeType == .multifactor ? "Verify your phone number:" : ""
        let minX: CGFloat = codeType == .multifactor ? 27 : 10
        
        label = UILabel(frame: CGRect(x: minX, y: 120, width: UIScreen.main.bounds.width - 20, height: 36))
        label.text = labelText
        label.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        label.font = UIFont(name: "SFCamera-Regular", size: 15)
        label.textAlignment = codeType == .newAccount ? .center : .left
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        view.addSubview(label)
        
        phoneField = UITextField(frame: CGRect(x: 27, y: label.frame.maxY + 22, width: UIScreen.main.bounds.width - 54, height: 60))
        phoneField.backgroundColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
        phoneField.font = UIFont(name: "SFCamera-Semibold", size: 28)
        phoneField.textAlignment = .left
        phoneField.tintColor = UIColor(named: "SpotGreen")
        phoneField.textColor = .black
        phoneField.layer.cornerRadius = 15
        phoneField.layer.borderWidth = 1
        phoneField.layer.borderColor = UIColor(red: 0.158, green: 0.158, blue: 0.158, alpha: 1).cgColor
        phoneField.textContentType = .telephoneNumber
        phoneField.keyboardType = .numberPad
        phoneField.addTarget(self, action: #selector(phoneNumberChanged(_:)), for: .editingChanged)
        view.addSubview(phoneField)
        
        /// country code overlaps with left portion of phoneField
        countryCodeView = CountryCodeView(frame: CGRect(x: phoneField.frame.minX + 10, y: phoneField.frame.minY + 8, width: 130, height: 40))
        countryCodeView.setUp(country: country)
        let tap = UITapGestureRecognizer(target: self, action: #selector(openCountryPicker(_:)))
        countryCodeView.addGestureRecognizer(tap)
        countryCodeView.frame = CGRect(x: countryCodeView.frame.minX, y: countryCodeView.frame.minY, width: countryCodeView.separatorLine.frame.maxX + 10, height: countryCodeView.frame.height)
        view.addSubview(countryCodeView)
                
        paddingView = UIView(frame: CGRect(x: 0, y: 0, width: countryCodeView.bounds.width + 10, height: phoneField.frame.height))
        phoneField.leftView = paddingView
        phoneField.leftViewMode = UITextField.ViewMode.always

        sendButton = UIButton(frame: CGRect(x: (UIScreen.main.bounds.width - 217)/2, y: phoneField.frame.maxY + 32, width: 217, height: 40))
        sendButton.alpha = 0.65
        sendButton.setImage(UIImage(named: "SendCodeButton"), for: .normal)
        sendButton.addTarget(self, action: #selector(sendCode(_:)), for: .touchUpInside)
        view.addSubview(sendButton)
                
        errorBox = UIView(frame: CGRect(x: 0, y: sendButton.frame.maxY + 30, width: UIScreen.main.bounds.width, height: 32))
        errorBox.backgroundColor = UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1)
        errorBox.isHidden = true
        view.addSubview(errorBox)
        
        errorLabel = UILabel(frame: CGRect(x: 23, y: 7, width: UIScreen.main.bounds.width - 46, height: 18))
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.numberOfLines = 0
        errorLabel.textColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.00)
        errorLabel.textAlignment = .center
        errorLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
        errorLabel.text = "Invalid credentials, please try again."
        errorLabel.isHidden = true
        errorBox.addSubview(errorLabel)
        
        activityIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 165, width: UIScreen.main.bounds.width, height: 30))
        activityIndicator.isHidden = true
        view.addSubview(activityIndicator)
    }
    
    @objc func openCountryPicker(_ sender: UITapGestureRecognizer) {
        if let vc = storyboard?.instantiateViewController(identifier: "CountryPicker") as? CountryPickerController {
            vc.phoneController = self
            present(vc, animated: true, completion: nil)
        }
    }
    
    @objc func backTapped(_ sender: UIButton) {
        self.dismiss(animated: false, completion: nil)
    }

    @objc func rootBackTapped(_ sender: UIButton) {
        /// here we'll make the landing page the root and sign the user out. The user at this moment has validated their email but not their phone, so sign out to make them go through the flow again
        sender.isEnabled = false
        
        do {
            try Auth.auth().signOut()
            if let loginVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "LandingPage") as? LandingPageController {
                
                let keyWindow = UIApplication.shared.connectedScenes
                    .filter({$0.activationState == .foregroundActive})
                    .map({$0 as? UIWindowScene})
                    .compactMap({$0})
                    .first?.windows
                    .filter({$0.isKeyWindow}).first
                keyWindow?.rootViewController = loginVC
            }
            
        } catch {
            return
        }
    }
    
    @objc func sendCode(_ sender: UIButton) {
        /// set to confirm button

        view.resignFirstResponder()
        guard var phoneNumber = phoneField.text?.trimmingCharacters(in: .whitespaces) else { return }
        /// add country code if not there
        phoneNumber = country.code + phoneNumber
        
        sender.isEnabled = false
        activityIndicator.startAnimating()
        
        if codeType == .logIn {
            checkForUser(phoneNumber: phoneNumber)
            
        } else {
            validatePhoneNumber(phoneNumber: phoneNumber)
        }
    }
    
    func validatePhoneNumber(phoneNumber: String) {
        
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { (verificationID, error) in

            if let error = error {
                
                self.view.endEditing(true)
                let message = error.localizedDescription == "TOO_SHORT" ? "Please enter a valid phone number" : error.localizedDescription == "We have blocked all requests from this device due to unusual activity. Try again later." ? "You're all out of codes. Try again later." : error.localizedDescription
                
                Mixpanel.mainInstance().track(event: "PhoneError", properties: ["error": message])
                self.showErrorMessage(message: message)
                
            } else {
                
                if self.newUser != nil { self.newUser.phone = phoneNumber }
                
                if let vc = self.storyboard?.instantiateViewController(identifier: "ConfirmVC") as? ConfirmCodeController {
                    
                    Mixpanel.mainInstance().track(event: "PhoneCodeSent")
                    
                    vc.verificationID = verificationID!
                    vc.phoneNumber = phoneNumber
                    vc.codeType = self.codeType
                    
                    if self.newUser != nil { vc.newUser = self.newUser }
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
            
            self.sendButton.isEnabled = true
            self.activityIndicator.stopAnimating()
        }
    }
    
    func checkForUser(phoneNumber: String) {
        
        // check if a user with this phone number exists if logging in with phone
        
        let defaults = UserDefaults.standard
        let verified = defaults.object(forKey: "verifiedPhone") as? Bool ?? false
        let db = Firestore.firestore()
        
        if verified {
            self.validatePhoneNumber(phoneNumber: phoneNumber)
            
        } else {
            db.collection("users").whereField("phone", isEqualTo: phoneNumber).getDocuments { (snap, err) in
                if let doc = snap?.documents.first {
                    /// if user is verified but its not already saved to defaults (app could've been deleted), save it to defaults
                    let verified = doc.get("verfiedPhone") as? Bool ?? false
                    if verified {
                        defaults.set(true, forKey: "verifiedPhone")
                        self.validatePhoneNumber(phoneNumber: phoneNumber)
                    } else {
                        self.showErrorMessage(message: "No verified user found with this number")
                    }
                }
            }
        }
    }
    
    func showErrorMessage(message: String) {
        
        self.sendButton.isEnabled = true
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
    
    @objc func phoneNumberChanged(_ sender: UITextField) {
        sendButton.alpha = sender.text?.count ?? 0 < 10 ? 0.65 : 1.0
    }
    
    func resetCountry(country: CountryCode) {
        self.country = country
        countryCodeView.setUp(country: country)
        countryCodeView.frame = CGRect(x: countryCodeView.frame.minX, y: countryCodeView.frame.minY, width: countryCodeView.separatorLine.frame.maxX + 10, height: countryCodeView.frame.height)
        paddingView.frame = CGRect(x: 0, y: 0, width: countryCodeView.bounds.width + 10, height: phoneField.frame.height)
    }
}

class CountryCodeView: UIView {
    
    var number: UILabel!
    var editButton: UIImageView!
    var separatorLine: UIView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = nil
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp(country: CountryCode) {
        
        backgroundColor = nil
        
        if number != nil { number.text = ""}
        number = UILabel(frame: CGRect(x: 0, y: 5, width: 60, height: 30))
        number.text = country.code
        number.textColor = .black
        number.font = UIFont(name: "SFCamera-Semibold", size: 28)
        number.textAlignment = .left
        number.sizeToFit()
        addSubview(number)
        
        if editButton != nil { editButton.image = UIImage() }
        editButton = UIImageView(frame: CGRect(x: number.frame.maxX + 3, y: 20, width: 12, height: 9))
        editButton.image = UIImage(named: "DownCarat")
        editButton.contentMode = .scaleAspectFit
        addSubview(editButton)
        
        if separatorLine != nil { separatorLine.backgroundColor = nil }
        separatorLine = UIView(frame: CGRect(x: editButton.frame.maxX + 5, y: 0, width: 1, height: self.frame.height))
        separatorLine.backgroundColor = UIColor(red: 0.704, green: 0.704, blue: 0.704, alpha: 1.0)
        addSubview(separatorLine)
    }
}

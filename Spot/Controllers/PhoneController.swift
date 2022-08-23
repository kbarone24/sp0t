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
import IQKeyboardManagerSwift

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
    
    var cancelOnDismiss = false
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "PhoneOpen")
        enableKeyboardMethods()
        if phoneField != nil { phoneField.becomeFirstResponder() }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        IQKeyboardManager.shared.enable = true
        disableKeyboardMethods()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
        setUpNavBar()
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

        country = CountryCode(id: 224, code: "+1", name: "United States")
        
        let labelText = "Verify your phone number"
        
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
        
        phoneField = UITextField {
            //$0.backgroundColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 27.5)
            $0.textAlignment = .center
            $0.tintColor = UIColor(named: "SpotGreen")
            $0.textColor = .black
            var placeholderText = NSMutableAttributedString()
            placeholderText = NSMutableAttributedString(string: "000-000-0000", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Medium", size: 27.5),
                    NSAttributedString.Key.foregroundColor: UIColor(red: 0.733, green: 0.733, blue: 0.733, alpha: 1)
            ])
            $0.attributedPlaceholder = placeholderText
            $0.keyboardType = .numberPad
            $0.addTarget(self, action: #selector(phoneNumberChanged(_:)), for: .editingChanged)
            view.addSubview($0)
        }
        phoneField.snp.makeConstraints{
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
            $0.width.equalTo(phoneField.snp.width)
            $0.top.equalTo(phoneField.snp.bottom).offset(5)
            $0.centerX.equalToSuperview()
        }
        
        
        sendButton = UIButton {
             $0.layer.cornerRadius = 9
             $0.backgroundColor = UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1)
             let customButtonTitle = NSMutableAttributedString(string: "Send code", attributes: [
                 NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 16) as Any,
                 NSAttributedString.Key.foregroundColor: UIColor(red: 0, green: 0, blue: 0, alpha: 1)
             ])
             $0.setAttributedTitle(customButtonTitle, for: .normal)
             $0.setImage(nil, for: .normal)
             $0.addTarget(self, action: #selector(sendCode(_:)), for: .touchUpInside)
             view.addSubview($0)
        }
        sendButton.snp.makeConstraints{
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.height.equalTo(49)
            $0.bottom.equalToSuperview().offset(-30)
        }
        

        errorBox = UIView(frame: CGRect(x: 0, y: sendButton.frame.maxY + 30, width: UIScreen.main.bounds.width, height: 32))
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
        
        activityIndicator = CustomActivityIndicator {
            $0.isHidden = true
            view.addSubview($0)
        }

        activityIndicator.snp.makeConstraints{
            $0.top.equalTo(bottomLine.snp.bottom).offset(15)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(20)
        }
        
    }
    
    @objc func keyboardWillShow(_ notification: NSNotification) {
        print("keyboard will show")
        if cancelOnDismiss { return }
        /// new spot name view editing when textview not first responder
        animateWithKeyboard(notification: notification) { keyboardFrame in
            self.sendButton.snp.removeConstraints()
            self.sendButton.snp.makeConstraints {
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
            self.sendButton.snp.removeConstraints()
            self.sendButton.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(18)
                $0.height.equalTo(49)
                $0.bottom.equalToSuperview().offset(-30)
            }
        }
    }
    
    @objc func openCountryPicker(_ sender: UITapGestureRecognizer) {
        if let vc = storyboard?.instantiateViewController(identifier: "CountryPicker") as? CountryPickerController {
            vc.phoneController = self
            present(vc, animated: true, completion: nil)
        }
    }
    
    @objc func backTapped(_ sender: UIButton) {
        self.dismiss(animated: true)
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
        guard let rawNumber = phoneField.text?.trimmingCharacters(in: .whitespaces) else { return }
        /// add country code if not there
        let phoneNumber = country.code + rawNumber
        
        sender.isEnabled = false
        activityIndicator.startAnimating()
        
        if codeType == .logIn {
            checkForUser(phoneNumber: phoneNumber)
            
        } else {
            validatePhoneNumber(phoneNumber: phoneNumber, rawNumber: rawNumber)
        }
    }
    
    func validatePhoneNumber(phoneNumber: String, rawNumber: String) {
        
        /// raw number only needed for searching db for sentInvites to this number
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
                    vc.rawNumber = rawNumber
                    
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
            print("🙇🏽‍♀️ 1")
            self.validatePhoneNumber(phoneNumber: phoneNumber, rawNumber: "")
        } else {
            print("🙇🏽‍♀️ 2")

            db.collection("users").whereField("phone", isEqualTo: phoneNumber).getDocuments { (snap, err) in
                if let doc = snap?.documents.first {
                    /// if user is verified but its not already saved to defaults (app could've been deleted), save it to defaults
                    let verified = doc.get("verifiedPhone") as? Bool ?? false
                    if verified {
                        defaults.set(true, forKey: "verifiedPhone")
                        self.validatePhoneNumber(phoneNumber: phoneNumber, rawNumber: "")
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
        sendButton.isUserInteractionEnabled = sender.text?.count ?? 0 < 10 ? false : true

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
        number.font = UIFont(name: "SFCompactText-Semibold", size: 28)
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

extension UITextField {
  func useUnderline() -> Void {
    let border = CALayer()
    let borderWidth = CGFloat(2.0) // Border Width
    border.borderColor = UIColor.black.cgColor
    border.frame = CGRect(origin: CGPoint(x: 0,y :self.frame.size.height - borderWidth), size: CGSize(width: self.frame.size.width, height: self.frame.size.height))
    border.borderWidth = borderWidth
    self.layer.addSublayer(border)
    self.layer.masksToBounds = true
  }
    
}

extension UITextField {
    public func addBottomBorder(color: UIColor = UIColor.black, marginToUp: CGFloat = 1.00, height: CGFloat = 1.00){
        let bottomLine = CALayer()
        bottomLine.frame = CGRect(x: 0, y: self.frame.size.height - marginToUp, width: self.frame.size.width, height: height)
        bottomLine.backgroundColor = color.cgColor
        borderStyle = .none
        layer.addSublayer(bottomLine)
    }
    
}

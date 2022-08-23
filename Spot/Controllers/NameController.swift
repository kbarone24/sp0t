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
import IQKeyboardManagerSwift


class NameController: UIViewController, UITextFieldDelegate {
                
    var nameField: UITextField!
    var nextButton: UIButton!

    var activityIndicator: CustomActivityIndicator!
        
    var label: UILabel!
    var countryCodeView: CountryCodeView!
    var paddingView: UIView!
    var submitButton: UIButton!
    
    var newUser: NewUser!
    
    var cancelOnDismiss = false

    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "SignUp1Open")
        enableKeyboardMethods()
        if nameField != nil { nameField.becomeFirstResponder() }
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
               
        newUser = NewUser(name: "", username: "", phone: "")
        
        label = UILabel {
            $0.text = "Welcome! What's your name?"
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 20)
            view.addSubview($0)

        }
        label.snp.makeConstraints{
            $0.top.equalToSuperview().offset(114)
            $0.centerX.equalToSuperview()
        }
                
        nameField = UITextField {
            //$0.backgroundColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 27.5)
            $0.textAlignment = .center
            $0.tintColor = UIColor(named: "SpotGreen")
            $0.textColor = .black
            var placeholderText = NSMutableAttributedString()
            placeholderText = NSMutableAttributedString(string: "sp0t b0tterson", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Medium", size: 27.5),
                    NSAttributedString.Key.foregroundColor: UIColor(red: 0.733, green: 0.733, blue: 0.733, alpha: 1)
            ])
            $0.attributedPlaceholder = placeholderText
            $0.autocorrectionType = .no
            $0.autocapitalizationType = .words
            $0.tag = 0
            $0.delegate = self
            $0.textContentType = .name
            $0.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
            view.addSubview($0)
        }
        nameField.snp.makeConstraints{
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
            $0.width.equalTo(nameField.snp.width)
            $0.top.equalTo(nameField.snp.bottom).offset(5)
            $0.centerX.equalToSuperview()
        }
        
        nextButton = UIButton {
             $0.layer.cornerRadius = 9
             $0.backgroundColor = UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1)
             let customButtonTitle = NSMutableAttributedString(string: "Next", attributes: [
                 NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 16) as Any,
                 NSAttributedString.Key.foregroundColor: UIColor(red: 0, green: 0, blue: 0, alpha: 1)
             ])
             $0.setAttributedTitle(customButtonTitle, for: .normal)
             $0.setImage(nil, for: .normal)
             $0.addTarget(self, action: #selector(nextTapped(_:)), for: .touchUpInside)
             view.addSubview($0)
        }
        nextButton.snp.makeConstraints{
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.height.equalTo(49)
            $0.bottom.equalToSuperview().offset(-30)
        }
        
        activityIndicator = CustomActivityIndicator(){
            $0.isHidden = true
            view.addSubview($0)

        }
        activityIndicator.snp.makeConstraints{
            $0.top.equalTo(bottomLine.snp.bottom).offset(20)
            $0.width.height.equalTo(20)
            $0.centerX.equalToSuperview()
        }
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        let message = nameFieldComplete(name: nameField.text ?? "")
        nextButton.alpha = message == "" ? 1.0 : 0.65
        nextButton.isUserInteractionEnabled = message == "" ? true : false
    }
    
    @objc func textChanged(_ sender: UITextView) {
        let message = nameFieldComplete(name: nameField.text ?? "")
        nextButton.alpha = message == "" ? 1.0 : 0.65
        nextButton.isUserInteractionEnabled = message == "" ? true : false
    }
    
    @objc func keyboardWillShow(_ notification: NSNotification) {
        print("keyboard will show")
        if cancelOnDismiss { return }
        /// new spot name view editing when textview not first responder
        animateWithKeyboard(notification: notification) { keyboardFrame in
            self.nextButton.snp.removeConstraints()
            self.nextButton.snp.makeConstraints {
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
            self.nextButton.snp.removeConstraints()
            self.nextButton.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(18)
                $0.height.equalTo(49)
                $0.bottom.equalToSuperview().offset(-30)
            }
        }
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
        
        //Checks to see if there is text field without text entered into it
        
        let errorMessage = self.nameFieldComplete(name: name)
        
        if errorMessage == "" {
            
            self.newUser.name = name
            let vc = UsernameController()
            Mixpanel.mainInstance().track(event: "SignUp1Success")
            vc.newUser = self.newUser
            self.navigationController?.pushViewController(vc, animated: true)
    
                
        } else {
            Mixpanel.mainInstance().track(event: "SignUp1InvalidFields", properties: ["error": errorMessage])
            nextButton.isUserInteractionEnabled = false
        }
    }
    
    //add new user's account to firestore w/ uid key and name,email,username value pairs
    
    
    //Function checks to see if text is entered into all fields
    private func nameFieldComplete(name: String) -> String {
        
        var errorMessage = ""
        
        if name.isEmpty {
            errorMessage = "Please enter your name."
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

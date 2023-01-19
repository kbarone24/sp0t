//
//  SignUp3Controller.swift
//  Spot
//
//  Created by kbarone on 4/9/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation
import IQKeyboardManagerSwift
import Mixpanel
import UIKit
import SnapKit

enum CodeType {
    case newAccount
    case multifactor
    case logIn
    case deleteAccount
}

final class PhoneController: UIViewController, UITextFieldDelegate {
    var root = false
    var newUser: NewUser!
    var countryCode: CountryCode!

    var label: UILabel!
    var phoneField: UITextField!
    
    private(set) lazy var countryCodeView: CountryCodeView = {
        let view = CountryCodeView()
        view.addTarget(self, action: #selector(openCountryPicker), for: .touchUpInside)
        return view
    }()
    
    var paddingView: UIView!
    var sendButton: UIButton!

    var activityIndicator: CustomActivityIndicator!
    var errorBox: ErrorBox!
    var codeType: CodeType!

    var cancelOnDismiss = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "PhoneOpen")
        enableKeyboardMethods()
        if phoneField != nil { DispatchQueue.main.async { self.phoneField.becomeFirstResponder() } }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        disableKeyboardMethods()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
        setUpNavBar()
    }

    func enableKeyboardMethods() {
        cancelOnDismiss = false
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    func disableKeyboardMethods() {
        cancelOnDismiss = true
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

    }

    func setUpNavBar() {
        navigationController?.navigationBar.barTintColor = UIColor.white
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.tintColor = UIColor.black
        navigationController?.view.backgroundColor = .white
        navigationController?.navigationBar.addWhiteBackground()

        let logo = UIImage(named: "OnboardingLogo")
        let imageView = UIImageView(image: logo)
        // imageView.contentMode = .scaleToFill
        imageView.snp.makeConstraints {
            $0.height.equalTo(32.9)
            $0.width.equalTo(78)

        }
        self.navigationItem.titleView = imageView

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "BackArrowDark"),
            style: .plain,
            target: self,
            action: #selector(backTapped(_:))
        )
    }

    func setUpViews() {
        view.backgroundColor = .white
        countryCode = CountryCode(id: 224, code: "+1", name: "United States")

        let labelText = "Verify your phone number"

        label = UILabel {
            $0.text = labelText
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 20)
            view.addSubview($0)
        }
        
        label.snp.makeConstraints {
            $0.top.equalToSuperview().offset(114)
            $0.centerX.equalToSuperview()
        }

        countryCodeView.code = countryCode.code
        view.addSubview(countryCodeView)
        countryCodeView.snp.makeConstraints {
            $0.leading.equalTo(18)
            $0.top.equalTo(label.snp.bottom).offset(30)
            $0.height.equalTo(40)
            $0.width.equalTo(countryCodeView.number.snp.width).offset(28)
        }

        phoneField = UITextField {
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 27.5)
            $0.textAlignment = .left
            $0.tintColor = UIColor(named: "SpotGreen")
            $0.textColor = .black
            var placeholderText = NSMutableAttributedString()
            placeholderText = NSMutableAttributedString(string: "000-000-0000", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Medium", size: 27.5) as Any,
                NSAttributedString.Key.foregroundColor: UIColor(red: 0.733, green: 0.733, blue: 0.733, alpha: 1)
            ])
            $0.attributedPlaceholder = placeholderText
            $0.keyboardType = .numberPad
            $0.textContentType = .telephoneNumber
            $0.addTarget(self, action: #selector(phoneNumberChanged(_:)), for: .editingChanged)
            view.addSubview($0)
        }
        phoneField.snp.makeConstraints {
            $0.leading.equalTo(countryCodeView.snp.trailing).offset(12)
            $0.top.equalTo(label.snp.bottom).offset(30)
            $0.height.equalTo(40)
        }

        let bottomLine = UIView {
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            view.addSubview($0)
        }
        bottomLine.snp.makeConstraints {
            $0.height.equalTo(1.5)
            $0.leading.trailing.equalToSuperview().inset(18)
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
            $0.addTarget(self, action: #selector(sendCode(_:)), for: .touchUpInside)
            $0.alpha = 0.4
            $0.isEnabled = false
            view.addSubview($0)
        }
        sendButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.height.equalTo(49)
            $0.bottom.equalToSuperview().offset(-30)
        }

        /// redesign with constraints
        errorBox = ErrorBox {
            $0.isHidden = true
            view.addSubview($0)
        }
        errorBox.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(bottomLine.snp.bottom).offset(15)
            $0.height.equalTo(errorBox.label.snp.height).offset(12)
        }

        activityIndicator = CustomActivityIndicator {
            $0.isHidden = true
            view.addSubview($0)
        }
        activityIndicator.snp.makeConstraints {
            $0.top.equalTo(bottomLine.snp.bottom).offset(12)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(25)
        }

    }

    @objc func keyboardWillShow(_ notification: NSNotification) {
        /// new spot name view editing when textview not first responder
        if cancelOnDismiss { return }
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
        animateWithKeyboard(notification: notification) { _ in
            self.sendButton.snp.removeConstraints()
            self.sendButton.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(18)
                $0.height.equalTo(49)
                $0.bottom.equalToSuperview().offset(-30)
            }
        }
    }

    @objc func openCountryPicker() {
        let countryPicker = CountryPickerController()
        countryPicker.delegate = self
        DispatchQueue.main.async { self.present(countryPicker, animated: true) }
    }

    @objc func backTapped(_ sender: UIButton) {
        print("back tapped")
        DispatchQueue.main.async {
            if self.root {
                self.dismiss(animated: false)
            } else {
                self.navigationController?.popViewController(animated: true)
            }
        }
    }

    @objc func sendCode(_ sender: UIButton) {
        /// set to confirm button
        guard let rawNumber = phoneField.text?.trimmingCharacters(in: .whitespaces) else { return }
        /// add country code if not there
        let phoneNumber = countryCode.code + rawNumber
        sender.isEnabled = false
        activityIndicator.startAnimating()

        checkForUser(phoneNumber: phoneNumber) { userExists in
            /// validate if user already exists
            if self.codeType == .logIn {
                if userExists {
                    self.validatePhoneNumber(phoneNumber: phoneNumber)
                } else {
                    self.showErrorMessage(message: "No verified user found with this number")
                }
            /// show error if user already exists
            } else {
                if userExists {
                    self.showErrorMessage(message: "Phone number already in use")
                } else {
                    self.validatePhoneNumber(phoneNumber: phoneNumber)
                }
            }
        }
    }

    func validatePhoneNumber(phoneNumber: String) {
        /// raw number only needed for searching db for sentInvites to this number
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { (verificationID, error) in
            if let error = error {
                print("error", error.localizedDescription)
                let message = error.localizedDescription ==
                "We have blocked all requests from this device due to unusual activity. Try again later."
                ? "You're all out of codes. Try again later."
                : "Please enter a valid phone number."
                Mixpanel.mainInstance().track(event: "PhoneError", properties: ["error": message])
                self.showErrorMessage(message: message)

            } else {
                DispatchQueue.main.async { self.view.endEditing(true) }
                let formattedNumber = self.countryCode.code + phoneNumber.formatNumber()
                if self.newUser != nil { self.newUser.phone = formattedNumber } /// formatted # for database

                let vc = ConfirmCodeController()
                Mixpanel.mainInstance().track(event: "PhoneCodeSent")
                vc.verificationID = verificationID!
                vc.codeType = self.codeType

                if self.newUser != nil { vc.newUser = self.newUser }
                self.navigationController?.pushViewController(vc, animated: true)
            }
            self.sendButton.isEnabled = true
            self.activityIndicator.stopAnimating()
        }
    }

    func checkForUser(phoneNumber: String, completion: @escaping (_ userExists: Bool) -> Void) {
        // check if a user with this phone number exists if logging in with phone
        let defaults = UserDefaults.standard
        let defaultsPhone = defaults.object(forKey: "phoneNumber") as? String ?? ""
        let db = Firestore.firestore()
        let formattedNumber = countryCode.code + phoneNumber.formatNumber()

        if defaultsPhone == formattedNumber {
            completion(true)
            return
        } else {
            db.collection("users").whereField("phone", isEqualTo: formattedNumber).getDocuments { (snap, _) in
                if let doc = snap?.documents.first {
                    /// if user is verified but its not already saved to defaults (app could've been deleted), save it to defaults
                    let verified = doc.get("verifiedPhone") as? Bool ?? false
                    if verified {
                        defaults.set(formattedNumber, forKey: "phoneNumber")
                        completion(true)
                        return
                    } else {
                        completion(false)
                        return
                    }
                } else {
                    completion(false)
                    return
                }
            }
        }
    }

    func showErrorMessage(message: String) {
        sendButton.isEnabled = true
        activityIndicator.stopAnimating()
        errorBox.isHidden = false
        errorBox.message = message

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            self.errorBox.isHidden = true
        }
    }

    @objc func phoneNumberChanged(_ sender: UITextField) {
        let text = sender.text ?? ""
        sendButton.alpha = text.count < 10 ? 0.4 : 1.0
        sendButton.isEnabled = text.count < 10 ? false : true
    }
    
    // https://www.advancedswift.com/animate-with-ios-keyboard-swift/
    private func animateWithKeyboard(
        notification: NSNotification,
        animations: ((_ keyboardFrame: CGRect) -> Void)?
    ) {
        // Extract the duration of the keyboard animation
        let durationKey = UIResponder.keyboardAnimationDurationUserInfoKey
        let duration = notification.userInfo?[durationKey] as? Double ?? 0

        // Extract the final frame of the keyboard
        let frameKey = UIResponder.keyboardFrameEndUserInfoKey
        let keyboardFrameValue = notification.userInfo?[frameKey] as? NSValue

        // Extract the curve of the iOS keyboard animation
        let curveKey = UIResponder.keyboardAnimationCurveUserInfoKey
        let curveValue = notification.userInfo?[curveKey] as? Int ?? 0
        let curve = UIView.AnimationCurve(rawValue: curveValue) ?? .easeIn

        // Create a property animator to manage the animation
        let animator = UIViewPropertyAnimator(
            duration: duration,
            curve: curve
        ) {
            // Perform the necessary animation layout updates
            animations?(keyboardFrameValue?.cgRectValue ?? .zero)

            // Required to trigger NSLayoutConstraint changes
            // to animate
            self.view?.layoutIfNeeded()
        }

        // Start the animation
        animator.startAnimation()
    }
}

extension PhoneController: CountryPickerDelegate {
    func finishPassing(code: CountryCode) {
        countryCode = code
        countryCodeView.code = code.code
    }
}

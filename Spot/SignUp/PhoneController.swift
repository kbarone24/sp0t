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
    var newUser: NewUser?
    lazy var countryCode = CountryCode(id: 224, code: "+1", name: "United States")

    private lazy var backgroundImage: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "LandingPageBackground"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private(set) lazy var titleLabel: UILabel = {
        // TODO: change font (UniversCEMedium-Bold)
        let label = UILabel()
        label.text = "Verify your phone number"
        label.textColor = UIColor(red: 0.358, green: 0.357, blue: 0.357, alpha: 1)
        label.font = UIFont(name: "UniversCE-Black", size: 22)
        return label
    }()
    private(set) lazy var phoneField: UITextField = {
        // TODO: change font (UniversLTBlack-Oblique)
        let view = UITextField()
        view.font = UIFont(name: "UniversCE-Black", size: 27)
        view.textAlignment = .left
        view.tintColor = UIColor(named: "SpotGreen")
        view.textColor = UIColor(red: 0.358, green: 0.357, blue: 0.357, alpha: 1)
        var placeholderText = NSMutableAttributedString()
        placeholderText = NSMutableAttributedString(string: "000-000-0000", attributes: [
            NSAttributedString.Key.font: UIFont(name: "UniversCE-Black", size: 27) as Any,
            NSAttributedString.Key.foregroundColor: UIColor(red: 0.358, green: 0.357, blue: 0.357, alpha: 0.25)
        ])
        view.attributedPlaceholder = placeholderText
        view.keyboardType = .numberPad
        view.textContentType = .telephoneNumber
        view.addTarget(self, action: #selector(phoneNumberChanged(_:)), for: .editingChanged)
        return view
    }()
    
    private(set) lazy var countryCodeView: CountryCodeView = {
        let view = CountryCodeView(code: "+1")
        view.addTarget(self, action: #selector(openCountryPicker), for: .touchUpInside)
        return view
    }()

    private lazy var bottomLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.919, green: 0.919, blue: 0.919, alpha: 1)
        return view
    }()
    
    private lazy var sendButton: SignUpPillButton = {
        let button = SignUpPillButton(text: "Send code")
        button.alpha = 0.4
        button.addTarget(self, action: #selector(sendCode(_:)), for: .touchUpInside)
        return button
    }()

    private lazy var activityIndicator = CustomActivityIndicator()
    private lazy var errorBox = ErrorBox()
    private var codeType: CodeType

    var cancelOnDismiss = false

    init(codeType: CodeType) {
        self.codeType = codeType
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "PhoneOpen")
        enableKeyboardMethods()
        DispatchQueue.main.async { self.phoneField.becomeFirstResponder() }
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
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.tintColor = UIColor.black

        if codeType == .logIn {
            navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "BackArrowDark"), style: .plain, target: self, action: #selector(arrowTap))
        }
    }

    func setUpViews() {
        view.backgroundColor = .white

        view.addSubview(backgroundImage)
        backgroundImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.centerY.equalToSuperview().offset(-200)
            $0.centerX.equalToSuperview()
        }

        view.addSubview(countryCodeView)
        countryCodeView.snp.makeConstraints {
            $0.leading.equalTo(38)
            $0.top.equalTo(titleLabel.snp.bottom).offset(60)
            $0.height.equalTo(40)
            $0.width.equalTo(countryCodeView.number.snp.width).offset(16)
        }

        view.addSubview(phoneField)
        phoneField.snp.makeConstraints {
            $0.leading.equalTo(countryCodeView.snp.trailing).offset(14)
            $0.top.equalTo(countryCodeView).offset(-5)
            $0.height.equalTo(40)
        }

        view.addSubview(bottomLine)
        bottomLine.snp.makeConstraints {
            $0.height.equalTo(3)
            $0.leading.trailing.equalToSuperview().inset(30)
            $0.top.equalTo(phoneField.snp.bottom).offset(5)
            $0.centerX.equalToSuperview()
        }

        view.addSubview(sendButton)
        sendButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.height.equalTo(49)
            $0.bottom.equalToSuperview().offset(-30)
        }

        errorBox.isHidden = true
        view.addSubview(errorBox)
        errorBox.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(bottomLine.snp.bottom).offset(15)
            $0.height.equalTo(errorBox.label.snp.height).offset(12)
        }

        activityIndicator.isHidden = true
        view.addSubview(activityIndicator)
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

    @objc func arrowTap() {
        dismiss(animated: false)
    }

    @objc func openCountryPicker() {
        let countryPicker = CountryPickerController()
        countryPicker.delegate = self
        DispatchQueue.main.async { self.present(countryPicker, animated: true) }
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
                if self.newUser != nil { self.newUser?.phone = formattedNumber } /// formatted # for database

                let vc = ConfirmCodeController()
                Mixpanel.mainInstance().track(event: "PhoneCodeSent")
                vc.verificationID = verificationID ?? ""
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

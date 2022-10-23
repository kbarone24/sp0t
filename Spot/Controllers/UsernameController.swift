//
//  SignUp2Controller.swift
//  Spot
//
//  Created by kbarone on 4/9/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation
import Mixpanel
import UIKit

final class UsernameController: UIViewController, UITextFieldDelegate {
    private var usernameText = ""

    private lazy var usernameField: UITextField = {
        let textField = UITextField()
        textField.font = UIFont(name: "SFCompactText-Semibold", size: 27.5)
        textField.textAlignment = .center
        textField.tintColor = UIColor(named: "SpotGreen")
        textField.textColor = .black

        let placeholderText = NSMutableAttributedString(
            string: "@sp0tb0t", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Medium", size: 27.5) as Any,
                NSAttributedString.Key.foregroundColor: UIColor(red: 0.733, green: 0.733, blue: 0.733, alpha: 1)
            ]
        )

        textField.attributedPlaceholder = placeholderText
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.delegate = self
        textField.textContentType = .name
        textField.addTarget(self, action: #selector(usernameChanged(_:)), for: .editingChanged)

        return textField
    }()

    private lazy var nextButton: UIButton = {
        let button = UIButton()

        button.layer.cornerRadius = 9
        button.backgroundColor = UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1)

        let customButtonTitle = NSMutableAttributedString(
            string: "Next",
            attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 16) as Any,
                NSAttributedString.Key.foregroundColor: UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            ]
        )

        button.setAttributedTitle(customButtonTitle, for: .normal)
        button.setImage(nil, for: .normal)
        button.addTarget(self, action: #selector(nextTapped(_:)), for: .touchUpInside)
        button.alpha = 0.4
        return button
    }()

    private lazy var activityIndicator: CustomActivityIndicator = {
        let activityIndicator = CustomActivityIndicator()
        activityIndicator.isHidden = true
        return activityIndicator
    }()

    private lazy var statusLabel: UIButton = {
        let label = UIButton()

        label.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 7)
        label.titleEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        label.setTitleColor(UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1), for: .normal)
        label.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14)
        label.contentVerticalAlignment = .center
        label.contentHorizontalAlignment = .center
        label.isHidden = false

        return label
    }()

    private var newUser: NewUser?
    private var cancelOnDismiss = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "SignUpUsernameOpen")
        enableKeyboardMethods()
        self.usernameField.becomeFirstResponder()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        disableKeyboardMethods()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setUpViews()
        setUpNavBar()
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
        imageView.snp.makeConstraints {
            $0.height.equalTo(32.9)
            $0.width.equalTo(78)
        }

        self.navigationItem.titleView = imageView

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "BackArrowDark"),
            style: .plain,
            target: self,
            action: #selector(self.backTapped(_:))
        )
        navigationController?.navigationBar.addWhiteBackground()
    }

    func setNewUser(newUser: NewUser) {
        self.newUser = newUser
    }

    func setUpViews() {
        let usernameLabel = UILabel {
            $0.text = "Create your username"
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 20)
            view.addSubview($0)
        }

        usernameLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(114)
            $0.centerX.equalToSuperview()
        }

        view.addSubview(usernameField)
        usernameField.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.top.equalTo(usernameLabel.snp.bottom).offset(30)
            $0.height.equalTo(40)
        }

        let bottomLine = UIView {
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            view.addSubview($0)
        }

        bottomLine.snp.makeConstraints {
            $0.height.equalTo(1.5)
            $0.width.equalTo(usernameField.snp.width)
            $0.top.equalTo(usernameField.snp.bottom).offset(5)
            $0.centerX.equalToSuperview()
        }

        view.addSubview(nextButton)
        nextButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.height.equalTo(49)
            $0.bottom.equalToSuperview().offset(-30)
        }

        view.addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
            $0.top.equalTo(bottomLine.snp.bottom).offset(12)
            $0.centerX.equalToSuperview()
            $0.width.equalTo(200)
            $0.height.equalTo(30)
        }

        view.addSubview(activityIndicator)
        activityIndicator.isHidden = true
        activityIndicator.snp.makeConstraints {
            $0.top.equalTo(bottomLine.snp.bottom).offset(15)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(20)
        }
    }

    func setAvailable() {
        activityIndicator.stopAnimating()
        statusLabel.isHidden = false
        statusLabel.setImage(UIImage(named: "UsernameAvailable"), for: .normal)
        statusLabel.setTitleColor(UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1), for: .normal)
        statusLabel.setTitle("Available", for: .normal)
        nextButton.alpha = 1.0
        nextButton.isEnabled = true
    }

    func setUnavailable(text: String) {
        activityIndicator.stopAnimating()
        statusLabel.isHidden = false
        statusLabel.setImage(UIImage(named: "UsernameTaken"), for: .normal)
        statusLabel.setTitleColor(UIColor(red: 1, green: 0.376, blue: 0.42, alpha: 1), for: .normal)
        statusLabel.setTitle(text, for: .normal)
        nextButton.alpha = 0.4
        nextButton.isEnabled = false
    }

    func setEmpty() {
        activityIndicator.stopAnimating()
        statusLabel.isHidden = true
        nextButton.alpha = 0.4
        nextButton.isEnabled = false
    }

    @objc func keyboardWillShow(_ notification: NSNotification) {
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
        animateWithKeyboard(notification: notification) { _ in
            self.nextButton.snp.removeConstraints()
            self.nextButton.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(18)
                $0.height.equalTo(49)
                $0.bottom.equalToSuperview().offset(-30)
            }
        }
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

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField.text == "" {
            textField.text = "@"
        }
    }

    func textFieldDidChange(textField: UITextField) {
        guard let text = textField.text else { return }
        if text.contains("$") && text.count == 1 {
            textField.text = ""
        }
        if !text.hasPrefix("@") {
            textField.text = "@" + text
        }
    }

    /// max username = 16 char
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }

        var remove = text.count
        for x in text where x == "@" {
            remove -= 1
        }

        let currentCharacterCount = remove
        let newLength = currentCharacterCount + string.count - range.length
        return newLength <= 16
    }

    @objc func usernameChanged(_ sender: UITextField) {

        setEmpty()

        guard let text = sender.text else { return }

        var lowercaseUsername = sender.text?.lowercased() ?? ""
        lowercaseUsername = lowercaseUsername.trimmingCharacters(in: .whitespaces)
        if lowercaseUsername.count > 2 {
            lowercaseUsername.remove(at: lowercaseUsername.startIndex)
        }

        usernameText = lowercaseUsername

        if text.contains("$") && text.count == 1 {
            sender.text = ""
        }
        if !text.hasPrefix("@") {
            print("does not have prefix")
            sender.text = "@" + text
        }

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.runUsernameQuery), object: nil)
        self.perform(#selector(self.runUsernameQuery), with: nil, afterDelay: 0.4)
    }

    @objc func backTapped(_ sender: UIButton) {
        DispatchQueue.main.async { self.navigationController?.popViewController(animated: true) }
    }

    @objc func runUsernameQuery() {
        let localUsername = self.usernameText
        setEmpty()
        activityIndicator.startAnimating()

        usernameAvailable(username: localUsername) { (errorMessage) in
            if localUsername != self.usernameText { return } /// return if username field already changed
            if errorMessage != "" {
                self.setUnavailable(text: errorMessage)
            } else {
                self.setAvailable()
            }
        }
    }

    func usernameAvailable(username: String, completion: @escaping(_ err: String) -> Void) {
        if !isValidUsername(username: username) {
            completion("Too short")
            return
        }

        let db = Firestore.firestore()
        let usersRef = db.collection("usernames")
        let query = usersRef.whereField("username", isEqualTo: username)

        query.getDocuments { [weak self] snap, err in
            guard let self, err == nil else {
                completion("error")
                return
            }

            if username != self.usernameText {
                completion("Taken")
                return
            }

            if let documents = snap?.documents, !documents.isEmpty {
                completion("Taken")
            } else {
                completion("")
            }
        }
    }

    @objc func nextTapped(_ sender: UIButton) {
        view.endEditing(true)
        setEmpty()

        guard var username = usernameField.text?.lowercased() else {
            return
        }

        username = username.trimmingCharacters(in: .whitespaces)
        if username.count > 2 {
            username.remove(at: username.startIndex)
        }

        activityIndicator.startAnimating()

        /// check username status again on completion
        usernameAvailable(username: username) { [weak self] errorMessage in

            guard let self, errorMessage.isEmpty else {
                Mixpanel.mainInstance().track(
                    event: "SignUpUsernameError",
                    properties: ["error": errorMessage]
                )

                return
            }

            self.newUser?.username = username
            let vc = PhoneController()
            Mixpanel.mainInstance().track(event: "UsernameContorllerSuccess")
            vc.codeType = .newAccount
            vc.newUser = self.newUser

            DispatchQueue.main.async { self.navigationController?.pushViewController(vc, animated: true)
            }

            sender.isEnabled = true
            self.activityIndicator.stopAnimating()
        }
    }
}

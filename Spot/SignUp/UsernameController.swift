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

    private lazy var backgroundImage: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "LandingPageBackground"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        //TODO: replace with real font (UniversCEMedium-Bold)
        let label = UILabel()
        label.text = "Create username"
        label.textColor = UIColor(red: 0.358, green: 0.357, blue: 0.357, alpha: 1)
        label.font = UIFont(name: "UniversCE-Black", size: 22)
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        //TODO: replace with real font (UniversCEMedium-Bold)
        let label = UILabel()
        label.text = "You can be anyone on sp0t"
        label.textColor = UIColor(red: 0.358, green: 0.357, blue: 0.357, alpha: 0.7)
        label.font = UIFont(name: "UniversCE-Black", size: 16)
        return label
    }()

    private lazy var usernameField: UITextField = {
        let textField = UITextField()
        textField.backgroundColor = .white
        textField.layer.cornerRadius = 15
        textField.layer.borderWidth = 6
        textField.layer.borderColor = UIColor(red: 0.919, green: 0.919, blue: 0.919, alpha: 1).cgColor
        textField.font = UIFont(name: "UniversCE-Black", size: 27)
        textField.textAlignment = .center
        textField.tintColor = UIColor(named: "SpotGreen")
        textField.textColor = UIColor(red: 0.358, green: 0.357, blue: 0.357, alpha: 1)
        // TODO: set correct placeholder font (UIFont(name: "UniversLT75Black-Oblique", size: 27)
        let placeholderText = NSMutableAttributedString(
            string: "@sp0tter101", attributes: [
                NSAttributedString.Key.font: UIFont(name: "UniversCE-Black", size: 27) as Any,
                NSAttributedString.Key.foregroundColor: UIColor(red: 0.358, green: 0.357, blue: 0.357, alpha: 0.3)
            ]
        )
        textField.attributedPlaceholder = placeholderText
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.delegate = self
        textField.textContentType = .name
        textField.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
        return textField
    }()

    private lazy var nextButton: SignUpPillButton = {
        let button = SignUpPillButton(text: "Next")
        button.alpha = 0.4
        button.addTarget(self, action: #selector(nextTapped(_:)), for: .touchUpInside)
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

    lazy var userService: UserServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.userService)
        return service
    }()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "SignUpUsernameOpen")
        enableKeyboardMethods()
        DispatchQueue.main.async { self.usernameField.becomeFirstResponder() }

        if !(usernameField.text?.isEmpty ?? true) {
            setAvailable()
        }
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
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.tintColor = UIColor.black
    }

    func setNewUser(newUser: NewUser) {
        self.newUser = newUser
    }

    func setUpViews() {
        view.addSubview(backgroundImage)
        backgroundImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-200)
        }

        view.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(titleLabel.snp.bottom).offset(10)
        }

        view.addSubview(usernameField)
        usernameField.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(25)
            $0.top.equalTo(subtitleLabel.snp.bottom).offset(25)
            $0.height.equalTo(62)
        }

        view.addSubview(nextButton)
        nextButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.height.equalTo(49)
            $0.bottom.equalToSuperview().offset(-30)
        }

        view.addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
            $0.top.equalTo(usernameField.snp.bottom).offset(12)
            $0.centerX.equalToSuperview()
            $0.width.equalTo(200)
            $0.height.equalTo(30)
        }

        view.addSubview(activityIndicator)
        activityIndicator.isHidden = true
        activityIndicator.snp.makeConstraints {
            $0.top.equalTo(usernameField.snp.bottom).offset(15)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(20)
        }
    }

    private func setAvailable() {
        activityIndicator.stopAnimating()
        statusLabel.isHidden = false
        statusLabel.setImage(UIImage(named: "UsernameAvailable"), for: .normal)
        statusLabel.setTitleColor(UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1), for: .normal)
        statusLabel.setTitle("Available", for: .normal)
        nextButton.alpha = 1.0
        nextButton.isEnabled = true
    }

    private func setUnavailable(text: String) {
        activityIndicator.stopAnimating()
        statusLabel.isHidden = false
        statusLabel.setImage(UIImage(named: "UsernameTaken"), for: .normal)
        statusLabel.setTitleColor(UIColor(red: 1, green: 0.376, blue: 0.42, alpha: 1), for: .normal)
        statusLabel.setTitle(text, for: .normal)
        nextButton.alpha = 0.4
        nextButton.isEnabled = false
    }

    private func setEmpty() {
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

    // max username = 16 char
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

    @objc func backTapped(_ sender: UIButton) {
        DispatchQueue.main.async { self.dismiss(animated: false, completion: nil) }
    }

    @objc func textChanged(_ sender: UITextField) {
        guard let text = sender.text else { return }
        if text.contains("$") && text.count == 1 {
            sender.text = ""
        } else if !text.hasPrefix("@") && !text.isEmpty {
            sender.text = "@" + text
        } 

        setUsername(text: sender.text)
    }

    func setUsername(text: String?) {
        setEmpty()

        var lowercaseUsername = text?.lowercased() ?? ""
        lowercaseUsername = lowercaseUsername.trimmingCharacters(in: .whitespaces)
        lowercaseUsername.removeAll(where: { $0 == "@" })
        usernameText = lowercaseUsername

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.runUsernameQuery), object: nil)
        self.perform(#selector(self.runUsernameQuery), with: nil, afterDelay: 0.4)
    }

    @objc func runUsernameQuery() {
        let localUsername = self.usernameText
        setEmpty()
        activityIndicator.startAnimating()

        userService?.usernameAvailable(username: localUsername) { (errorMessage) in
            if localUsername != self.usernameText { return } /// return if username field already changed
            if errorMessage != "" {
                self.setUnavailable(text: errorMessage)
            } else {
                self.setAvailable()
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
        userService?.usernameAvailable(username: username) { [weak self] errorMessage in
            guard let self, errorMessage.isEmpty else {
                Mixpanel.mainInstance().track(
                    event: "SignUpUsernameError",
                    properties: ["error": errorMessage]
                )
                return
            }

            self.newUser?.username = username
            let vc = PhoneController(codeType: .newAccount)
            Mixpanel.mainInstance().track(event: "UsernameContorllerSuccess")
            vc.newUser = self.newUser

            DispatchQueue.main.async { self.navigationController?.pushViewController(vc, animated: true) }

            sender.isEnabled = true
            self.activityIndicator.stopAnimating()
        }
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

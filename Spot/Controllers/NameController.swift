//
//  ViewController.swift
//  Spot
//
//  Created by kbarone on 2/4/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import CoreLocation
import Firebase
import Mixpanel
import UIKit

final class NameController: UIViewController, UITextFieldDelegate {
    private lazy var label: UILabel = {
        let label = UILabel()
        label.text = "Welcome! What's your name?"
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 20)

        return label
    }()

    private lazy var nameField: UITextField = {
        let textField = UITextField()

        textField.font = UIFont(name: "SFCompactText-Semibold", size: 27.5)
        textField.textAlignment = .center
        textField.tintColor = UIColor(named: "SpotGreen")
        textField.textColor = .black

        let placeholderText = NSMutableAttributedString(
            string: "sp0t b0tterson",
            attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Medium", size: 27.5) as Any,
                NSAttributedString.Key.foregroundColor: UIColor(red: 0.733, green: 0.733, blue: 0.733, alpha: 1)
            ]
        )

        textField.attributedPlaceholder = placeholderText
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .words
        textField.tag = 0
        textField.delegate = self
        textField.textContentType = .name
        textField.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)

        return textField
    }()

    private lazy var nextButton: UIButton = {
        let button = UIButton()

        button.layer.cornerRadius = 9
        button.backgroundColor = UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1)

        let customButtonTitle = NSMutableAttributedString(
            string: "Next", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 16) as Any,
                NSAttributedString.Key.foregroundColor: UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            ]
        )

        button.setAttributedTitle(customButtonTitle, for: .normal)
        button.setImage(nil, for: .normal)
        button.addTarget(self, action: #selector(nextTapped(_:)), for: .touchUpInside)

        return button
    }()

    private var cancelOnDismiss = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "SignUp1Open")
        enableKeyboardMethods()
        self.nameField.becomeFirstResponder()
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
            action: #selector(backTapped(_:))
        )
    }

    func setUpViews() {
        view.backgroundColor = .white

        view.addSubview(label)
        label.snp.makeConstraints {
            $0.top.equalToSuperview().offset(114)
            $0.centerX.equalToSuperview()
        }

        view.addSubview(nameField)
        nameField.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.top.equalTo(label.snp.bottom).offset(30)
            $0.height.equalTo(40)
        }

        let bottomLine = UIView {
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            view.addSubview($0)
        }
        bottomLine.snp.makeConstraints {
            $0.height.equalTo(1.5)
            $0.width.equalTo(nameField.snp.width)
            $0.top.equalTo(nameField.snp.bottom).offset(5)
            $0.centerX.equalToSuperview()
        }

        view.addSubview(nextButton)
        nextButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.height.equalTo(49)
            $0.bottom.equalToSuperview().offset(-30)
        }
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        let complete = nameFieldComplete(name: nameField.text ?? "")
        nextButton.isEnabled = complete
        nextButton.alpha = complete ? 1.0 : 0.4
    }

    @objc func textChanged(_ sender: UITextView) {
        let complete = nameFieldComplete(name: nameField.text ?? "")
        nextButton.isEnabled = complete
        nextButton.alpha = complete ? 1.0 : 0.4
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

    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        UIApplication.shared.open(URL)
        return false
    }

    /// limit name field to 25 characters
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)

        return updatedText.count <= 25
    }

    @objc func backTapped(_ sender: UIButton) {
        self.dismiss(animated: false, completion: nil)
    }

    @objc func nextTapped(_ sender: UIButton) {
        self.view.endEditing(true)

        // gets the text values from the text boxes
        guard let name = nameField.text,
              // Checks to see if there is text field without text entered into it
              nameFieldComplete(name: name)
        else { return }

        let vc = UsernameController()
        let newUser = NewUser(name: name, username: "", phone: "")
        vc.setNewUser(newUser: newUser)
        self.navigationController?.pushViewController(vc, animated: true)
        Mixpanel.mainInstance().track(event: "NameControllerSuccess")
    }

    // Function checks to see if text is entered into all fields
    private func nameFieldComplete(name: String) -> Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func termsTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "SignUp1TermsTap")
        if let url = URL(string: "https://www.sp0t.app/legal") {
            UIApplication.shared.open(url)
        }
    }
}

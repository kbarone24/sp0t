//
//  LandingPageController.swift
//  Spot
//
//  Created by kbarone on 4/8/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import AVKit
import Firebase
import Foundation
import Mixpanel
import UIKit

class LandingPageController: UIViewController {
    private lazy var backgroundImage: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "LandingPageBackground"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var createAccountButton: UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = 28
        button.backgroundColor = UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1)
        let customButtonTitle = NSMutableAttributedString(string: "Create account", attributes: [
            NSAttributedString.Key.font: SpotFonts.SFCompactRoundedBold.fontWith(size: 17.5),
            NSAttributedString.Key.foregroundColor: UIColor.black
        ])
        button.setAttributedTitle(customButtonTitle, for: .normal)
        return button
    }()

    private lazy var loginButton: UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = 28
        button.backgroundColor = UIColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1)
        let customButtonTitle = NSMutableAttributedString(string: "Log in", attributes: [
            NSAttributedString.Key.font: SpotFonts.SFCompactRoundedBold.fontWith(size: 15),
            NSAttributedString.Key.foregroundColor: UIColor.black
        ])
        button.setAttributedTitle(customButtonTitle, for: .normal)
        return button
    }()

    private lazy var logo = UIImageView(image: UIImage(named: "LandingScreenLogo"))

    private lazy var privacyNote: UILabel = {
        let label = UILabel()
        label.text = "By creating an account, you agree to sp0t’s"
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1.0)
        label.font = SpotFonts.SFCompactRoundedMedium.fontWith(size: 13)
        return label
    }()

    private lazy var privacyLinks: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isUserInteractionEnabled = true
        textView.isEditable = false

        let attributedString = NSMutableAttributedString(string: "Privacy Policy and Terms of Service")
        let totalRange = NSRange(location: 0, length: attributedString.length)
        attributedString.addAttribute(.font, value: SpotFonts.SFCompactRoundedMedium.fontWith(size: 13), range: totalRange)
        attributedString.addAttribute(.foregroundColor, value: UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1), range: totalRange)

        let url = URL(string: "https://www.sp0t.app/privacy")
        textView.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1.0)
        textView.font = SpotFonts.SFCompactRoundedMedium.fontWith(size: 13)

        // Set the 'click here' substring to be the link
        attributedString.setAttributes([.link: url as Any], range: NSRange(location: 0, length: attributedString.length))
        attributedString.addAttribute(.font, value: SpotFonts.SFCompactRoundedSemibold.fontWith(size: 13), range: totalRange)
        attributedString.addAttribute(.foregroundColor, value: UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1.0), range: totalRange)

        textView.attributedText = attributedString
        textView.linkTextAttributes = [
            .foregroundColor: UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        ]
        return textView
    }()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "LandingPageOpen")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(backgroundImage)
        backgroundImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        createAccountButton.addTarget(self, action: #selector(createAccountTap(_:)), for: .touchUpInside)
        view.addSubview(createAccountButton)
        createAccountButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(27)
            $0.height.equalTo(55.97)
            $0.centerY.equalToSuperview()
        }

        view.addSubview(loginButton)
        loginButton.addTarget(self, action: #selector(loginWithPhoneTap(_:)), for: .touchUpInside)
        loginButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(27)
            $0.height.equalTo(55.97)
            $0.top.equalTo(createAccountButton.snp.bottom).offset(12)
        }

        view.addSubview(logo)
        logo.snp.makeConstraints {
            $0.bottom.equalTo(createAccountButton.snp.top).offset(-32)
            $0.centerX.equalToSuperview()
            $0.height.equalTo(149)
            $0.width.equalTo(236)
        }

        view.addSubview(privacyNote)
        privacyNote.snp.makeConstraints {
            $0.top.equalTo(loginButton.snp.bottom).offset(20)
            $0.centerX.equalToSuperview()
        }

        view.addSubview(privacyLinks)
        privacyLinks.snp.makeConstraints {
            $0.top.equalTo(privacyNote.snp.bottom).offset(-7)
            $0.width.equalTo(250)
            $0.height.equalTo(50)
            $0.centerX.equalToSuperview().offset(5)
        }
        privacyLinks.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(termsTap)))

        addEmailLogin()
    }

    func addEmailLogin() {
        let emailButton = UIButton {
            $0.addTarget(self, action: #selector(emailTap), for: .touchUpInside)
            $0.setTitle("Login with email", for: .normal)
            $0.setTitleColor(UIColor.lightGray, for: .normal)
            $0.titleLabel?.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 12)
            view.addSubview($0)
        }
        emailButton.snp.makeConstraints {
            $0.bottom.equalTo(-50)
            $0.centerX.equalToSuperview()
        }
    }

    @objc func emailTap() {
        let vc = EmailLoginController()
        let navController = UINavigationController(rootViewController: vc)
        navController.modalPresentationStyle = .fullScreen
        self.present(navController, animated: false, completion: nil)
    }

    @objc func createAccountTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "LandingPageCreateAccountTap")
        let vc = UsernameController()
        let newUser = NewUser(name: "", username: "", phone: "")
        vc.setNewUser(newUser: newUser)
        let navController = UINavigationController(rootViewController: vc)
        navController.modalPresentationStyle = .fullScreen
        self.present(navController, animated: false, completion: nil)
    }

    @objc func loginWithPhoneTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "LandingPageLoginWithPhoneTap")
        let vc = PhoneController(codeType: .logIn)
        let navController = UINavigationController(rootViewController: vc)
        navController.modalPresentationStyle = .fullScreen
        self.present(navController, animated: false, completion: nil)
    }

    @objc func termsTap() {
        Mixpanel.mainInstance().track(event: "LandingPageTermsTap")
        if let url = URL(string: "https://www.sp0t.app/privacy") {
            UIApplication.shared.open(url)
        }
    }
}

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
    var thumbnailImage: UIImageView! /// show preview thumbnail while video is buffering
    var firstLoad = true /// determine whether video player has been loaded yet
    var privacyNote: UITextView!
    var privacyLinks: UITextView!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "LandingPageOpen")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        let loginButton = UIButton {
            $0.layer.cornerRadius = 9
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            let customButtonTitle = NSMutableAttributedString(string: "Log in", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15) as Any,
                NSAttributedString.Key.foregroundColor: UIColor(red: 0.488, green: 0.488, blue: 0.488, alpha: 1)
            ])
            $0.setAttributedTitle(customButtonTitle, for: .normal)
            $0.setImage(nil, for: .normal)
            $0.addTarget(self, action: #selector(loginWithPhoneTap(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        loginButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(27)
            $0.height.equalTo(55.97)
            $0.centerY.equalToSuperview()
        }

        let logo = UIImageView {
            $0.image = UIImage(named: "LandingscreenLogo")
            view.addSubview($0)
        }
        logo.snp.makeConstraints {
            $0.bottom.equalTo(loginButton.snp.top).offset(-34)
            $0.centerX.equalToSuperview()
            $0.height.equalTo(133)
            $0.width.equalTo(238)
        }

        let createAccountButton = UIButton {
            $0.layer.cornerRadius = 9
            $0.backgroundColor = UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1)
            let customButtonTitle = NSMutableAttributedString(string: "Create account", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 17.5) as Any,
                NSAttributedString.Key.foregroundColor: UIColor.black
            ])
            $0.setAttributedTitle(customButtonTitle, for: .normal)
            $0.setImage(nil, for: .normal)
            $0.addTarget(self, action: #selector(createAccountTap(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        createAccountButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(27)
            $0.height.equalTo(55.97)
            $0.top.equalTo(loginButton.snp.bottom).offset(12)
        }

        let privacyNote = UILabel {
            $0.text = "By creating an account, you agree to sp0t’s"
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 0.8)
            $0.font = UIFont(name: "SFCompactText-Medium", size: 13)
            view.addSubview($0)
        }
        privacyNote.snp.makeConstraints {
            $0.top.equalTo(createAccountButton.snp.bottom).offset(20)
            $0.centerX.equalToSuperview()
        }

        privacyLinks = UITextView()
        privacyLinks.backgroundColor = .clear

        let attributedString = NSMutableAttributedString(string: "Privacy Policy and Terms of Service")
        let totalRange = NSRange(location: 0, length: attributedString.length)
        attributedString.addAttribute(.font, value: UIFont(name: "SFCompactText-Medium", size: 13)!, range: totalRange)
        attributedString.addAttribute(.foregroundColor, value: UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1), range: totalRange)

        let url = URL(string: "https://www.sp0t.app/privacy")!
        privacyLinks.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 0.8)
        privacyLinks.font = UIFont(name: "SFCompactText-Medium", size: 13)

        // Set the 'click here' substring to be the link
        attributedString.setAttributes([.link: url], range: NSRange(location: 0, length: attributedString.length))
        attributedString.addAttribute(.font, value: UIFont(name: "SFCompactText-Semibold", size: 13)!, range: totalRange)
        attributedString.addAttribute(.foregroundColor, value: UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 0.7), range: totalRange)

        self.privacyLinks.attributedText = attributedString
        self.privacyLinks.isUserInteractionEnabled = true
        self.privacyLinks.isEditable = false

        self.privacyLinks.linkTextAttributes = [
            .foregroundColor: UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        ]

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
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 18)
            view.addSubview($0)
        }
        emailButton.snp.makeConstraints {
            $0.bottom.equalTo(-80)
            $0.centerX.equalToSuperview()
        }
    }

    @objc func emailTap() {
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "EmailLogin") as? EmailLoginController {
            let navController = UINavigationController(rootViewController: vc)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: false, completion: nil)
        }
    }

    @objc func createAccountTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "LandingPageCreateAccountTap")
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SignUp") as? NameController {
            let navController = UINavigationController(rootViewController: vc)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: false, completion: nil)
        }
    }

    @objc func loginWithPhoneTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "LandingPageLoginWithPhoneTap")
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PhoneVC") as? PhoneController {
            vc.root = true
            vc.codeType = .logIn
            let navController = UINavigationController(rootViewController: vc)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: false, completion: nil)
        }
    }

    @objc func termsTap() {
        Mixpanel.mainInstance().track(event: "LandingPageTermsTap")
        if let url = URL(string: "https://www.sp0t.app/privacy") {
            UIApplication.shared.open(url)
        }
    }
}

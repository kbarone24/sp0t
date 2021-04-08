//
//  ResetViewController.swift
//  Spot
//
//  Created by kbarone on 2/13/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import UIKit
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Mixpanel

class ResetViewController: UIViewController {
        
    var emailLabel: UILabel!
    var emailField: UITextField!
    var descriptionLabel: UILabel!
    var resetButton: UIButton!
    
    var activityIndicator: CustomActivityIndicator!
    var errorBox: UIView!
    var errorLabel: UILabel!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if emailField != nil { emailField.becomeFirstResponder() }
        Mixpanel.mainInstance().track(event: "ResetOpen")
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        navigationItem.title = "Password reset"

        let backArrow = UIImage(named: "BackArrow")?.withRenderingMode(.alwaysOriginal)
        navigationController?.navigationBar.backIndicatorImage = backArrow
        navigationController?.navigationBar.backIndicatorTransitionMaskImage = backArrow
        
        emailLabel = UILabel(frame: CGRect(x: 31, y: 40, width: 40, height: 12))
        emailLabel.text = "Email"
        emailLabel.textColor = UIColor(named: "SpotGreen")
        emailLabel.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        view.addSubview(emailLabel)

        emailField = PaddedTextField(frame: CGRect(x: 27, y: emailLabel.frame.maxY + 8, width: UIScreen.main.bounds.width - 54, height: 40))
        emailField.layer.cornerRadius = 7.5
        emailField.backgroundColor = .black
        emailField.layer.borderColor = UIColor(red: 0.158, green: 0.158, blue: 0.158, alpha: 1).cgColor
        emailField.layer.borderWidth = 1
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        emailField.tag = 1
        emailField.textColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.00)
        emailField.font = UIFont(name: "SFCamera-Regular", size: 16)!
        emailField.textContentType = .emailAddress
        emailField.keyboardType = .emailAddress
        emailField.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
        view.addSubview(emailField)

        descriptionLabel = UILabel(frame: CGRect(x: emailField.frame.minX, y: emailField.frame.maxY + 6, width: emailField.frame.width, height: 19))
        descriptionLabel.textColor = UIColor(red: 0.704, green: 0.704, blue: 0.704, alpha:1)
        descriptionLabel.textAlignment = .center
        descriptionLabel.text = "We’ll send a link to reset your password."
        descriptionLabel.font = UIFont(name: "SFCamera-Regular", size: 13)
        view.addSubview(descriptionLabel)
        
        //Load 'Email Link' button background
        resetButton = UIButton(frame: CGRect(x: (UIScreen.main.bounds.width - 217)/2, y: descriptionLabel.frame.maxY + 32, width: 217, height: 40))
        resetButton.alpha = 0.65
        resetButton.imageView?.contentMode = .scaleAspectFit
        resetButton.setImage(UIImage(named: "SendLinkButton"), for: .normal)
        resetButton.addTarget(self, action: #selector(handleReset(_:)), for: UIControl.Event.touchUpInside)
        view.addSubview(resetButton)
        
        errorBox = UIView(frame: CGRect(x: 0, y: resetButton.frame.maxY + 30, width: UIScreen.main.bounds.width, height: 32))
        errorBox.backgroundColor = UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1)
        view.addSubview(errorBox)
        errorBox.isHidden = true
        
        errorLabel = UILabel(frame: CGRect(x: 13, y: 7, width: UIScreen.main.bounds.width - 26, height: 18))
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.numberOfLines = 0
        errorLabel.textColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.00)
        errorLabel.textAlignment = .center
        errorLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
        errorLabel.text = "Invalid email"
        errorBox.addSubview(errorLabel)
        errorLabel.isHidden = true

        activityIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 165, width: UIScreen.main.bounds.width, height: 30))
        activityIndicator.isHidden = true
        view.addSubview(activityIndicator)
    }
    
    @objc func textChanged(_ sender: UITextView) {
        resetButton.alpha = isValidEmail(email: emailField.text ?? "") ? 1.0 : 0.65
    }
    
    @objc func backTapped(_ sender: UIButton){
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "EmailLogin") as? EmailLoginController {
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }
    
    @objc func handleReset(_ sender: UIButton){
        
        guard let resetText = emailField.text else { return }
        
        if !isValidEmail(email: resetText) {
            
            Mixpanel.mainInstance().track(event: "ResetSendEmail")
            
            self.errorBox.isHidden = false
            self.errorLabel.isHidden = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self else { return }
                self.errorLabel.isHidden = true
                self.errorBox.isHidden = true
            }

        } else {
            
            Auth.auth().sendPasswordReset(withEmail: resetText, completion: nil)
            showConfirmMessage()
        }
    }
    
    func showConfirmMessage() {
        
        emailLabel.isHidden = true
        emailField.isHidden = true
        descriptionLabel.isHidden = true
        resetButton.isHidden = true
        errorBox.isHidden = true
        errorLabel.isHidden = true
        
        let confirmationLabel = UILabel(frame: CGRect(x: 108, y: 80, width: 236, height: 38))
        confirmationLabel.textColor = UIColor(named: "SpotGreen")
        confirmationLabel.font = UIFont(name: "SFCamera-Regular", size: 16)
        confirmationLabel.text = "Got it! Check your inbox for a link to reset your password."
        confirmationLabel.numberOfLines = 0
        confirmationLabel.lineBreakMode = .byWordWrapping
        confirmationLabel.sizeToFit()
        view.addSubview(confirmationLabel)
        
        let confirmationSymbol = UIImageView(frame: CGRect(x: 30, y: 70, width: 60, height: 60))
        confirmationSymbol.image = UIImage(named: "CheckIcon")
        view.addSubview(confirmationSymbol)

    }
}

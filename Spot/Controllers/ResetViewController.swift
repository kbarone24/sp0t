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

//This file controls the resetView
class ResetViewController: UIViewController {
    
    //Change status bar theme color white
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    //Initializes text field variable
    var emailField: UITextField!
    var confirmationSymbol: UIImageView!
    var confirmationLayer: UILabel!
    var emailLayer: UILabel!
    var instructLayer: UILabel!
    var resetBtn: UIButton!
    var errorBox: UIView!
    var errorTextLayer: UILabel!
    var resetLabel: UILabel!
    var emailLabel: UILabel!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        //Display background image
        var heightAdjust: CGFloat = 0
        if (!(UIScreen.main.nativeBounds.height > 2300 || UIScreen.main.nativeBounds.height == 1792)) {
            heightAdjust = 20
        }
        
        self.view.backgroundColor = UIColor(named: "SpotBlack")
        
        //Load Spot Logo
        let logoImage = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 45, y: 52 - heightAdjust, width: 90, height: 36))
        logoImage.image = UIImage(named: "MapSp0tLogo")
        logoImage.contentMode = .scaleAspectFit
        view.addSubview(logoImage)
        
        
        let sloganLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 75, y: logoImage.frame.maxY + 3, width: 150, height: 17))
        sloganLabel.text = "where places live"
        sloganLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
        sloganLabel.textColor = .white
        sloganLabel.textAlignment = .center
        view.addSubview(sloganLabel)
        
        let arrow = UIButton(frame: CGRect(x: 0, y: 50 - heightAdjust, width: 40, height: 40))
        arrow.setImage(UIImage(named: "BackButton"), for: .normal)
        arrow.addTarget(self, action: #selector(backTapped(_:)), for: .touchUpInside)
        view.addSubview(arrow)
        
        //Loads 'Password Reset' Label
        
        resetLabel = UILabel(frame: CGRect(x: 32, y: sloganLabel.frame.maxY + 60, width: 100, height: 31))
        resetLabel.text = "Password reset"
        resetLabel.font = UIFont(name: "SFCamera-Semibold", size: 22)
        resetLabel.textColor = UIColor(red:0.64, green:0.64, blue:0.64, alpha:1.00)
        resetLabel.sizeToFit()
        self.view.addSubview(resetLabel)
        
        
        //Load reset confirmation text
        confirmationLayer = UILabel(frame: CGRect(x: 108, y: 308 - heightAdjust, width: 236, height: 38))
        confirmationLayer.lineBreakMode = .byWordWrapping
        confirmationLayer.numberOfLines = 0
        confirmationLayer.textColor = UIColor(named: "SpotGreen")
        confirmationLayer.font = UIFont(name: "SFCamera-regular", size: 16)
        confirmationLayer.text = "Got it! Check your inbox for a link to reset your password."
        confirmationLayer.sizeToFit()
        self.view.addSubview(confirmationLayer)
        confirmationLayer.isHidden = true
        
        
        confirmationSymbol = UIImageView(frame: CGRect(x: 30, y: 298 - heightAdjust, width: 60, height: 60))
        confirmationSymbol.isHidden = true
        confirmationSymbol.image = UIImage(named: "CheckIcon")
        view.addSubview(confirmationSymbol)
        
        //load email label
        emailLabel = UILabel(frame: CGRect(x: 37, y: resetLabel.frame.maxY + 30, width: 100, height: 18))
        emailLabel.text = "Email"
        emailLabel.textColor = UIColor(named: "SpotGreen")
        emailLabel.font = UIFont(name: "SFCamera-Semibold", size: 13)
        emailLabel.sizeToFit()
        self.view.addSubview(emailLabel)
        
        //load email text field
        emailField = UITextField(frame: CGRect(x: 28.5, y: emailLabel.frame.maxY + 3, width: UIScreen.main.bounds.width - 57, height: 41))
        emailField.layer.cornerRadius = 10
        emailField.backgroundColor = UIColor(red:0.16, green:0.16, blue:0.16, alpha:0.5)
        emailField.layer.borderColor = UIColor(red:0.21, green:0.21, blue:0.21, alpha:1).cgColor
        emailField.layer.borderWidth = 1
        self.view.addSubview(emailField)
        
        emailField.textColor = UIColor.white
        emailField.font = UIFont(name: "SFCamera-regular", size: 16)!
        emailField.autocorrectionType = .no
        emailField.autocapitalizationType = .none
        emailField.textContentType = .username
        emailField.keyboardType = .emailAddress
        
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: self.emailField.frame.height))
        emailField.leftView = paddingView
        emailField.leftViewMode = UITextField.ViewMode.always
        
        
        //Load 'we'll send a link to reset your password'
        instructLayer = UILabel(frame: CGRect(x: 38, y: emailField.frame.maxY + 6, width: 313, height: 19))
        instructLayer.lineBreakMode = .byWordWrapping
        instructLayer.numberOfLines = 0
        instructLayer.textColor = UIColor(red:0.61, green:0.61, blue:0.61, alpha:1)
        instructLayer.text = "We’ll send a link to reset your password."
        instructLayer.font = UIFont(name: "SFCamera-regular", size: 14)!
        instructLayer.sizeToFit()
        self.view.addSubview(instructLayer)
        
        //Load 'Email Link' button background
        resetBtn = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 96, y: 412 - heightAdjust, width: 192, height: 45))
        resetBtn.contentMode = .scaleAspectFit
        resetBtn.setImage(UIImage(named: "SendLinkButton"), for: .normal)
        resetBtn.addTarget(self, action: #selector(handleReset(_:)), for: UIControl.Event.touchUpInside)
        self.view.addSubview(resetBtn)
        
        
        errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 80, width: UIScreen.main.bounds.width, height: 32))
        errorBox.backgroundColor = UIColor(red:0.35, green:0, blue:0.04, alpha:1)
        self.view.addSubview(errorBox)
        errorBox.isHidden = true
        
        //Load error text
        errorTextLayer = UILabel(frame: CGRect(x: 23, y: UIScreen.main.bounds.height - 73, width: UIScreen.main.bounds.width - 46, height: 18))
        errorTextLayer.lineBreakMode = .byWordWrapping
        errorTextLayer.numberOfLines = 0
        errorTextLayer.textColor = UIColor.white
        errorTextLayer.textAlignment = .center
        errorTextLayer.text = "Please enter a valid email address."
        errorTextLayer.font = UIFont(name: "SFCamera-regular", size: 14)
        self.view.addSubview(errorTextLayer)
        errorTextLayer.isHidden = true
        
    }
    @objc override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(false)
    }
    
    @objc func backTapped(_ sender: UIButton){
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Login") as? LoginViewController {
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }
    
    @objc func handleReset(_ sender: UIButton){
        guard let resetText = emailField.text else { return }
        
        if !isValidEmail(email: resetText) {
            
            errorBox.isHidden = false
            errorTextLayer.isHidden = false
            
        }else{
            
            Auth.auth().sendPasswordReset(withEmail: resetText, completion: nil)
                        
            //Hide initial fields, label, and button
            resetLabel.isHidden = true
            emailLabel.isHidden = true
            emailField.isHidden = true
            instructLayer.isHidden = true
            resetBtn.isHidden = true
            errorBox.isHidden = true
            errorTextLayer.isHidden = true
            
            //Show confirmation text and symbol
            confirmationSymbol.isHidden = false //show check mark
            confirmationLayer.isHidden = false  //show confirmation message
        }
        
    }
    
    //checks to see if valid email is entered
    func isValidEmail(email:String?) -> Bool {
        guard email != nil else { return false }
        let regEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let pred = NSPredicate(format:"SELF MATCHES %@", regEx)
        return pred.evaluate(with: email)
    }
    
    //Hide keyboard when user touches screen
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
        
    }
    
}

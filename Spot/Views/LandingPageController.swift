//
//  LandingPageController.swift
//  Spot
//
//  Created by kbarone on 4/8/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase

class LandingPageController: UIViewController {
    var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ///check to make sure user isnt signed in
        if Auth.auth().currentUser != nil {
            let sb = UIStoryboard(name: "TabBar", bundle: nil)
            let vc = sb.instantiateViewController(withIdentifier: "TabBarMain") as! CustomTabBar
            DispatchQueue.main.async {
                self.getTopMostViewController()?.present(vc, animated: true, completion: nil)
            }
        }
        
        imageView = UIImageView(frame: self.view.frame)
        imageView.image = UIImage(named: "LandingPage0")
        view.addSubview(imageView)
        self.animateGIF(directionUp: true, counter: 0)
        
        
        let gl0 = CAGradientLayer()
        let color0 = UIColor(named: "SpotBlack")!.withAlphaComponent(0.7).cgColor
        let color1 = UIColor.clear.cgColor
        gl0.colors = [color1, color0]
        gl0.startPoint = CGPoint(x: 0, y: 0.6)
        gl0.endPoint = CGPoint(x: 0, y: 1.0)
        gl0.frame = self.view.bounds
        self.view.layer.addSublayer(gl0)
        
        let gl1 = CAGradientLayer()
        gl1.colors = [color0, color1]
        gl1.startPoint = CGPoint(x: 0, y: 0.0)
        gl1.endPoint = CGPoint(x: 0, y: 0.35)
        gl1.frame = self.view.bounds
        self.view.layer.addSublayer(gl1)
        
        var heightAdjust: CGFloat = 0
        if (!(UIScreen.main.nativeBounds.height > 2300 || UIScreen.main.nativeBounds.height == 1792)) {
            heightAdjust = 20
        }
        
        
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
        
        let createAccountButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 118.5, y: UIScreen.main.bounds.height - 147, width: 237, height: 47))
        createAccountButton.contentMode = .scaleAspectFit
        createAccountButton.setImage(UIImage(named: "CreateAccountButton")!, for: .normal)
        createAccountButton.addTarget(self, action: #selector(createAccountTap(_:)), for: .touchUpInside)
        view.addSubview(createAccountButton)
        
        let beenHereBackground = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 81.5, y: createAccountButton.frame.maxY + 10, width: 153, height: 54))
        beenHereBackground.backgroundColor = UIColor(red:0.09, green:0.09, blue:0.09, alpha: 0.4)
        beenHereBackground.layer.cornerRadius = 5
        view.addSubview(beenHereBackground)
        
        let maskLayer = CAGradientLayer()
        maskLayer.frame = beenHereBackground.bounds
        maskLayer.shadowRadius = 5
        maskLayer.shadowPath = CGPath(roundedRect: beenHereBackground.bounds.insetBy(dx: 5, dy: 5), cornerWidth: 10, cornerHeight: 10, transform: nil)
        maskLayer.shadowOpacity = 1
        maskLayer.shadowOffset = CGSize.zero
        maskLayer.shadowColor =  UIColor(red:0.09, green:0.09, blue:0.09, alpha: 0.4).cgColor
        beenHereBackground.layer.mask = maskLayer
        
        let beenHereLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 100, y: createAccountButton.frame.maxY + 15, width: 200, height: 17))
        beenHereLabel.text = "Been here before?"
        beenHereLabel.textAlignment = .center
        beenHereLabel.textColor = UIColor(red:0.84, green:0.84, blue:0.84, alpha:1.00)
        beenHereLabel.font = UIFont(name: "SFCamera-Regular", size: 16)
        view.addSubview(beenHereLabel)
        
        let loginButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 80, y: beenHereLabel.frame.maxY, width: 160, height: 26))
        loginButton.setTitle("Log in", for: .normal)
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 18)
        loginButton.titleLabel?.textAlignment = .center
        loginButton.addTarget(self, action: #selector(loginTap(_:)), for: .touchUpInside)
        view.addSubview(loginButton)
    }
    
    @objc func createAccountTap(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SignUp") as? SignUpViewController {
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: false, completion: nil)
        }
        
    }
    
    @objc func loginTap(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Login") as? LoginViewController {
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }
    
    func animateGIF(directionUp: Bool, counter: Int) {
        var newDirection = directionUp
        var newCount = counter
        if directionUp {
            if counter == 4 {
                newDirection = false
                newCount = 3
            } else {
                newCount += 1
            }
        } else {
            if counter == 0 {
                newDirection = true
                newCount = 1
            } else {
                newCount -= 1
            }
        }
        var newImage = UIImage()
        
        switch newCount {
        case 0:
            newImage = UIImage(named: "LandingPage0")!
        case 1:
            newImage = UIImage(named: "LandingPage1")!
        case 2:
            newImage = UIImage(named: "LandingPage2")!
        case 3:
            newImage = UIImage(named: "LandingPage3")!
        default:
            newImage = UIImage(named: "LandingPage4")!
        }
        
        UIView.animate(withDuration: 0.10, delay: 0.0, options: .transitionCrossDissolve, animations: {
            self.imageView.image = newImage
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            guard let self = self else { return }
            self.animateGIF(directionUp: newDirection, counter: newCount)
        }
    }

}

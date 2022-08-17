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
import AVKit
import Mixpanel

class LandingPageController: UIViewController {
    
    var playerLooper: AVPlayerLooper!
    var playerLayer: AVPlayerLayer!
    var videoPlayer: AVQueuePlayer!
    var thumbnailImage: UIImageView! /// show preview thumbnail while video is buffering
    var videoPreviewView: UIView!
    var firstLoad = true /// determine whether video player has been loaded yet
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "LandingPageOpen")
    }
    
    deinit {
        if videoPlayer != nil { videoPlayer.removeObserver(self, forKeyPath: "status") }
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil) /// deinit player on send to background
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil) /// deinit player on resign active
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil) /// reinit player on send to foreground
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil) /// reinit player on become active
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        //setUpVideoLayer()
        
        var heightAdjust: CGFloat = 0
        if UIScreen.main.bounds.height < 800 { heightAdjust = 20 }
        

        let createAccountButton = UIButton {
            $0.layer.cornerRadius = 15
            $0.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            let customButtonTitle = NSMutableAttributedString(string: "Create account", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
                NSAttributedString.Key.foregroundColor: UIColor.black
            ])
            $0.setAttributedTitle(customButtonTitle, for: .normal)
            $0.setImage(nil, for: .normal)
            $0.addTarget(self, action: #selector(createAccountTap(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        
        
        createAccountButton.snp.makeConstraints{
            $0.leading.trailing.equalToSuperview().inset(50)
            $0.height.equalTo(58)
            $0.top.equalToSuperview().offset(351)
        }

        let loginButton = UIButton {
            $0.layer.cornerRadius = 15
            $0.backgroundColor = .white
            $0.layer.borderWidth = 1.0
            $0.layer.borderColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1).cgColor
            let customButtonTitle = NSMutableAttributedString(string: "Log in", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
                NSAttributedString.Key.foregroundColor: UIColor.black
            ])
            $0.setAttributedTitle(customButtonTitle, for: .normal)
            $0.setImage(nil, for: .normal)
            $0.addTarget(self, action: #selector(loginWithPhoneTap(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        
        
        loginButton.snp.makeConstraints{
            $0.leading.trailing.equalToSuperview().inset(50)
            $0.height.equalTo(58)
            $0.top.equalTo(createAccountButton.snp.bottom).offset(16)
        }
        
        let loginButton2 = UIButton {
            $0.layer.cornerRadius = 15
            $0.backgroundColor = .black
            $0.layer.borderWidth = 1.0
            $0.layer.borderColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1).cgColor
            let customButtonTitle = NSMutableAttributedString(string: "Log in with email", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15),
                NSAttributedString.Key.foregroundColor: UIColor.white
            ])
            $0.setAttributedTitle(customButtonTitle, for: .normal)
            $0.setImage(nil, for: .normal)
            $0.addTarget(self, action: #selector(loginWithEmailTap(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        
        
        loginButton2.snp.makeConstraints{
            $0.leading.trailing.equalToSuperview().inset(50)
            $0.height.equalTo(58)
            $0.top.equalTo(loginButton.snp.bottom).offset(16)
        }
        
        
        let titleScreen = UIView {
            view.addSubview($0)
        }
        
        titleScreen.snp.makeConstraints{
            $0.height.equalTo(60)
            $0.top.equalToSuperview().offset(208)
            $0.width.equalTo(106)
            $0.centerX.equalToSuperview()
        }
        
        let logo = UIImageView {
            $0.contentMode = .center
            $0.image = UIImage(named: "sp0tLogo")
            titleScreen.addSubview($0)
        }
        
        logo.snp.makeConstraints{
            $0.leading.equalToSuperview()
            $0.width.equalTo(38.32)
            $0.height.equalTo(55.95)
            $0.bottom.equalToSuperview()
        }
        
        let title = UILabel {
            $0.text = "SPOT"
            $0.font = UIFont(name: "SFCompactRounded-Black", size: 32)
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            titleScreen.addSubview($0)
        }
        
      title.snp.makeConstraints{
            $0.bottom.equalToSuperview()
            $0.leading.equalTo(logo.snp.trailing).offset(-10)
        }
        
        let subTitle = UILabel {
            $0.text = "Share your world"
            $0.font = UIFont(name: "SFCompactText-Bold", size: 22)
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            view.addSubview($0)
        }
        
        subTitle.snp.makeConstraints{
            $0.top.equalTo(titleScreen.snp.bottom).offset(9.05)
            $0.centerX.equalToSuperview()
        }
        
        
        
    }
    
    @objc func createAccountTap(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SignUp") as? SignUpController {
            let navController = UINavigationController(rootViewController: vc)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: false, completion: nil)
        }
    }
    
    @objc func loginWithEmailTap(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "EmailLogin") as? EmailLoginController {
            let navController = UINavigationController(rootViewController: vc)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: false, completion: nil)
        }
    }
    
    @objc func loginWithPhoneTap(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PhoneVC") as? PhoneController {
            
            vc.codeType = .logIn
            
            let navController = UINavigationController(rootViewController: vc)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: false, completion: nil)
        }
    }
}

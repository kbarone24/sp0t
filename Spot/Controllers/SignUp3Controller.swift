//
//  SignUp3Controller.swift
//  Spot
//
//  Created by kbarone on 4/9/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import CoreLocation
import Mixpanel

class SignUp3Controller: UIViewController {
    
    private let locationManager = CLLocationManager()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "SignUp3Open")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var heightAdjust: CGFloat = 0
        if (!(UIScreen.main.nativeBounds.height > 2300 || UIScreen.main.nativeBounds.height == 1792)) {
            heightAdjust = 20
        }
        
        let logoImage = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 45, y: 52 - heightAdjust, width: 90, height: 36))
        logoImage.image = UIImage(named: "MapSp0tLogo")
        logoImage.contentMode = .scaleAspectFit
        view.addSubview(logoImage)
        
        let createText = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 95, y: logoImage.frame.maxY + 20, width: 190, height: 30))
        createText.textAlignment = .center
        createText.text = "Create account"
        createText.textColor = UIColor(red:0.64, green:0.64, blue:0.64, alpha:1.00)
        createText.font = UIFont(name: "SFCamera-Semibold", size: 18)
        view.addSubview(createText)
        
        addDotView(y: createText.frame.maxY + 4)
        
        let seeText = UILabel(frame: CGRect(x: 40, y: logoImage.frame.maxY + 200, width: UIScreen.main.bounds.width - 80, height: 65))
        seeText.text = "See which of your friends are already on sp0t"
        seeText.textColor = UIColor(red:0.79, green:0.79, blue:0.79, alpha:1.00)
        seeText.font = UIFont(name: "SFCamera-Regular", size: 20)
        seeText.lineBreakMode = .byWordWrapping
        seeText.textAlignment = .center
        seeText.numberOfLines = 0
        //   seeText.sizeToFit()
        view.addSubview(seeText)
        
        let searchContactsButton = UIButton(frame: CGRect(x: 50, y: seeText.frame.maxY + 12, width: UIScreen.main.bounds.width - 100, height: 50))
        searchContactsButton.imageView?.contentMode = .scaleAspectFit
        searchContactsButton.setImage(UIImage(named: "OnboardSearchContactsButton"), for: .normal)
        searchContactsButton.addTarget(self, action: #selector(searchContactsTap(_:)), for: .touchUpInside)
        view.addSubview(searchContactsButton)
        
        let skipButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 60, y: UIScreen.main.bounds.height - 70, width: 40, height: 20))
        skipButton.setTitle("Skip", for: .normal)
        skipButton.setTitleColor(UIColor(red:0.60, green:0.60, blue:0.60, alpha:1.00), for: .normal)
        skipButton.titleLabel?.contentMode = .scaleAspectFit
        skipButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 15)
        skipButton.addTarget(self, action: #selector(skipTap(_:)), for: .touchUpInside)
        view.addSubview(skipButton)
        
    }
    
    @objc func searchContactsTap(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(withIdentifier: "SearchContacts") as? SearchContactsViewController {
            vc.sentFromTutorial = true
            self.present(vc, animated: true, completion: nil)
        }
    }
    
    @objc func skipTap(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "TabBar", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MapView") as! MapViewController
        let navController = UINavigationController(rootViewController: vc)
        navController.modalPresentationStyle = .fullScreen
        
        let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow}).first
        keyWindow?.rootViewController = navController
    }
    
    func addDotView(y: CGFloat) {
        let dotView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 16, y: y, width: 32, height: 10))
        dotView.backgroundColor = nil
        self.view.addSubview(dotView)
        
        let dot1 = UIImageView(frame: CGRect(x: 0, y: 0, width: 8, height: 8))
        dot1.layer.cornerRadius = 4
        dot1.image = UIImage(named: "ElipsesFilled")
        dotView.addSubview(dot1)
        
        let dot2 = UIImageView(frame: CGRect(x: 12, y: 0, width: 8, height: 8))
        dot2.layer.cornerRadius = 4
        dot2.image = UIImage(named: "ElipsesFilled")
        dotView.addSubview(dot2)
        
        let dot3 = UIImageView(frame: CGRect(x: 24, y: 0, width: 8, height: 8))
        dot3.layer.cornerRadius = 4
        dot3.image = UIImage(named: "ElipsesFilled")
        dotView.addSubview(dot3)
    }
}

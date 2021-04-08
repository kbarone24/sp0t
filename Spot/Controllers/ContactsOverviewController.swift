//
//  ContactsOverviewController.swift
//  Spot
//
//  Created by Kenny Barone on 3/27/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

class ContactsOverviewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        navigationItem.title = ""

        navigationController?.navigationBar.backIndicatorImage = UIImage()
        navigationController?.navigationBar.backIndicatorTransitionMaskImage = UIImage()

        let label = UILabel(frame: CGRect(x: 14, y: 225, width: UIScreen.main.bounds.width - 28, height: 16))
        label.text = "See which of your friends are already on sp0t!"
        label.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        label.font = UIFont(name: "SFCamera-Regular", size: 15)
        label.clipsToBounds = false
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        view.addSubview(label)
        
        let searchContactsButton = UIButton(frame: CGRect(x: (UIScreen.main.bounds.width - 284)/2, y: label.frame.maxY + 24, width: 284, height: 48))
        searchContactsButton.setImage(UIImage(named: "OnboardSearchContactsButton"), for: .normal)
        searchContactsButton.addTarget(self, action: #selector(searchContactsTap(_:)), for: .touchUpInside)
        view.addSubview(searchContactsButton)
        
        let skipButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 50, y: searchContactsButton.frame.maxY + 15, width: 100, height: 36))
        skipButton.setTitle("Skip", for: .normal)
        skipButton.setTitleColor(UIColor(red: 0.479, green: 0.479, blue: 0.479, alpha: 1), for: .normal)
        skipButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 15)
        skipButton.backgroundColor = nil
        skipButton.contentHorizontalAlignment = .center
        skipButton.contentVerticalAlignment = .center
        skipButton.addTarget(self, action: #selector(skipTap(_:)), for: .touchUpInside)
        view.addSubview(skipButton)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "ContactsOverviewOpen")
    }
    
    @objc func searchContactsTap(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(withIdentifier: "SearchContacts") as? SearchContactsViewController {
            vc.sentFromTutorial = true
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @objc func skipTap(_ sender: UIButton) {
        
        let storyboard = UIStoryboard(name: "TabBar", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MapView") as! MapViewController
        vc.tutorialMode = true
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
}

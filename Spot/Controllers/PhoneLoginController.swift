//
//  PhoneLoginController.swift
//  Spot
//
//  Created by Kenny Barone on 3/26/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class PhoneLoginController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        navigationController?.navigationBar.setBackgroundImage(UIImage(color: UIColor(named: "SpotBlack")!), for: .default)
        
        navigationItem.title = "Log in"
        let backArrow = UIImage(named: "BackArrow")?.withRenderingMode(.alwaysOriginal)
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: backArrow, style: .plain, target: self, action: #selector(backTapped(_:)))
    }
    
    
    
    @objc func backTapped(_ sender: UIButton) {
        self.dismiss(animated: false, completion: nil)
    }
    
}

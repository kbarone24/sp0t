//
//  ProfileViewController.swift
//  Spot
//
//  Created by Kenny Barone on 6/6/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class ProfileViewController: UIViewController, UIViewControllerTransitioningDelegate {
    
    // function for adding profileViewController
    @objc func addView(_ sender: UIButton){
        let newVC = ProfileViewController()
        self.navigationController?.pushViewController(newVC, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        modalPresentationStyle = .custom
        transitioningDelegate = self
        
        //dummy button for adding profileViewController
        let myButton = UIButton(type: .system)
        myButton.frame = CGRect(x: 20, y: 20, width: 100, height: 50)
        myButton.setTitle("AddView", for: .normal)
        
        myButton.addTarget(self, action: #selector(addView(_:)), for: .touchUpInside)
        
        view.addSubview(myButton)
        self.view = view
    }
    
    override func viewWillAppear(_ animated: Bool){
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //print("did Appear")
    }
    
    override func viewWillDisappear(_ animated: Bool){
        super.viewWillDisappear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool){
        super.viewDidDisappear(animated)
        //print("did DISappear")
    }
    

    
    /*func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        
        let controller = UIPresentationController(presentedViewController: presented, presenting: presenting)
        
        if #available(iOS 15.0, *) {
            let controller: UISheetPresentationController = .init(presentedViewController: presented, presenting: presenting)
            let detent1: UISheetPresentationController.Detent = ._detent(withIdentifier: "Test1", constant: 100.0)
            
            controller.detents = [detent1, .medium(), .large()]
            controller.prefersScrollingExpandsWhenScrolledToEdge = false
            controller.largestUndimmedDetentIdentifier = .medium
            controller.preferredCornerRadius = 20
            controller.prefersGrabberVisible = true
            
            return controller
        } else {
            return controller// Fallback on earlier versions
        }
    }*/
        

}




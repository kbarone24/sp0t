//
//  HalfSheetViewController.swift
//  Spot
//
//  Created by Shay Gyawali on 6/10/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

@available(iOS 15.0, *)
class BottomDrawerViewController: UINavigationController{
  
    var vc : UIViewController
    
    override init(rootViewController : UIViewController){

        vc = rootViewController
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        
        super.init(nibName: nil, bundle: nil)

            //creating sheet controller
        if let sheet = self.sheetPresentationController {
            //custom detent
            let detent1: UISheetPresentationController.Detent = ._detent(withIdentifier: "Test1", constant: 100.0)
            sheet.detents = [detent1, .medium(), .large()]
            //other optional vars
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.largestUndimmedDetentIdentifier = .medium
            sheet.preferredCornerRadius = 20
            sheet.prefersGrabberVisible = true

        }

        self.viewControllers = [rootViewController]
        self.modalPresentationStyle = .pageSheet
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    ///alternative implementation
    /*func getSheetController()-> UINavigationController?{

     let nav = UINavigationController(rootViewController: vc)
     nav.modalPresentationStyle = .pageSheet

      if #available(iOS 15.0, *) {
         //creating sheet controller
         if let sheet = nav.sheetPresentationController {
             //custom detent
             let detent1: UISheetPresentationController.Detent = ._detent(withIdentifier: "Test1", constant: 100.0)
             sheet.detents = [detent1, .medium(), .large()]
             //other optional vars
             sheet.prefersScrollingExpandsWhenScrolledToEdge = false
             sheet.largestUndimmedDetentIdentifier = .medium
             sheet.preferredCornerRadius = 20
             sheet.prefersGrabberVisible = true

         }
     } else {
         // Fallback on earlier versions -- IOS >15 sheet here
     }
     
     return nav
     
    }*/
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
    

    
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        
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
    
    
    
     }
}
    

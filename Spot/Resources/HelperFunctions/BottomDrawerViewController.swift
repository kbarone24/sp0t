//
//  HalfSheetViewController.swift
//  Spot
//
//  Created by Shay Gyawali on 6/10/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

@available(iOS 15.0, *)
class BottomDrawerViewController: UINavigationController{
  
    var vc : UIViewController
    
    override init(rootViewController : UIViewController){

        vc = rootViewController
        //let nav = UINavigationController(rootViewController: vc)
        //nav.modalPresentationStyle = .pageSheet
        
        super.init(nibName: nil, bundle: nil)

            //creating sheet controller
        if let sheet = self.sheetPresentationController {
            //custom detent
            let detent1: UISheetPresentationController.Detent = ._detent(withIdentifier: "Test1", constant: 100.0)
            sheet.detents = [.medium(), detent1, .large()]
            //other optional vars
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.largestUndimmedDetentIdentifier = .large
            sheet.preferredCornerRadius = 20
            sheet.prefersGrabberVisible = true

        }

        self.viewControllers = [rootViewController]
        self.modalPresentationStyle = .pageSheet
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let exitDrawer = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 81, y: 10, width: 71, height: 71))
        exitDrawer.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        exitDrawer.setImage(UIImage(named: "FeedExit"), for: .normal)
        exitDrawer.addTarget(self, action: #selector(dismissDrawer(_:)), for: .touchUpInside)
        view.addSubview(exitDrawer)
        let bottomLine = UIView(frame: CGRect(x: 0, y: 100, width: UIScreen.main.bounds.width, height: 1))
        bottomLine.backgroundColor = UIColor(red: 0.922, green: 0.922, blue: 0.922, alpha: 1)
        view.addSubview(bottomLine)
        
    }
    
    override func viewWillAppear(_ animated: Bool){
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool){
        super.viewWillDisappear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool){
        super.viewDidDisappear(animated)
    }
    
    @objc func dismissDrawer(_ sender: UIButton){
        navigationController?.popViewController(animated: true)

        self.dismiss(animated: true, completion: nil)
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
    

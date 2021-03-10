//
//  TabBarController.swift
//  Spot
//
//  Created by kbarone on 8/26/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase

class CustomTabBar: UITabBarController {
    @IBInspectable var defaultIndex: Int = 0
        
    var mapVC: MapViewController!
    var cameraController: AVCameraController!
    
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

    override func viewDidLoad() {
        self.view.tag = 8
        
        super.viewDidLoad()
        
        self.tabBar.items?[2].image = UIImage(named: "CameraLaunchButton")?.withRenderingMode(.alwaysOriginal)
     
        mapVC = MapViewController()
        if self.parent?.isKind(of: MapViewController.self) ?? false {
            mapVC = (parent as! MapViewController)
            self.delegate = mapVC
        }
        cameraController = AVCameraController()
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(tabBarPan(_:)))
        self.tabBar.addGestureRecognizer(pan)
        
        let notificationRef = self.db.collection("users").document(self.uid).collection("notifications")
        let query = notificationRef.whereField("seen", isEqualTo: false)
        
        query.addSnapshotListener(includeMetadataChanges: true) { (snap, err) in
            if err != nil || snap?.metadata.isFromCache ?? false {
                return
            } else {
                if snap!.documents.count > 0 {
                    self.tabBar.items?[3].image = UIImage(named: "NotificationIconFilled")?.withRenderingMode(.alwaysOriginal)
                }
            }
        }
    }
    
    //tab bar pan to open camera on swipe up
    @objc func tabBarPan(_ sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .ended, .cancelled:
            let direction = sender.velocity(in: view).y
            if direction < -300 {
                pushCamera()
            }
        default:
            return
        }
    }
    
    func pushCamera() {
        let transition = CATransition()
        transition.duration = 0.3
        transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        transition.type = CATransitionType.push
        transition.subtype = CATransitionSubtype.fromTop
        navigationController?.view.layer.add(transition, forKey: kCATransition)
        navigationController?.pushViewController(cameraController, animated: false)
    }
}

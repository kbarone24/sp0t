//
//  DrawerView.swift
//  Spot
//
//  Created by Arnold on 6/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SnapKit

enum Status {
    case Top
    case Middle
    case Bottom
    case Close
}

class DrawerView: NSObject {
        
    private lazy var slideView = UIView {
        $0.backgroundColor = .white
        $0.layer.cornerRadius = 10
        $0.layer.shadowColor = UIColor.black.cgColor
        $0.layer.shadowOffset = CGSize(width: 2, height: 2)
        $0.layer.shadowOpacity = 0.8
        $0.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private lazy var closeButton = UIButton {
        $0.backgroundColor = .clear
        $0.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: UIImage.SymbolConfiguration(textStyle: .largeTitle))?.withTintColor(.tertiarySystemFill, renderingMode: .alwaysOriginal), for: .normal)
        $0.setTitle("", for: .normal)
    }
    
    private lazy var grabberView = UIView {
        $0.backgroundColor = .tertiarySystemFill
        $0.layer.cornerRadius = 2
    }
    
    private var rootController = UIViewController()
    private var parentController: UIViewController = UIApplication.shared.keyWindow?.rootViewController ?? UIViewController()
    private var status = Status.Close
    
    override init() {
        super.init()
    }
    public init(present: UIViewController = UIViewController(), drawerConrnerRadius: CGFloat = 20) {
        super.init()
        if let parent = UIApplication.shared.keyWindow?.rootViewController as? UINavigationController {
            if parent.visibleViewController != nil {
                parentController = parent.visibleViewController!
            }
        }
        self.rootController = present
        self.slideView.layer.cornerRadius = drawerConrnerRadius
        viewSetup(cornerRadius: drawerConrnerRadius)
    }
    
    private func viewSetup(cornerRadius: CGFloat) {
        parentController.view.addSubview(slideView)
        slideView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.greaterThanOrEqualTo(parentController.view.snp.top).offset(0.45 * parentController.view.frame.height)
            $0.height.equalTo(parentController.view.snp.height)
        }
        slideView.frame = CGRect(x: 0, y: parentController.view.frame.height - 100, width: parentController.view.frame.width, height: parentController.view.frame.height)
        slideView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panPerforming(recognizer:))))
       
        let myNav = UINavigationController(rootViewController: rootController)
        parentController.addChild(myNav)
        slideView.addSubview(myNav.view)
        myNav.view.frame = CGRect(origin: .zero, size: slideView.frame.size)
        myNav.view.layer.cornerRadius = cornerRadius
        myNav.view.layer.masksToBounds = true
        myNav.didMove(toParent: parentController)
        
        slideView.addSubview(grabberView)
        grabberView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(10)
            $0.width.equalTo(60)
            $0.height.equalTo(4)
            $0.centerX.equalToSuperview()
        }
        
        slideView.addSubview(closeButton)
        closeButton.snp.makeConstraints {
            $0.top.trailing.equalToSuperview()
            $0.width.height.equalTo(70)
        }
        closeButton.addTarget(self, action: #selector(self.closeAction), for: .touchUpInside)
    }
    
    @objc func panPerforming(recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: recognizer.view)
        if recognizer.state == .began || recognizer.state == .changed {
            if slideView.frame.minY >= parentController.view.frame.height - slideView.frame.height {
                slideView.frame.origin.y += translation.y
            }
            recognizer.setTranslation(.zero, in: recognizer.view)
        }
        else{
            UIView.animate(withDuration: 0.35, animations: {
                self.slideView.frame.origin.y =  (self.slideView.frame.minY > self.parentController.view.frame.height * 0.6) ? (self.parentController.view.frame.height - 100):(self.slideView.frame.minY < self.parentController.view.frame.height * 0.28) ? (self.parentController.view.frame.height - self.slideView.frame.height + 100):(0.45 * self.parentController.view.frame.height) // Bottom:Top:Middle
                self.parentController.view.layoutIfNeeded()
            }) { (success) in
                self.status = (self.slideView.frame.minY > self.parentController.view.frame.height * 0.6) ? Status.Bottom:(self.slideView.frame.minY < self.parentController.view.frame.height * 0.28) ? Status.Top:Status.Middle
            }
        }
    }
    
    @objc func closeAction() {
        UIView.animate(withDuration: 0.35, animations: {
            self.slideView.frame.origin.y = self.parentController.view.frame.height
            self.parentController.view.layoutIfNeeded()
        }) { (success) in
            self.status = Status.Close
        }
    }
    
    public func present() {
        switch status {
        case .Top, .Bottom:
            UIView.animate(withDuration: 0.35) {
                self.slideView.frame.origin.y = (0.45 * self.parentController.view.frame.height)
            } completion: { success in
                self.status = Status.Middle
            }
        case .Middle:
            let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
            animation.values = [0, -20, 0]
            animation.duration = 0.5
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
            slideView.layer.add(animation, forKey: nil)
        case .Close:
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
                self.slideView.frame.origin.y = 0.45 * self.parentController.view.frame.height
            }) { (success) in
                self.status = Status.Middle
            }
        }
    }
    
//    public func shownAlready() {
//        if slideView.frame.origin.y == (self.parentController.view.frame.height - 100) || (self.slideView.frame.minY < self.parentController.view.frame.height * 0.28) {
//            UIView.animate(withDuration: 0.35) {
//                self.slideView.frame.origin.y = (0.45 * self.parentController.view.frame.height)
//            } completion: { success in
//                self.status = Status.Middle
//            }
//        } else {
//            let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
//            animation.values = [0, -20, 0]
//            animation.duration = 0.5
//            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
//            slideView.layer.add(animation, forKey: nil)
//            status = Status.Middle
//        }
//    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

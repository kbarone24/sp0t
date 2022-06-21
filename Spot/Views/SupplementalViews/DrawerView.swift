//
//  DrawerView.swift
//  Spot
//
//  Created by Arnold on 6/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SnapKit

enum DrawerViewStatus {
    case Top
    case Middle
    case Bottom
    case Close
}

class DrawerView: NSObject {
    private lazy var slideView = UIView {
        $0.backgroundColor = .clear
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
    
    private var rootVC = UIViewController()
    private unowned var parentVC: UIViewController = UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.rootViewController ?? UIViewController()
    
    private var panRecognizer: UIPanGestureRecognizer?
    private var status = DrawerViewStatus.Close
    private var duration: CGFloat = 0
    private var yPosition: CGFloat = 0
    private var topConstraints: Constraint? = nil
    private var midConstraints: Constraint? = nil
    private var botConstraints: Constraint? = nil
    public var canDrag: Bool = true {
        didSet {
            toggleDrag(to: canDrag)
        }
    }
    
    override init() {
        super.init()
    }
    public init(present: UIViewController = UIViewController(), drawerConrnerRadius: CGFloat = 20) {
        super.init()
        if let parent = UIApplication.shared.windows.filter({$0.isKeyWindow}).first?.rootViewController as? UINavigationController {
            if parent.visibleViewController != nil {
                parentVC = parent.visibleViewController!
            }
        }
        self.rootVC = present
        self.slideView.layer.cornerRadius = drawerConrnerRadius
        viewSetup(cornerRadius: drawerConrnerRadius)
    }
    
    private func viewSetup(cornerRadius: CGFloat) {
        parentVC.view.addSubview(slideView)
        slideView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            topConstraints = $0.top.greaterThanOrEqualTo(parentVC.view.snp.top).offset(100).constraint
            midConstraints = $0.top.greaterThanOrEqualTo(parentVC.view.snp.top).offset(0.45 * parentVC.view.frame.height).constraint
            botConstraints = $0.top.greaterThanOrEqualTo(parentVC.view.snp.bottom).inset(100).constraint
            $0.height.equalTo(parentVC.view.snp.height)
        }
        topConstraints?.deactivate()
        midConstraints?.deactivate()
        botConstraints?.deactivate()
        slideView.frame = CGRect(x: 0, y: parentVC.view.frame.height, width: parentVC.view.frame.width, height: parentVC.view.frame.height)
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panPerforming(recognizer:)))
        slideView.addGestureRecognizer(panRecognizer!)
        let myNav = UINavigationController(rootViewController: rootVC)
        parentVC.addChild(myNav)
        slideView.addSubview(myNav.view)
        myNav.view.frame = CGRect(origin: .zero, size: slideView.frame.size)
        myNav.view.layer.cornerRadius = cornerRadius
        myNav.view.layer.masksToBounds = true
        myNav.didMove(toParent: parentVC)
        slideView.addSubview(grabberView)
        grabberView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(10)
            $0.width.equalTo(40)
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
    
    public func present(to: DrawerViewStatus = .Middle) {
        let currentStatus = status
        switch to {
        case .Top:
            goTop()
        case .Middle, .Close:
            goMid()
        case .Bottom:
            goBot()
        }
        if currentStatus != to {
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
                self.slideView.frame.origin.y = self.yPosition
            }, completion: nil)
        } else {
            let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
            animation.values = [0, -20, 0]
            animation.duration = 0.5
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
            slideView.layer.add(animation, forKey: nil)
        }
    }
    
    private func goTop() {
        topConstraints?.activate()
        let sheetPresentVelocity = 0.35 * self.parentVC.view.frame.height / 0.5
        duration = abs((self.parentVC.view.frame.height - self.slideView.frame.height + 100 - self.slideView.frame.origin.y) / sheetPresentVelocity)
        yPosition = (self.parentVC.view.frame.height - self.slideView.frame.height + 100)
        self.status = DrawerViewStatus.Top
    }
    private func goMid() {
        midConstraints?.activate()
        let sheetPresentVelocity = 0.35 * self.parentVC.view.frame.height / 0.5
        duration = abs((0.45 * self.parentVC.view.frame.height - self.slideView.frame.origin.y) / sheetPresentVelocity)
        yPosition = (0.45 * self.parentVC.view.frame.height)
        self.status = DrawerViewStatus.Middle
    }
    private func goBot() {
        botConstraints?.activate()
        let sheetPresentVelocity = 0.35 * self.parentVC.view.frame.height / 0.5
        duration = abs((self.parentVC.view.frame.height - 100 - self.slideView.frame.origin.y) / sheetPresentVelocity)
        yPosition = self.parentVC.view.frame.height - 100
        self.status = DrawerViewStatus.Bottom
    }
    
    private func toggleDrag(to: Bool) {
        to ? slideView.addGestureRecognizer(panRecognizer!):slideView.removeGestureRecognizer(panRecognizer!)
    }
    
    // Pan gesture
    @objc func panPerforming(recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: recognizer.view)
        if recognizer.state == .began || recognizer.state == .changed {
            // When the user is still dragging or start dragging the if statement here will be fall through
            if slideView.frame.minY >= parentVC.view.frame.height - slideView.frame.height {
                slideView.frame.origin.y += translation.y
            }
            recognizer.setTranslation(.zero, in: recognizer.view)
        }
        else{
            // Check the velocity of gesture to determine if it's a swipe or a drag
            if abs(recognizer.velocity(in: recognizer.view).y) > 1000 {
                // Swipe up velocity is smaller than 0
                switch status {
                case .Top:
                    recognizer.velocity(in: recognizer.view).y <= 0 ? goTop():goMid()
                case .Middle:
                    recognizer.velocity(in: recognizer.view).y <= 0 ? goTop():goBot()
                case .Bottom:
                    recognizer.velocity(in: recognizer.view).y <= 0 ? goMid():goBot()
                case .Close:
                    return
                }
            } else {
                if self.slideView.frame.minY > self.parentVC.view.frame.height * 0.6 {
                    goBot()
                } else if self.slideView.frame.minY < self.parentVC.view.frame.height * 0.28 {
                    goTop()
                } else {
                    goMid()
                }
            }
            UIView.animate(withDuration: duration) {
                self.slideView.frame.origin.y = self.yPosition
                self.parentVC.view.layoutIfNeeded()
            }
        }
    }
    
    @objc func closeAction() {
        UIView.animate(withDuration: 0.35, animations: {
            self.slideView.frame.origin.y = self.parentVC.view.frame.height
            self.parentVC.view.layoutIfNeeded()
        }) { (success) in
            self.status = DrawerViewStatus.Close
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//
//  DrawerView.swift
//  Spot
//
//  Created by Arnold on 6/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SnapKit

enum DrawerViewStatus: Int {
    case Bottom = 0
    case Middle = 1
    case Top = 2
    case Close = 3
}
enum DrawerViewDetent: Int {
    case Bottom = 0
    case Middle = 1
    case Top = 2
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
    private lazy var myNav = UINavigationController()
    private lazy var closeButton = UIButton {
        $0.backgroundColor = .clear
        $0.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: UIImage.SymbolConfiguration(textStyle: .largeTitle))?.withTintColor(.tertiarySystemFill, renderingMode: .alwaysOriginal), for: .normal)
        $0.setTitle("", for: .normal)
    }
    private lazy var grabberView = UIView {
        $0.backgroundColor = .tertiarySystemFill
        $0.layer.cornerRadius = 2
    }
    private lazy var grabBarOnTop = UIView {
        $0.backgroundColor = .clear
    }
    private let transitionAnimation = BottomToTopTransition()
    
    private var rootVC = UIViewController()
    private unowned var parentVC: UIViewController = UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.rootViewController ?? UIViewController()
    
    private var panRecognizer: UIPanGestureRecognizer?
    public var status = DrawerViewStatus.Close// {
//        didSet {
//            switch status {
//            case .Bottom:
//                present(to: .Bottom)
//            case .Middle:
//                present(to: .Middle)
//            case .Top:
//                present(to: .Top)
//            case .Close:
//                closeAction()
//            }
//        }
//    }
    private var yPosition: CGFloat = 0
    private var topConstraints: Constraint? = nil
    private var midConstraints: Constraint? = nil
    private var botConstraints: Constraint? = nil
    public var canDrag: Bool = true {
        didSet {
            toggleDrag(to: canDrag)
        }
    }
    public var showCloseButton: Bool = true {
        didSet {
            closeButton.isHidden = !showCloseButton
        }
    }
    public var swipeDownToDismiss: Bool = false
    private var detents: [DrawerViewDetent] = [.Bottom, .Middle, .Top]
    private var detentsPointer = 0 {
        didSet {
            if detentsPointer > detents.count - 1 {
                detentsPointer = detents.count - 1
            }
            if detentsPointer < 0 {
                detentsPointer = 0
            }
        }
    }
    private var closeDo: (() -> Void)? = nil
    
    override init() {
        super.init()
    }
    public init(present: UIViewController = UIViewController(), drawerConrnerRadius: CGFloat = 20, detentsInAscending: [DrawerViewDetent] = [.Bottom, .Middle, .Top], closeAction: (() -> Void)? = nil) {
        super.init()
        if let parent = UIApplication.shared.windows.filter({$0.isKeyWindow}).first?.rootViewController as? UINavigationController {
            if parent.visibleViewController != nil {
                parentVC = parent.visibleViewController!
            }
        }
        rootVC = present
        slideView.layer.cornerRadius = drawerConrnerRadius
        detents = detentsInAscending
        viewSetup(cornerRadius: drawerConrnerRadius)
        closeDo = closeAction
    }
    
    private func viewSetup(cornerRadius: CGFloat) {
        parentVC.view.addSubview(slideView)
        slideView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            topConstraints = $0.top.greaterThanOrEqualTo(parentVC.view.snp.top).constraint
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
        myNav = UINavigationController(rootViewController: rootVC)
        myNav.delegate = self
        parentVC.addChild(myNav)
        slideView.addSubview(myNav.view)
        myNav.view.frame = CGRect(origin: .zero, size: slideView.frame.size)
        myNav.view.layer.cornerRadius = cornerRadius
        myNav.view.layer.masksToBounds = true
        myNav.didMove(toParent: parentVC)
        myNav.navigationBar.setBackgroundImage(UIImage(), for: .default)
        myNav.navigationBar.shadowImage = UIImage()
        myNav.navigationBar.isTranslucent = true
        slideView.addSubview(grabberView)
        grabberView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(10)
            $0.width.equalTo(40)
            $0.height.equalTo(4)
            $0.centerX.equalToSuperview()
        }
        slideView.addSubview(grabBarOnTop)
        grabBarOnTop.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(50)
        }
        slideView.addSubview(closeButton)
        closeButton.snp.makeConstraints {
            $0.trailing.equalToSuperview()
            $0.top.equalToSuperview().offset(30)
            $0.width.height.equalTo(70)
        }
        closeButton.addTarget(self, action: #selector(self.closeAction), for: .touchUpInside)
        closeButton.isHidden = !showCloseButton
    }
    
    public func present(to: DrawerViewDetent = .Middle) {
        let currentStatus = status
        switch to {
        case .Top:
            goTop()
        case .Middle:
            goMid()
        case .Bottom:
            goBottom()
        }
        print("myNav", myNav)
        detentsPointer = detents.firstIndex(of: DrawerViewDetent(rawValue: to.rawValue)!) ?? 0
        if currentStatus.rawValue != to.rawValue {
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
    
    // MARK: Set position functions
    private func goTop() -> (() -> Void)? {
        topConstraints?.activate()
        yPosition = 0
        return { self.status = DrawerViewStatus.Top }
    }
    private func goMid() -> (() -> Void)? {
        midConstraints?.activate()
        yPosition = (0.45 * self.parentVC.view.frame.height)
        return { self.status = DrawerViewStatus.Middle }
    }
    private func goBottom() -> (() -> Void)? {
        botConstraints?.activate()
        yPosition = self.parentVC.view.frame.height - 100
        return { self.status = DrawerViewStatus.Bottom }
    }
    
    private func toggleDrag(to: Bool) {
        to ? slideView.addGestureRecognizer(panRecognizer!):slideView.removeGestureRecognizer(panRecognizer!)
    }
    
    // MARK: Pan gesture
    @objc func panPerforming(recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: recognizer.view)
        // When the user is still dragging or start dragging the if statement here will be fall through
        if recognizer.state == .began || recognizer.state == .changed {
            // Add the translation in y to slideView when slideView's minY is larger than 0
            if slideView.frame.minY >= 0 {
                slideView.frame.origin.y += translation.y
            }
            // Prevent drawer view in top position can still scroll top
            if status == .Top && translation.y < 0 && slideView.frame.minY <= 0 {
                slideView.frame.origin.y = 0
            }
            recognizer.setTranslation(.zero, in: recognizer.view)
        }
        else{
            
            var completeionFunc: (() -> Void)?
            // Check the velocity of gesture to determine if it's a swipe or a drag
            if abs(recognizer.velocity(in: recognizer.view).y) > 1000 {
                // This is a swipe
                // Swipe up velocity is smaller than 0
                // Determine whether the detentsPointer shuld move forward or back according to the swipe direction
                recognizer.velocity(in: recognizer.view).y <= 0 ? (detentsPointer += 1) : (detentsPointer -= 1)
                // Switch available detents set in initial and set animation duration, yPosition and status
                switch detents[detentsPointer] {
                case .Bottom:
                    completeionFunc = goBottom()
                case .Middle:
                    completeionFunc = goMid()
                case .Top:
                    completeionFunc = goTop()
                }
            } else {
                // This is a drag
                // Determine what area the drawer view is in and set animation duration, yPosition, status and detentsPointer to the nearest position
                if self.slideView.frame.minY > self.parentVC.view.frame.height * 0.6 && detents.contains(.Bottom) {
                    completeionFunc = goBottom()
                    detentsPointer = detents.firstIndex(of: .Bottom)!
                } else if self.slideView.frame.minY < self.parentVC.view.frame.height * 0.28 && detents.contains(.Top) {
                    completeionFunc = goTop()
                    detentsPointer = detents.firstIndex(of: .Top)!
                } else if detents.contains(.Middle) {
                    completeionFunc = goMid()
                    detentsPointer = detents.firstIndex(of: .Middle)!
                }
            }
            
            // If swipeDownToDismiss is true check the slideView ending position to determine if need to pop view controller
            if self.slideView.frame.minY > (detents.contains(.Bottom) ? (self.parentVC.view.frame.height - 100) : (self.parentVC.view.frame.height * 0.6)) && swipeDownToDismiss {
                myNav.popViewController(animated: true)
            }
            
            // Animate the drawer view to the set position
            UIView.animate(withDuration: abs(yPosition - self.slideView.frame.origin.y) / (0.35 * self.parentVC.view.frame.height / 0.35)) {
                self.slideView.frame.origin.y = self.yPosition
                self.parentVC.view.layoutIfNeeded()
            } completion: { success in
                completeionFunc!()
            }
        }
    }
    
    @objc func closeAction() {
        UIView.animate(withDuration: 0.35, animations: {
            self.slideView.frame.origin.y = self.parentVC.view.frame.height
            self.parentVC.view.layoutIfNeeded()
        }) { (success) in
            self.status = DrawerViewStatus.Close
            self.slideView.removeFromSuperview()
            self.myNav.removeFromParent()            
            if self.closeDo != nil {
                self.closeDo!()
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DrawerView: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        transitionAnimation.transitionMode = operation == .push ? .present : .pop
        return transitionAnimation
    }
}

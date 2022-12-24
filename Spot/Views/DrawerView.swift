//
//  DrawerView.swift
//  Spot
//
//  Created by Arnold on 6/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import SnapKit
import UIKit

enum DrawerViewStatus: Int {
    case bottom = 0
    case middle = 1
    case top = 2
    case close = 3
}
enum DrawerViewDetent: Int {
    case bottom = 0
    case middle = 1
    case top = 2
}

class DrawerView: NSObject {

    // MARK: Public variable
    public lazy var slideView = UIView {
        $0.backgroundColor = .white
        $0.layer.cornerRadius = UserDataModel.shared.screenSize == 0 ? 0 : 20
        $0.layer.shadowColor = UIColor.black.cgColor
        $0.layer.shadowOffset = CGSize(width: 2, height: 2)
        $0.layer.shadowOpacity = 0.8
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    public var status: DrawerViewStatus = .close

    // If false remove pangesture
    public var canInteract: Bool = true {
        didSet {
            toggleDrag(canInteract: canInteract)
        }
    }
    // If false don't update the slideview frame
    public var canDrag: Bool = true
    public var showCloseButton: Bool = false {
        didSet {
            closeButton.isHidden = !showCloseButton
        }
    }
    public var swipeDownToDismiss: Bool = false
    public var swipingDownToDismiss: Bool = false
    public var swipeToNextState: Bool = true

    // MARK: Private variable
    private lazy var myNav = UINavigationController()
    private lazy var closeButton = UIButton {
        $0.backgroundColor = .clear
        $0.setImage(UIImage(named: "X"), for: .normal)
        $0.setTitle("", for: .normal)
    }
    private lazy var grabberView = UIView {
        $0.backgroundColor = .tertiarySystemFill
        $0.layer.cornerRadius = 2
    }
    private lazy var panRecognizer = UIPanGestureRecognizer()

    private let transitionAnimation = BottomToTopTransition()
    private var drawerCornerRadius: CGFloat = 0.0

    private var rootVC = UIViewController()
    private unowned var parentVC: UIViewController?

    private var yPosition: CGFloat = 0
    private var topConstraints: Constraint?
    private var midConstraints: Constraint?
    private var botConstraints: Constraint?
    private var detents: [DrawerViewDetent] = [.bottom, .middle, .top]
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
    private var animationCompleteNotificationName = "DrawerViewToTopComplete"
    private var closeDo: (() -> Void)?

    override init() {
        super.init()
    }
    
    public init(present: UIViewController = UIViewController(), detentsInAscending: [DrawerViewDetent] = [.bottom, .middle, .top], closeAction: (() -> Void)? = nil) {
        super.init()
        if let parent = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController as? UINavigationController {
            if parent.visibleViewController != nil {
                parentVC = parent.visibleViewController ?? UIViewController()
            }
        }
        rootVC = present
        drawerCornerRadius = UserDataModel.shared.screenSize == 0 ? 0 : 20
        slideView.layer.cornerRadius = drawerCornerRadius
        detents = detentsInAscending
        viewSetup(cornerRadius: drawerCornerRadius)
        closeDo = closeAction
    }

    // MARK: View setup
    private func viewSetup(cornerRadius: CGFloat) {
        parentVC?.view.addSubview(slideView)
        guard let parent = parentVC else { return }
        slideView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            topConstraints = $0.top.greaterThanOrEqualTo(parent.view.snp.top).constraint
            midConstraints = $0.top.greaterThanOrEqualTo(parent.view.snp.top).offset(0.45 * parent.view.frame.height).constraint
            botConstraints = $0.top.greaterThanOrEqualTo(parent.view.snp.bottom).inset(200).constraint
            $0.height.equalTo(parent.view.snp.height)
        }
        topConstraints?.deactivate()
        midConstraints?.deactivate()
        botConstraints?.deactivate()
        slideView.frame = CGRect(x: 0, y: parent.view.frame.height, width: parent.view.frame.width, height: parent.view.frame.height)
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panPerforming(recognizer:)))
        panRecognizer.delegate = self
        slideView.addGestureRecognizer(panRecognizer)

        myNav = UINavigationController(rootViewController: rootVC)
        myNav.delegate = self
        parentVC?.addChild(myNav)
        slideView.addSubview(myNav.view)
        myNav.view.frame = CGRect(origin: .zero, size: slideView.frame.size)
        myNav.view.layer.cornerRadius = cornerRadius
        myNav.view.layer.masksToBounds = true
        myNav.didMove(toParent: parentVC)
        myNav.navigationBar.setBackgroundImage(UIImage(), for: .default)
        myNav.navigationBar.shadowImage = UIImage()
        myNav.navigationBar.isTranslucent = false

        slideView.addSubview(grabberView)
        grabberView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(10)
            $0.width.equalTo(40)
            $0.height.equalTo(4)
            $0.centerX.equalToSuperview()
        }

        slideView.addSubview(closeButton)
        closeButton.snp.makeConstraints {
            $0.trailing.equalToSuperview()
            $0.top.equalToSuperview().offset(30)
            $0.width.height.equalTo(70)
        }
        closeButton.addTarget(self, action: #selector(self.closeAction(_:)), for: .touchUpInside)
        closeButton.isHidden = !showCloseButton
    }

    // MARK: Present
    public func present(to: DrawerViewDetent = .middle) {
        self.topConstraints?.deactivate()
        self.midConstraints?.deactivate()
        self.botConstraints?.deactivate()
        switch to {
        case .top:
            goTop()
        case .middle:
            goMid()
        case .bottom:
            goBottom()
        }
        detentsPointer = detents.firstIndex(of: DrawerViewDetent(rawValue: to.rawValue) ?? .top) ?? 0

    //    DispatchQueue.main.async {
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
                self.slideView.frame.origin.y = self.yPosition
                self.myNav.view.layer.cornerRadius = self.drawerCornerRadius
                self.parentVC?.view.layoutIfNeeded()
            } completion: { _ in
                NotificationCenter.default.post(name: NSNotification.Name("\(self.animationCompleteNotificationName)"), object: nil)
            }
      //  }
    }

    // MARK: Set position functions
    private func goTop() {
        topConstraints?.activate()
        yPosition = 0
        status = .top
        drawerCornerRadius = 0
        animationCompleteNotificationName = "DrawerViewToTopComplete"
    }
    private func goMid() {
        midConstraints?.activate()
        yPosition = (0.45 * (parentVC?.view.frame.height ?? 0))
        status = .middle
        drawerCornerRadius = 20
        animationCompleteNotificationName = "DrawerViewToMiddleComplete"
    }
    private func goBottom() {
        botConstraints?.activate()
        yPosition = (parentVC?.view.frame.height ?? 0) - 200
        status = .bottom
        drawerCornerRadius = 20
        animationCompleteNotificationName = "DrawerViewToBottomComplete"
    }

    private func toggleDrag(canInteract: Bool) {
        if canInteract {
            slideView.addGestureRecognizer(panRecognizer)
        } else {
            slideView.removeGestureRecognizer(panRecognizer)
        }
    }

    // MARK: Pan gesture
    @objc func panPerforming(recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: recognizer.view)
        let velocity = recognizer.velocity(in: recognizer.view)
        // When the user is still dragging or start dragging the if statement here will be fall through
        guard canDrag else { return }
        if recognizer.state == .began || recognizer.state == .changed {
            // Add the translation in y to slideView when slideView's minY is larger than 0
            if slideView.frame.minY >= 0 {
                slideView.frame.origin.y += translation.y
            }

            // Change status according to the position when dragging
            if slideView.frame.minY == 0 {
                status = .top
            } else if slideView.frame.minY == (0.45 * (parentVC?.view.frame.height ?? 0)) {
                status = .middle
            } else if slideView.frame.minY == ((parentVC?.view.frame.height ?? 0) - 100) {
                status = .bottom
            }

            if slideView.frame.minY <= 0.45 * slideView.frame.height {
                let portion = (UserDataModel.shared.screenSize == 0 ? 0 : 20) / (0.45 * slideView.frame.height)
                myNav.view.layer.cornerRadius = slideView.frame.minY * portion
            }

            // Prevent drawer view in top position can still scroll top
            if status == .top && translation.y < 0 && slideView.frame.minY <= 0 {
                slideView.frame.origin.y = 0
            }
            recognizer.setTranslation(.zero, in: recognizer.view)
        } else {
            /// swipe to dismiss from full-screen-only view
            let topOffset = slideView.frame.origin.y
            if self.swipeDownToDismiss && (topOffset * 5 + velocity.y) > 1_000 {
                self.swipingDownToDismiss = true
                closeAction()
                return
            }

            self.topConstraints?.deactivate()
            self.midConstraints?.deactivate()
            self.botConstraints?.deactivate()
            // Check the velocity of gesture to determine if it's a swipe or a drag
            if swipeToNextState && abs(velocity.y) > 1_000 {
                // This is a swipe
                // Swipe up velocity is smaller than 0
                // Determine whether the detentsPointer shuld move forward or back according to the swipe direction
                recognizer.velocity(in: recognizer.view).y <= 0 ? (detentsPointer += 1) : (detentsPointer -= 1)
                // Switch available detents set in initial and set animation duration, yPosition and status
                switch detents[detentsPointer] {
                case .bottom:
                    goBottom()
                case .middle:
                    goMid()
                case .top:
                    goTop()
                }
            } else {
                // This is a drag
                // Determine what area the drawer view is in and set animation duration, yPosition, status and detentsPointer to the nearest position
                if self.slideView.frame.minY > (self.parentVC?.view.frame.height ?? 0) * 0.6 && detents.contains(.bottom) {
                    goBottom()
                    detentsPointer = detents.firstIndex(of: .bottom) ?? 0
                } else if self.slideView.frame.minY < (self.parentVC?.view.frame.height ?? 0) * 0.28 && detents.contains(.top) {
                    goTop()
                    detentsPointer = detents.firstIndex(of: .top) ?? 2
                } else if detents.contains(.middle) {
                    goMid()
                    detentsPointer = detents.firstIndex(of: .middle) ?? 1
                }
            }
            /* If swipeDownToDismiss is true check the slideView ending position to determine if need to pop view controller
            if self.slideView.frame.minY > (detents.contains(.bottom) ? (self.parentVC.view.frame.height - 100) : (self.parentVC.view.frame.height * 0.6)) && swipeDownToDismiss {
                myNav.popViewController(animated: true)
            } */

            // Animate the drawer view to the set position
            UIView.animate(withDuration: abs(yPosition - self.slideView.frame.origin.y) / (0.25 * (self.parentVC?.view.frame.height ?? 0) / 0.25)) {
                self.slideView.frame.origin.y = self.yPosition
                self.myNav.view.layer.cornerRadius = self.drawerCornerRadius
                self.parentVC?.view.layoutIfNeeded()
            } completion: { _ in
                NotificationCenter.default.post(name: NSNotification.Name("\(self.animationCompleteNotificationName)"), object: nil)
            }
        }
    }

    // MARK: Close
    @objc func closeAction(_ sender: UIButton) {
        closeAction()
    }

    func closeAction() {
        /// animation duration as a proportion of drawer's current position (0.3 is default duration)
        let animationDuration = ((slideView.frame.height - slideView.frame.origin.y) * 0.25) / (parentVC?.view.bounds.height ?? 0)
        if myNav.viewControllers.count == 1 {

            UIView.animate(withDuration: animationDuration, animations: {
                self.slideView.frame.origin.y = self.parentVC?.view.frame.height ?? 0
                self.parentVC?.view.layoutIfNeeded()
            }, completion: { [weak self] Bool in
                guard let self = self else { return }
                if let closeDo = self.closeDo { closeDo() }
                self.status = DrawerViewStatus.close
                self.slideView.removeFromSuperview()
                self.myNav.removeFromParent()
                self.swipingDownToDismiss = false
            })
        } else {
            myNav.popViewController(animated: true)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DrawerView: UINavigationControllerDelegate {
    func navigationController
    (_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController)
    -> UIViewControllerAnimatedTransitioning? {
        transitionAnimation.startingOffset = slideView.frame.origin.y
        transitionAnimation.transitionMode = operation == .push ? .present : .pop
        return transitionAnimation
    }
}

extension DrawerView: UIGestureRecognizerDelegate {
    // This will let gesture recognizer to be recognized even in the back of view hierarchy
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

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
enum PresentationDirection: Int {
    case rightToLeft = 0
    case bottomToTop = 1
}

class DrawerView: NSObject {
    public lazy var slideView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = UserDataModel.shared.screenSize == 0 ? 0 : 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 2, height: 2)
        view.layer.shadowOpacity = 0.8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    public var status: DrawerViewStatus = .top

    public var canDrag: Bool = true
    public var showCloseButton: Bool = false {
        didSet {
            closeButton.isHidden = !showCloseButton
        }
    }
    public var isDraggingVertical: Bool = false
    public var isDraggingHorizontal: Bool = false
    public var swipeDownToDismiss: Bool = false
    public var swipingToDismiss: Bool = false
    public var swipeToNextState: Bool = false

    // MARK: Private variable
    private lazy var myNav = UINavigationController()
    private lazy var closeButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .clear
        button.setImage(UIImage(named: "X"), for: .normal)
        button.setTitle("", for: .normal)
        return button
    }()
    private lazy var grabberView: UIView = {
        let view = UIView()
        view.backgroundColor = .tertiarySystemFill
        view.layer.cornerRadius = 2
        return view
    }()
    private lazy var panRecognizer = UIPanGestureRecognizer()

    private let transitionAnimation = BottomToTopTransition()
    private var drawerCornerRadius: CGFloat = 0.0

    public var rootVC = UIViewController()
    private unowned var parentVC: UIViewController?

    private var yPosition: CGFloat = 0
    private var presentationDirection: PresentationDirection = .rightToLeft

    let midConstraintOffset: CGFloat = UIScreen.main.bounds.height * 0.45
    let botConstraintOffset: CGFloat = -150

    private var animationConstraints: Constraint?
    private var boundingConstraint: Constraint?

    private var topConstraints: Constraint?
    private var midConstraints: Constraint?
    private var botConstraints: Constraint?
    private var bottomEdgeConstraint: Constraint?
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
    
    public init(present: UIViewController = UIViewController(), presentationDirection: PresentationDirection, closeAction: (() -> Void)? = nil) {
        super.init()
        // cant get parent from this -> rework
        if let parent = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController as? HomeScreenContainerController {
            parentVC = parent
        }
        rootVC = present
        drawerCornerRadius = UserDataModel.shared.screenSize == 0 ? 0 : 20
        slideView.layer.cornerRadius = drawerCornerRadius
        self.presentationDirection = presentationDirection
        viewSetup(cornerRadius: drawerCornerRadius)
        closeDo = closeAction
    }

    // MARK: View setup
    private func viewSetup(cornerRadius: CGFloat) {
        parentVC?.view.addSubview(slideView)
        guard let parent = parentVC else { return }
        slideView.snp.makeConstraints {
            // make constraints for initial animation
            if presentationDirection == .bottomToTop {
                $0.leading.trailing.height.equalToSuperview()
                animationConstraints = $0.top.equalTo(parent.view.snp.bottom).constraint

            } else {
                $0.bottom.top.width.equalToSuperview()
                animationConstraints = $0.leading.equalTo(parent.view.snp.trailing).constraint
            }
        }
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panPerforming(recognizer:)))
        panRecognizer.delegate = self
        slideView.addGestureRecognizer(panRecognizer)

        myNav = UINavigationController(rootViewController: rootVC)
        myNav.delegate = self
        parentVC?.addChild(myNav)
        slideView.addSubview(myNav.view)
        myNav.view.layer.cornerRadius = cornerRadius
        myNav.view.layer.masksToBounds = true
        myNav.didMove(toParent: parentVC)
        myNav.navigationBar.setBackgroundImage(UIImage(), for: .default)
        myNav.navigationBar.shadowImage = UIImage()
        myNav.navigationBar.isTranslucent = false
        myNav.view.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

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

        status = .close
    }

    public func configure(canDrag: Bool, swipeDownToDismiss: Bool, startingPosition: DrawerViewDetent) {
        self.canDrag = canDrag
        self.swipeDownToDismiss = swipeDownToDismiss
        if status.rawValue != startingPosition.rawValue { present(to: startingPosition) }
    }

    // MARK: Present
    public func present(to: DrawerViewDetent? = .top) {
        DispatchQueue.main.async {
            if self.animationConstraints != nil {
                // handle constraints for initial animation (right-to-left only)
                self.removeAnimationConstraints()
            } else {
                self.topConstraints?.deactivate()
                self.midConstraints?.deactivate()
                self.botConstraints?.deactivate()
                switch to {
                case .top:
                    self.goTop()
                case .middle:
                    self.goMid()
                case .bottom:
                    self.goBottom()
                default: return
                }
            }
            self.detentsPointer = self.detents.firstIndex(of: DrawerViewDetent(rawValue: to?.rawValue ?? 2) ?? .top) ?? 0
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
                self.myNav.view.layer.cornerRadius = self.drawerCornerRadius
               //  self.myNav.view.layoutIfNeeded()
               //  self.parentVC?.view.layoutIfNeeded()
                self.parentVC?.view.layoutSubviews()

            } completion: { _ in
                NotificationCenter.default.post(name: NSNotification.Name("\(self.animationCompleteNotificationName)"), object: nil)
            }
        }
    }

    private func removeAnimationConstraints() {
        guard let parent = parentVC else { return }
        status = .top
        animationConstraints?.deactivate()
        slideView.snp.removeConstraints()
        slideView.snp.makeConstraints {
            $0.width.equalToSuperview()
            // name new constraint to be deactivated on remove animation
            boundingConstraint = $0.leading.equalToSuperview().constraint
            bottomEdgeConstraint = $0.bottom.equalToSuperview().constraint

            midConstraints = $0.top.equalToSuperview().offset(self.midConstraintOffset).constraint
        }
        midConstraints?.deactivate()

        slideView.snp.makeConstraints {
            botConstraints = $0.top.equalTo(parent.view.snp.bottom).offset(self.botConstraintOffset).constraint
        }
        botConstraints?.deactivate()

        slideView.snp.makeConstraints {
            topConstraints = $0.top.equalToSuperview().constraint
        }

        // send drawer view to top notification for remove animation
    }

    // MARK: Set position functions
    private func goTop() {
        // used to set collection view content offset on CustomMapController
        NotificationCenter.default.post(name: NSNotification.Name("DrawerViewToTopBegan"), object: nil)

        // update in case swipe to dismiss was activated
        yPosition = 0
        topConstraints?.update(offset: 0)
        topConstraints?.activate()
        bottomEdgeConstraint?.update(offset: yPosition)

        status = .top
        drawerCornerRadius = 0
        animationCompleteNotificationName = "DrawerViewToTopComplete"
    }
    private func goMid() {
        yPosition = midConstraintOffset
        midConstraints?.update(offset: midConstraintOffset)
        midConstraints?.activate()
        bottomEdgeConstraint?.update(offset: yPosition)

        status = .middle
        drawerCornerRadius = 20
        animationCompleteNotificationName = "DrawerViewToMiddleComplete"
    }
    private func goBottom() {
        yPosition = UIScreen.main.bounds.height - 200
        botConstraints?.update(offset: botConstraintOffset)
        botConstraints?.activate()
        bottomEdgeConstraint?.update(offset: yPosition)

        status = .bottom
        drawerCornerRadius = 20
        animationCompleteNotificationName = "DrawerViewToBottomComplete"
    }

    private func offsetVerticalSlideViewConstraint(offset: CGFloat) {
        if offset > 0 { NotificationCenter.default.post(name: NSNotification.Name("DrawerViewOffset"), object: nil) }
        bottomEdgeConstraint?.update(offset: max(0, yPosition + offset))
        switch status {
        case .top:
            topConstraints?.update(offset: max(0, offset))
        case .middle:
            midConstraints?.update(offset: midConstraintOffset + offset)
        case .bottom:
            // measuring from bottom of parent so offset is a negative value
            botConstraints?.update(offset: botConstraintOffset + offset)
        default: return
        }
    }

    private func offsetHorizontalSlideViewConstraint(offset: CGFloat) {
        if offset > 0 { NotificationCenter.default.post(name: NSNotification.Name("DrawerViewOffset"), object: nil) }
        boundingConstraint?.update(offset: offset)
    }

    private func resetHorizontalSlideViewConstraint() {
        guard let parent = parentVC else { return }
        boundingConstraint?.update(offset: 0)
        UIView.animate(withDuration: 0.2, animations: {
            parent.view.layoutIfNeeded()
        }) { _ in
            NotificationCenter.default.post(name: NSNotification.Name("DrawerViewReset"), object: nil)
        }
    }

    // MARK: Pan gesture
    @objc func panPerforming(recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: recognizer.view)
        let velocity = recognizer.velocity(in: recognizer.view)
        // When the user is still dragging or start dragging the if statement here will be fall through
        guard canDrag else {
            if presentationDirection == .rightToLeft { swipeRightToDismiss(gesture: recognizer) }
            return
        }
        switch recognizer.state {
        case .began, .changed:
            if swipeToNextState || swipeDownToDismiss {
                isDraggingVertical = true
                offsetVerticalSlideViewConstraint(offset: translation.y)
            }

        case .ended, .cancelled:
            if swipeDownToDismiss {
                // if swipe to dismiss, calculate if the swipe was hard enough

                if translation.y * 5 + velocity.y > 1_000 {
                    self.swipingToDismiss = true
                    closeAction()
                    return
                } else {
                    goTop()
                }
            } else if swipeToNextState {
                // if dragging, calculate final position

                // already advanced past mid state
                var yAdjustment: CGFloat = 0
                if status.rawValue == 0 && translation.y < -midConstraintOffset {
                    detentsPointer += 1
                    yAdjustment = midConstraintOffset
                }
                if status.rawValue == 2 && translation.y > midConstraintOffset {
                    detentsPointer -= 1
                    yAdjustment = midConstraintOffset
                }

                // determine if swipe to next state
                let compositeValue = translation.y + velocity.y / 3 - yAdjustment
                if compositeValue > 100 {
                    detentsPointer = max(detentsPointer - 1, 0)
                } else if compositeValue < -100 {
                    detentsPointer = min(detentsPointer + 1, 2)
                }

                topConstraints?.deactivate()
                midConstraints?.deactivate()
                botConstraints?.deactivate()

                switch detents[detentsPointer] {
                case .bottom:
                    goBottom()
                case .middle:
                    goMid()
                case .top:
                    goTop()
                }
            }

            UIView.animate(withDuration: min(abs(yPosition - self.slideView.frame.origin.y) / (0.25 * (self.parentVC?.view.frame.height ?? 0) / 0.25), 0.3)) {
                self.myNav.view.layer.cornerRadius = self.drawerCornerRadius
                self.parentVC?.view.layoutSubviews()
            } completion: { _ in
                self.isDraggingVertical = false
                NotificationCenter.default.post(name: NSNotification.Name("\(self.animationCompleteNotificationName)"), object: nil)
            }

        default:
            return
        }
    }

    private func swipeRightToDismiss(gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        let location = gesture.location(in: gesture.view)
        let velocity = gesture.velocity(in: gesture.view)
        switch gesture.state {
        case .began:
            if velocity.x > 0 &&
                velocity.x > velocity.y &&
                location.x < 100 {
                isDraggingHorizontal = true
            }
        case .changed:
            if isDraggingHorizontal { offsetHorizontalSlideViewConstraint(offset: translation.x) }

        case .cancelled, .ended:
            if !isDraggingHorizontal { return }
            isDraggingHorizontal = false

            let compositeValue = translation.x + velocity.x / 3
            if compositeValue > 200 {
                closeAction()
            } else {
                resetHorizontalSlideViewConstraint()
            }

        default:
            return

        }
    }

    // MARK: Close
    @objc func closeAction(_ sender: UIButton) {
        closeAction()
    }

    func closeAction() {
        guard let parent = parentVC else { return }
        // animation duration as a proportion of drawer's current position (0.3 is default duration)
        let animationDuration = ((slideView.frame.height - slideView.frame.origin.y) * 0.25) / (parent.view.bounds.height)

        if myNav.viewControllers.count == 1 {
            if presentationDirection == .bottomToTop {
                self.topConstraints?.deactivate()
                self.bottomEdgeConstraint?.update(offset: UIScreen.main.bounds.height)
            } else {
                self.boundingConstraint?.deactivate()
            }
            self.animationConstraints?.activate()
            NotificationCenter.default.post(name: NSNotification.Name("DrawerViewCloseBegan"), object: nil)


            UIView.animate(withDuration: animationDuration, animations: {
                self.parentVC?.view.layoutIfNeeded()

            }, completion: { [weak self] _ in
                guard let self = self else { return }
                self.status = DrawerViewStatus.close
                self.slideView.removeFromSuperview()
                self.myNav.removeFromParent()
                self.swipingToDismiss = false
                if let closeDo = self.closeDo { closeDo() }
            })
        } else {
            status = .close
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
        if (toVC is PostController || fromVC is PostController) ||
            (toVC is CustomMapController || fromVC is CustomMapController) {
            transitionAnimation.startingOffset = slideView.frame.origin.y
            transitionAnimation.transitionMode = operation == .push ? .present : .pop
            return transitionAnimation

        } else {
            return nil
        }
    }
}

extension DrawerView: UIGestureRecognizerDelegate {
    // This will let gesture recognizer to be recognized even in the back of view hierarchy
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
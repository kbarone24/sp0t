//
//  BottomToTopTransition.swift
//  Spot
//
//  Created by Arnold on 6/16/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation

class BottomToTopTransition: NSObject {
    enum DismissalDirection {
        case up
        case down
    }

    enum BottomToTopTransitionMode {
        case present
        case dismiss
        case pop
    }
    var transitionMode: BottomToTopTransitionMode = .present
    var dismissalDirection: DismissalDirection = .down
    var minY: CGFloat = 0
    var maxY: CGFloat = UIScreen.main.bounds.height
}

extension BottomToTopTransition: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.25
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if transitionMode == .present {
            if let presentedView = transitionContext.view(forKey: UITransitionContextViewKey.to) {
                presentedView.frame.origin = CGPoint(x: 0, y: transitionContext.containerView.frame.height)
                transitionContext.containerView.addSubview(presentedView)
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                    presentedView.frame.origin = .zero
                    transitionContext.completeTransition(true)
                }
            }
        } else {
            let transitionModeKey = (transitionMode == .pop) ? UITransitionContextViewKey.to : UITransitionContextViewKey.from
            let finalViewModeKey = (transitionMode == .pop) ? UITransitionContextViewControllerKey.from : UITransitionContextViewControllerKey.to
            if let previousView = transitionContext.view(forKey: transitionModeKey) {
                guard let nowView = transitionContext.viewController(forKey: finalViewModeKey)?.view else { return }
                nowView.frame = CGRect(x: nowView.frame.minX, y: minY, width: nowView.frame.width, height: maxY)
                transitionContext.containerView.insertSubview(previousView, belowSubview: nowView)
                let yValue: CGFloat = dismissalDirection == .down ? transitionContext.containerView.frame.height : -transitionContext.containerView.frame.height
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
                    nowView.frame.origin = CGPoint(x: 0, y: yValue)
                } completion: { success in
                    self.minY = 0
                    self.maxY = UIScreen.main.bounds.height
                    nowView.removeFromSuperview()
                    transitionContext.completeTransition(success)
                }
            }
        }
    }
}

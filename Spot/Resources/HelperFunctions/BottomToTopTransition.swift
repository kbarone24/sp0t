//
//  BottomToTopTransition.swift
//  Spot
//
//  Created by Arnold on 6/16/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation

class BottomToTopTransition: NSObject {
    
    enum BottomToTopTransitionMode {
        case present
        case dismiss
        case pop
    }
    var transitionMode: BottomToTopTransitionMode = .present
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
                } completion: { success in
                    transitionContext.completeTransition(success)
                }
            }
        } else {
            let transitionModeKey = (transitionMode == .pop) ? UITransitionContextViewKey.to:UITransitionContextViewKey.from
            let finalViewModeKey = (transitionMode == .pop) ? UITransitionContextViewControllerKey.from:UITransitionContextViewControllerKey.to
            if let previousView = transitionContext.view(forKey: transitionModeKey) {
                let nowView = transitionContext.viewController(forKey: finalViewModeKey)?.view
                transitionContext.containerView.insertSubview(previousView, belowSubview: nowView ?? UIView())
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
                    nowView?.frame.origin = CGPoint(x: 0, y: transitionContext.containerView.frame.height)
                } completion: { success in
                    nowView?.removeFromSuperview()
                    transitionContext.completeTransition(success)
                }
            }
        }
    }
}

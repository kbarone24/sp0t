//
//  LocationScrollView.swift
//  Spot
//
//  Created by Kenny Barone on 1/27/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class LocationScrollView: UIScrollView {
    private var animating = false
    private var animator: UIViewPropertyAnimator?
    private var cancelOnDismiss = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        showsHorizontalScrollIndicator = false
        contentInset = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)
        isScrollEnabled = true
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startAnimating() {
        if !animating {
            animating = true
            animateScrollView()
        }
    }

    func stopAnimating() {
        if animating {
            stopAllAnimations()
        }
    }

    private func animateScrollView() {
        if animator != nil { return }
        let minOffset = -contentInset.left
        let maxOffset = contentSize.width + contentInset.left + contentInset.right - bounds.width
        var setOffset: CGFloat = 0

        if contentOffset.x != minOffset {
            setOffset = minOffset
        } else {
            setOffset = maxOffset
        }

        let animationDuration: TimeInterval = max(2.5, min(5.0, TimeInterval(maxOffset / 100)))
        animator = UIViewPropertyAnimator(duration: animationDuration, curve: .easeInOut, animations: {
            self.setContentOffset(CGPoint(x: setOffset, y: 0), animated: false)
        })
        animator?.startAnimation(afterDelay: 1.0)
        animator?.addCompletion { position in
            if position == .end {
                self.animator?.stopAnimation(true)
                self.animator = nil
                self.animateScrollView()
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("touches began")
        stopAllAnimations()
    }

    func stopAllAnimations() {
        animator?.stopAnimation(true)
        animator?.finishAnimation(at: .current)
        animator = nil
        animating = false
        layer.removeAllAnimations()
    }
}

//
//  FocusIndicatorView.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 1/9/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit

final class FocusIndicatorView: UIView {

    // MARK: - ivars
    private lazy var _focusRingView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "TapFocusIndicator")
        imageView.alpha = 0.0
        return imageView
    }()

    // MARK: - object lifecycle
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.contentMode = .scaleToFill

        _focusRingView.alpha = 0
        self.addSubview(_focusRingView)

        self.frame = self._focusRingView.frame

        self.prepareAnimation()
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self._focusRingView.layer.removeAllAnimations()
    }
}

// MARK: - animation
extension FocusIndicatorView {

    private func prepareAnimation() {
        // prepare animation
        self._focusRingView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        self._focusRingView.alpha = 0
    }

    public func startAnimation() {
        self._focusRingView.layer.removeAllAnimations()

        // animate
        UIView.animate(withDuration: 0.2) {
            self._focusRingView.alpha = 1
        }
        UIView.animate(withDuration: 0.5) {
            self._focusRingView.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        }
    }

    public func stopAnimation() {
        self._focusRingView.layer.removeAllAnimations()

        UIView.animate(withDuration: 0.2) {
            self._focusRingView.alpha = 0
        }
        UIView.animate(withDuration: 0.2) {
            self._focusRingView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        } completion: { (completed) in
            if completed {
                self.removeFromSuperview()
            }
        }
    }

}

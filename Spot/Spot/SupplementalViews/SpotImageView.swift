//
//  SpotImageView.swift
//  Spot
//
//  Created by Kenny Barone on 7/18/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

class SpotImageView: UIImageView {
    private lazy var originalCenter: CGPoint = .zero
    private(set) lazy var zooming = false
    lazy var swipingToExit = false

    func enableZoom() {
        isUserInteractionEnabled = true

        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(zoom(_:)))
        pinchGesture.delegate = self
        addGestureRecognizer(pinchGesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
    }

    @objc func zoom(_ sender: UIPinchGestureRecognizer) {
        Mixpanel.mainInstance().track(event: "SpotPageZoo", properties: nil)

        switch sender.state {

        case .began:
            zooming = true
            originalCenter = center

        case .changed:
            let pinchCenter = CGPoint(x: sender.location(in: self).x - self.bounds.midX,
                                      y: sender.location(in: self).y - self.bounds.midY)

            let transform = self.transform.translatedBy(x: pinchCenter.x, y: pinchCenter.y)
                .scaledBy(x: sender.scale, y: sender.scale)
                .translatedBy(x: -pinchCenter.x, y: -pinchCenter.y)

            let currentScale = self.frame.size.width / self.bounds.size.width
            var newScale = currentScale * sender.scale
            if newScale < 1 {
                newScale = 1
                let transform = CGAffineTransform(scaleX: newScale, y: newScale)
                self.transform = transform

            } else {
                self.transform = transform
                sender.scale = 1
            }

        case .ended, .cancelled, .failed:
            UIView.animate(withDuration: 0.3, animations: { [weak self] in

                guard let self = self else { return }
                self.center = self.originalCenter
                self.transform = CGAffineTransform.identity
            })

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [ weak self] in
                guard let self = self else { return }
                self.zooming = false
            }

        default: return
        }
    }

    @objc func pan(_ sender: UIPanGestureRecognizer) {

        if zooming && sender.state == .changed {
            let translation = sender.translation(in: self)
            let currentScale = self.frame.size.width / self.bounds.size.width
            self.center = CGPoint(x: self.center.x + (translation.x * currentScale), y: self.center.y + (translation.y * currentScale))
            sender.setTranslation(CGPoint.zero, in: superview)
        }
    }
}

extension SpotImageView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if swipingToExit {
            return false
        }
        if zooming {
            return gestureRecognizer.view?.isKind(of: SpotImageView.self) ?? false && otherGestureRecognizer.view?.isKind(of: SpotImageView.self) ?? false
        }
        return true
    }
}

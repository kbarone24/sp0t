//
//  PostImageView.swift
//  Spot
//
//  Created by Kenny Barone on 4/11/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class PostImageView: UIImageView, UIGestureRecognizerDelegate {
    var stillImage: UIImage
    var animationIndex: Int
    var originalCenter: CGPoint
    var activeAnimation = false
    var currentAspect: CGFloat
    lazy var imageMask = UIImageView()

    override init(frame: CGRect) {
        stillImage = UIImage()
        animationIndex = 0
        originalCenter = .zero
        currentAspect = 0
        super.init(frame: frame)

        tag = 16
        clipsToBounds = true
        isUserInteractionEnabled = true
        contentMode = .scaleAspectFill

        //TODO: enable zoom on images
       // enableZoom()
    }

    override func layoutSubviews() {
       // if currentAspect > 1.45 { addBottomMask() }
        // bottom mask added by PostImagePreview superclass now
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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
        guard let scrollView = superview as? ImageScrollView else { return }
        /// only zoom if not already swiping between images
        if scrollView.contentOffset.x.truncatingRemainder(dividingBy: UIScreen.main.bounds.width) != 0 { return }

        switch sender.state {

        case .began:
            scrollView.imageZoom = true
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

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                scrollView.imageZoom = false
            }

        default: return
        }
    }

    @objc func pan(_ sender: UIPanGestureRecognizer) {

        guard let scrollView = superview as? ImageScrollView else { return }

        if scrollView.imageZoom && sender.state == .changed {
            let translation = sender.translation(in: self)
            let currentScale = frame.size.width / bounds.size.width
            center = CGPoint(x: center.x + (translation.x * currentScale), y: center.y + (translation.y * currentScale))
            sender.setTranslation(CGPoint.zero, in: superview)
        }
    }

    /// source: https://medium.com/@jeremysh/instagram-pinch-to-zoom-pan-gesture-tutorial-772681660dfe

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func addBottomMask() {
        if imageMask.superview != nil { return }
        addSubview(imageMask)
        imageMask.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        let layer = CAGradientLayer()
        layer.frame = self.bounds
        layer.colors = [
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.0).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.0).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.6).cgColor
        ]
        layer.locations = [0, 0.48, 1]
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        imageMask.layer.addSublayer(layer)
    }
}

class ImageScrollView: UIScrollView {
    var imageZoom: Bool

    override init(frame: CGRect) {
        imageZoom = false
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

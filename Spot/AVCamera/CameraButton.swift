//
//  CameraButton.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class CameraButton: UIView {
    var enabled: Bool = false {
        didSet {
            alpha = enabled ? 1.0 : 0.5
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.white.withAlphaComponent(0.6)
        layer.cornerRadius = 92 / 2
        layer.borderColor = UIColor.white.cgColor
        layer.borderWidth = 4
    }
/*
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        super.hitTest(point, with: event)
        if !self.isEnabled { return nil }
        let newArea = CGRect(x: -10, y: -10, width: frame.width + 20, height: frame.height + 20)
        return newArea.contains(point) ? self : nil
    }
*/
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

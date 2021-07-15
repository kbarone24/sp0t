//
//  CircleProgress.swift
//  Spot
//
//  Created by kbarone on 4/30/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class CircleProgress: UIView {
    var bgPath = UIBezierPath()
    var shapeLayer = CAShapeLayer()
    var progressLayer = CAShapeLayer()
    var progress: Float = 0 {
        willSet(newValue)
        {
            UIView.animate(withDuration: 0.35, animations: {
                self.progressLayer.strokeEnd = CGFloat(newValue)
            })
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        simpleShape()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createCirclePath() {
        let x = self.frame.width/2
        let y = self.frame.height/2
        let center = CGPoint(x: x, y: y)
        bgPath.addArc(withCenter: center, radius: x/CGFloat(2), startAngle: CGFloat(0), endAngle: CGFloat(6.28), clockwise: true)
        bgPath.close()
    }
    
    func simpleShape() {
        createCirclePath()
        shapeLayer.path = bgPath.cgPath
        shapeLayer.lineWidth = 3
        shapeLayer.fillColor = nil
        shapeLayer.strokeColor = UIColor.lightGray.cgColor
        progressLayer.path = bgPath.cgPath
        progressLayer.lineWidth = 2
        progressLayer.lineCap = CAShapeLayerLineCap.round
        progressLayer.fillColor = nil
        progressLayer.strokeColor = UIColor.white.cgColor
        progressLayer.strokeEnd = 0.0
        self.layer.addSublayer(shapeLayer)
        self.layer.addSublayer(progressLayer)
    }
}

//
//  MapPrivacySlider.swift
//  Spot
//
//  Created by Kenny Barone on 10/3/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import SnapKit

protocol PrivacySliderDelegate: AnyObject {
    func finishPassing(rawPosition: Int)
}

class MapPrivacySlider: UIView {
    enum SliderPosition: Int {
        case left = 0
        case center = 1
        case right = 2
    }
    weak var delegate: PrivacySliderDelegate?
    private lazy var selectedSliderPositon: SliderPosition = .left

    private(set) lazy var baseline: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.283, green: 0.283, blue: 0.283, alpha: 1)
        return view
    }()
    private(set) lazy var tick0 = SliderTick()
    private(set) lazy var tick1 = SliderTick()
    private(set) lazy var tick2 = SliderTick()
    private(set) lazy var sliderBall: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        view.layer.cornerRadius = 14
        return view
    }()
    var sliderBallXConstraint: Constraint?
    let sideInset: CGFloat = 28

    override init(frame: CGRect) {
        super.init(frame: frame)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap(_:))))
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan(_:))))

        addSubview(baseline)
        baseline.snp.makeConstraints {
            $0.leading.trailing.centerY.equalToSuperview().inset(sideInset)
            $0.height.equalTo(2)
        }

        baseline.addSubview(tick0)
        tick0.snp.makeConstraints {
            $0.leading.centerY.equalToSuperview()
            $0.height.equalTo(16)
            $0.width.equalTo(2)
        }

        baseline.addSubview(tick1)
        tick1.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
            $0.height.equalTo(16)
            $0.width.equalTo(2)
        }

        baseline.addSubview(tick2)
        tick2.snp.makeConstraints {
            $0.trailing.centerY.equalToSuperview()
            $0.height.equalTo(16)
            $0.width.equalTo(2)
        }

        baseline.addSubview(sliderBall)
        sliderBall.snp.makeConstraints {
            sliderBallXConstraint = $0.centerX.equalTo(tick0).constraint
            $0.centerY.equalToSuperview()
            $0.height.width.equalTo(28)
        }
    }

    @objc private func tap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self).x
        if location > 0 && location < sideInset * 2 {
            setSelected(position: .left)
        } else if location > bounds.width / 2 - 25 && location < bounds.width / 2 + 25 {
            setSelected(position: .center)
        } else if location > bounds.width - sideInset * 2 && location < bounds.width {
            setSelected(position: .right)
        }
    }

    @objc private func pan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let velocity = gesture.velocity(in: self)

        switch gesture.state {
        case .began, .changed:
            sliderBallXConstraint?.update(offset: translation.x)
        case .ended, .cancelled, .failed:
            let offset: CGFloat = selectedSliderPositon == .left ? tick0.frame.midX : selectedSliderPositon == .center ? tick1.frame.midX : tick2.frame.midX
            let adjustedVelocity = min(80, velocity.x / 20)
            let composite = offset + translation.x + adjustedVelocity

            if composite < baseline.bounds.width / 4 {
                setSelected(position: .left)
            } else if composite >= baseline.bounds.width / 4 && composite <= baseline.bounds.width * 3 / 4 {
                setSelected(position: .center)
            } else {
                setSelected(position: .right)
            }
        default:
            return
        }
    }

    func setSelected(position: SliderPosition) {
        HapticGenerator.shared.play(.light)
        selectedSliderPositon = position
        sliderBall.snp.remakeConstraints {
            switch position {
            case .left:
                sliderBallXConstraint = $0.centerX.equalTo(tick0).constraint
            case .center:
                sliderBallXConstraint = $0.centerX.equalTo(tick1).constraint
            case .right:
                sliderBallXConstraint = $0.centerX.equalTo(tick2).constraint
            }
            $0.centerY.equalToSuperview()
            $0.height.width.equalTo(28)
        }
        delegate?.finishPassing(rawPosition: selectedSliderPositon.rawValue)
    }

    private func resetSelected() {
        sliderBallXConstraint?.update(offset: 0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SliderTick: UIView {
    override init(frame: CGRect) {
        super.init(frame: .zero)
        backgroundColor = UIColor(red: 0.283, green: 0.283, blue: 0.283, alpha: 1)
        layer.cornerRadius = 2
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

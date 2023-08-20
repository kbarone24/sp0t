//
//  HomeScreenTableFooter.swift
//  Spot
//
//  Created by Kenny Barone on 8/5/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class HomeScreenTableFooter: UIView {
    private lazy var gradientView = UIView()

    private(set) lazy var shareButton = ButtonBarButton(
        backgroundColor: UIColor(red: 0.74, green: 0.349, blue: 0.837, alpha: 1),
        borderColor: UIColor(red: 0.991, green: 0.525, blue: 1, alpha: 1).cgColor,
        image: UIImage(named: "WhiteShareButton") ?? UIImage(),
        title: "share")

    private(set) lazy var refreshButton = ButtonBarButton(
        backgroundColor: UIColor(red: 0.821, green: 0.536, blue: 0.109, alpha: 1),
        borderColor: UIColor(red: 0.988, green: 0.694, blue: 0.141, alpha: 1).cgColor,
        image: UIImage(named: "RefreshLocationIcon") ?? UIImage(),
        title: "refresh location")

    private(set) lazy var inboxButton = ButtonBarButton(
        backgroundColor:  UIColor(red: 0.109, green: 0.729, blue: 0.729, alpha: 1),
        borderColor: UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1).cgColor,
        image: UIImage(named: "InboxIcon") ?? UIImage(),
        title: "inbox")

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(gradientView)
        gradientView.isUserInteractionEnabled = false
        gradientView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        addSubview(shareButton)
        shareButton.snp.makeConstraints {
            $0.leading.equalTo(16)
            $0.bottom.equalTo(-40)
            // height and width include offset for unseen icon (x: 5.5, y: 7.5)
            $0.height.equalTo(44.5)
            $0.width.equalTo(95.5)
        }

        addSubview(inboxButton)
        inboxButton.snp.makeConstraints {
            $0.trailing.equalTo(-10.5)
            $0.bottom.height.width.equalTo(shareButton)
        }

        addSubview(refreshButton)
        refreshButton.snp.makeConstraints {
            $0.leading.equalTo(shareButton.snp.trailing).offset(0.5)
            $0.trailing.equalTo(inboxButton.snp.leading).offset(0.5)
            $0.bottom.height.equalTo(inboxButton)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutIfNeeded()
        for layer in gradientView.layer.sublayers ?? [] {
            layer.removeFromSuperlayer()
        }

        let layer = CAGradientLayer()
        layer.frame = gradientView.bounds
        layer.colors = [
            UIColor.white.withAlphaComponent(0.0).cgColor,
            UIColor.white.withAlphaComponent(0.6).cgColor,
            UIColor.white.withAlphaComponent(1.0).cgColor,
        ]
        layer.locations = [0, 0.3, 0.75]
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        gradientView.layer.addSublayer(layer)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // avoid stealing touches from tableView
        return point.y > shareButton.frame.minY - 5
    }
    


    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class HomeScreenFooterGradientLayer: CAGradientLayer {
    override init() {
        super.init()
        colors = [
            UIColor(red: 0.225, green: 0.721, blue: 1, alpha: 1).cgColor,
            UIColor(red: 0.142, green: 0.897, blue: 1, alpha: 1).cgColor,
            UIColor(red: 0.379, green: 0.926, blue: 1, alpha: 1).cgColor
        ]
        locations = [0, 0.53, 1]
        startPoint = CGPoint(x: 0.5, y: 0.0)
        endPoint = CGPoint(x: 0.5, y: 1.0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

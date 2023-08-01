//
//  SpotMoveCloserFooter.swift
//  Spot
//
//  Created by Kenny Barone on 7/19/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol SpotMoveCloserFooterDelegate: AnyObject {
    func refreshLocation()
}

class SpotMoveCloserFooter: UIView {
    private lazy var label: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        label.font = UIFont(name: "SFCompactRounded-Semibold", size: 18)
        label.textAlignment = .center
        label.text = "📍 MOVE CLOSER TO TALK 😿"
        return label
    }()

    private lazy var refreshButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "RefreshLocationButton"), for: .normal)
        button.addTarget(self, action: #selector(refreshLocation), for: .touchUpInside)
        return button
    }()

    weak var delegate: SpotMoveCloserFooterDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.106, green: 0.106, blue: 0.106, alpha: 1)

        addSubview(label)
        label.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(16)
        }

        addSubview(refreshButton)
        refreshButton.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(label.snp.bottom).offset(10)
            $0.height.equalTo(30)
            $0.width.equalTo(172)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func refreshLocation() {
        delegate?.refreshLocation()
    }
}

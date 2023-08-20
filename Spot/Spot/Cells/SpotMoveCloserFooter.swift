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
        label.textColor = .white
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 15.5)
        label.textAlignment = .center
        label.text = "NOT IN RANGE - MOVE CLOSER TO TALK"
        return label
    }()

    private lazy var refreshButton = PillButtonWithImage(backgroundColor: .white, image: UIImage(named: "RefreshIcon"), title: "Refresh location", titleColor: .black)

    weak var delegate: SpotMoveCloserFooterDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = SpotColors.HeaderGray.color

        addSubview(label)
        label.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(16)
        }

        addSubview(refreshButton)
        refreshButton.addTarget(self, action: #selector(refreshLocation), for: .touchUpInside)
        refreshButton.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(label.snp.bottom).offset(10)
            $0.height.equalTo(37)
            $0.width.equalTo(180)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func refreshLocation() {
        delegate?.refreshLocation()
    }
}

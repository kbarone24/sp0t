//
//  EmptySpotscoreCell.swift
//  Spot
//
//  Created by Kenny Barone on 4/26/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class EmptySpotscoreCell: UITableViewCell {
    private lazy var dotView = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        selectionStyle = .none

        contentView.addSubview(dotView)
        dotView.snp.makeConstraints {
            $0.leading.equalTo(47)
            $0.width.equalTo(2)
            $0.height.equalTo(8)
        }

        addDots()
    }

    private func addDots() {
        // min spotscore == 1, so blue dots always added for row 0
        for i in 0...1 {
            let dot = UIView()
            dot.backgroundColor = UIColor(red: 0.227, green: 0.851, blue: 0.953, alpha: 1)
            dotView.addSubview(dot)
            dot.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.height.equalTo(2)
                $0.top.equalTo(CGFloat(i * 6))
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

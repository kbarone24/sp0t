//
//  SearchContactsHeader.swift
//  Spot
//
//  Created by Kenny Barone on 11/8/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class SearchContactsHeader: UITableViewHeaderFooterView {
    private lazy var label: UILabel = {
        let label = UILabel()
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 14)
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.textAlignment = .center
        return label
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        let backgroundView = UIView()
        backgroundView.backgroundColor = .white
        self.backgroundView = backgroundView

        addSubview(label)
        label.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setLabel(count: Int) {
        let boldText = String(count)
        label.text = "It's already popping. You have \(boldText) contacts on sp0t:"
        label.attributedText = label.text?.getAttributedText(boldString: boldText, font: label.font) ?? NSAttributedString(string: "")
    }
}

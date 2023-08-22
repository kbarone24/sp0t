//
//  CountryPickerCell.swift
//  Spot
//
//  Created by Kenny Barone on 8/21/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class CountryCell: UITableViewCell {
    private lazy var countryName: UILabel = {
        let label = UILabel()
        label.textColor = SpotColors.SpotBlack.color
        label.font = SpotFonts.SFCompactRoundedRegular.fontWith(size: 16)
        return label
    }()

    private lazy var countryCode: UILabel = {
        let label = UILabel()
        label.textColor = SpotColors.SpotBlack.color.withAlphaComponent(0.8)
        label.font = SpotFonts.SFCompactRoundedRegular.fontWith(size: 16)
        return label
    }()

    var bottomLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
        return view
    }()

    var code: CountryCode! {
        didSet {
            countryName.text = code.name
            countryCode.text = code.code
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .white
        selectionStyle = .none

        contentView.addSubview(countryCode)
        countryCode.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-14)
            $0.top.equalTo(20)
        }

        contentView.addSubview(countryName)
        countryName.snp.makeConstraints {
            $0.leading.equalTo(16)
            $0.trailing.equalTo(countryCode.snp.leading).offset(-10)
            $0.top.equalTo(20)
        }

        contentView.addSubview(bottomLine)
        bottomLine.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(14)
            $0.bottom.equalToSuperview()
            $0.height.equalTo(1)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUp(code: CountryCode) {
        self.code = code
    }
}

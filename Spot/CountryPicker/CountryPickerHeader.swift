//
//  CountryPickerHeader.swift
//  Spot
//
//  Created by Kenny Barone on 8/21/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol CountryPickerHeaderDelegate: AnyObject {
    func exit()
}

class CountryPickerHeader: UITableViewHeaderFooterView {
    weak var delegate: CountryPickerHeaderDelegate?

    private lazy var label: UILabel = {
        let label = UILabel()
        label.text = "Select country"
        label.textColor = .black
        label.textAlignment = .center
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 18)
        return label
    }()

    private lazy var exitButton: UIButton = {
        let button = UIButton(withInsets: NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
        button.setImage(UIImage(named: "CancelButtonDark"), for: .normal)
        button.addTarget(self, action: #selector(exit), for: .touchUpInside)
        return button
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        let backgroundView = UIView()
        backgroundView.backgroundColor = .white
        self.backgroundView = backgroundView

        addSubview(label)
        label.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(2)
        }

        addSubview(exitButton)
        exitButton.snp.makeConstraints {
            $0.leading.top.equalTo(10)
            $0.height.width.equalTo(35)
        }
    }

    @objc func exit() {
        delegate?.exit()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//
//  SpotPageHeaderCell.swift
//  Spot
//
//  Created by Arnold on 8/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import Mixpanel
import SnapKit
import UIKit

class SpotPageHeaderCell: UICollectionViewCell {
    private lazy var spotName: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    private var detailLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
        label.adjustsFontSizeToFitWidth = true
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        spotName.text = ""
        detailLabel.text = ""
    }

    public func cellSetup(spotName: String, spot: MapSpot?) {
        self.spotName.text = spotName
        self.spotName.sizeToFit()
        guard spot != nil else { return }
        detailLabel.text = spot?.city ?? ""
    }
}

extension SpotPageHeaderCell {
    private func viewSetup() {
        contentView.backgroundColor = UIColor(named: "SpotBlack")

        contentView.addSubview(spotName)
        spotName.snp.makeConstraints {
            $0.top.equalTo(20)
            $0.leading.trailing.equalToSuperview().inset(17)
            $0.height.equalTo(23)
        }

        contentView.addSubview(detailLabel)
        detailLabel.snp.makeConstraints {
            $0.leading.trailing.equalTo(spotName)
            $0.top.equalTo(spotName.snp.bottom).offset(4)
        }
    }
}

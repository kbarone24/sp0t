//
//  SpotPageHeaderCell.swift
//  Spot
//
//  Created by Arnold on 8/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SnapKit
import Firebase
import Mixpanel

class SpotPageHeaderCell: UICollectionViewCell {

    private var spotName: UILabel!
    private var spotInfo: UILabel!

    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        spotName.text = ""
        spotInfo.text = ""
    }

    public func cellSetup(spotName: String, spot: MapSpot?) {
        self.spotName.text = spotName
        guard spot != nil else { return }
        spotInfo.text = (spot!.city == "" || spot!.city == nil) ? "\(spot!.postIDs.count) posts" : "\(spot!.city!) • \(spot!.postIDs.count) posts"
    }
}

extension SpotPageHeaderCell {
    private func viewSetup() {
        contentView.backgroundColor = .white

        spotName = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
            $0.adjustsFontSizeToFitWidth = true
            $0.text = ""
            contentView.addSubview($0)
        }
        spotName.snp.makeConstraints {
            $0.top.equalToSuperview().offset(50)
            $0.leading.trailing.equalToSuperview().offset(17)
            $0.height.equalTo(23)
        }
        
        spotInfo = UILabel {
            $0.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
            $0.text = ""
            $0.adjustsFontSizeToFitWidth = true
            contentView.addSubview($0)
        }
        spotInfo.snp.makeConstraints {
            $0.leading.trailing.equalTo(spotName)
            $0.top.equalTo(spotName.snp.bottom).offset(4)
        }
    }
}

//
//  SpotOverviewView.swift
//  Spot
//
//  Created by Kenny Barone on 7/7/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

final class SpotOverviewHeader: UITableViewHeaderFooterView {
    public var sort: SpotViewModel.SortMethod = .New

    private lazy var joinLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        label.font = UIFont(name: "UniversCE-Black", size: 14.5)
        return label
    }()

    private lazy var separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.179, green: 0.179, blue: 0.179, alpha: 1)
        return view
    }()

    private lazy var hereNowIcon = UIImageView(image: UIImage(named: "HereNowIcon"))

    private lazy var hereNowLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.345, green: 1, blue: 0.345, alpha: 1)
        label.font = UIFont(name: "UniversCE-Black", size: 14.5)
        return label
    }()

    private lazy var sortLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "UniversCE-Black", size: 14.5)
        return label
    }()

    private lazy var bottomLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.179, green: 0.179, blue: 0.179, alpha: 1)
        return view
    }()

    private lazy var sortArrows = UIImageView(image: UIImage(named: "SpotSortArrows"))

    private(set) lazy var sortButton = UIButton()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = SpotColors.HeaderGray.color
        self.backgroundView = backgroundView

        contentView.addSubview(joinLabel)
        joinLabel.snp.makeConstraints {
            $0.leading.equalTo(12)
            $0.centerY.equalToSuperview().offset(1)
        }

        contentView.addSubview(separatorView)
        separatorView.snp.makeConstraints {
            $0.leading.equalTo(joinLabel.snp.trailing).offset(8)
            $0.width.equalTo(2)
            $0.height.equalTo(19)
            $0.centerY.equalToSuperview()
        }

        contentView.addSubview(hereNowIcon)
        hereNowIcon.snp.makeConstraints {
            $0.leading.equalTo(separatorView.snp.trailing).offset(8)
            $0.centerY.equalToSuperview()
        }

        contentView.addSubview(hereNowLabel)
        hereNowLabel.snp.makeConstraints {
            $0.leading.equalTo(hereNowIcon.snp.trailing).offset(4.5)
            $0.centerY.equalToSuperview().offset(1)
        }

        contentView.addSubview(sortArrows)
        sortArrows.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-17)
            $0.centerY.equalToSuperview()
        }

        contentView.addSubview(sortLabel)
        sortLabel.snp.makeConstraints {
            $0.trailing.equalTo(sortArrows.snp.leading).offset(-9)
            $0.centerY.equalToSuperview().offset(1)
        }

        contentView.addSubview(sortButton)
        sortButton.snp.makeConstraints {
            $0.leading.equalTo(sortLabel.snp.leading).offset(-5)
            $0.trailing.equalTo(sortArrows.snp.trailing).offset(5)
            $0.centerY.height.equalToSuperview()
        }

        contentView.addSubview(bottomLine)
        bottomLine.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(1)
        }
    }

    func configure(spot: MapSpot, sort: SpotViewModel.SortMethod) {
        joinLabel.text = "\(spot.visitorList.count) joined"
        hereNowLabel.text = "\(spot.hereNow?.count ?? 0) here"
        sortLabel.text = sort.rawValue

        separatorView.isHidden = spot.hereNow?.isEmpty ?? true
        hereNowIcon.isHidden = spot.hereNow?.isEmpty ?? true
        hereNowLabel.isHidden = spot.hereNow?.isEmpty ?? true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

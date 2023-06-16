//
//  SearchResultCell.swift
//  Spot
//
//  Created by Kenny Barone on 6/15/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class SearchResultCell: UITableViewCell {

    lazy var label: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SFCompactText-Semibold", size: 14)
        label.textColor = .white
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUp()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        backgroundColor = UIColor(named: "SpotBlack")

        contentView.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.top.bottom.equalToSuperview().inset(5)
        }
    }

    func configure(searchResult: SearchResult) {
        switch searchResult.type {
        case .map:
            label.text = searchResult.map?.mapName ?? ""
        case .spot:
            label.text = searchResult.spot?.spotName ?? ""
        case .user:
            label.text = searchResult.user?.username ?? ""
        }
    }
}

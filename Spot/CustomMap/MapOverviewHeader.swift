//
//  MapOverviewHeader.swift
//  Spot
//
//  Created by Kenny Barone on 10/6/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

protocol MapHeaderDelegate: AnyObject {
    func joinMap()
    func newSort()
    func hotSort()
}

final class MapOverviewHeader: UITableViewHeaderFooterView {
    public var sort: SpotViewModel.SortMethod = .New

    private lazy var joinLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        label.font = SpotFonts.UniversCE.fontWith(size: 14.5)
        return label
    }()

    private lazy var joinMapButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = SpotColors.SpotGreen.color
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.setTitle("Join", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 14)
        button.addTarget(self, action: #selector(joinTap), for: .touchUpInside)
        return button
    }()

    private lazy var sortLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = SpotFonts.UniversCE.fontWith(size: 14.5)
        return label
    }()

    private lazy var bottomLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.179, green: 0.179, blue: 0.179, alpha: 1)
        return view
    }()

    lazy var newButton: UIButton = {
        let button = UIButton(withInsets: NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
        button.setTitle("New", for: .normal)
        button.addTarget(self, action: #selector(newSortTap), for: .touchUpInside)
        return button
    }()

    lazy var hotButton: UIButton = {
        let button = UIButton(withInsets: NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
        button.setTitle("Hot", for: .normal)
        button.addTarget(self, action: #selector(hotSortTap), for: .touchUpInside)
        return button
    }()

    private lazy var separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.179, green: 0.179, blue: 0.179, alpha: 1)
        return view
    }()

    weak var delegate: MapHeaderDelegate?

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

        contentView.addSubview(joinMapButton)
        joinMapButton.snp.makeConstraints {
            $0.leading.equalTo(joinLabel)
            $0.top.bottom.equalToSuperview().inset(6)
            $0.height.equalTo(24).priority(.high)
            $0.width.equalTo(60)
        }

        contentView.addSubview(hotButton)
        hotButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-7)
            $0.centerY.equalToSuperview().offset(1)
        }

        contentView.addSubview(separatorView)
        separatorView.snp.makeConstraints {
            $0.trailing.equalTo(hotButton.snp.leading).offset(-3)
            $0.height.equalTo(16)
            $0.width.equalTo(1)
            $0.centerY.equalToSuperview().offset(0.5)
        }

        contentView.addSubview(newButton)
        newButton.snp.makeConstraints {
            $0.trailing.equalTo(separatorView.snp.leading).offset(-3)
            $0.centerY.equalTo(hotButton)
        }

        contentView.addSubview(bottomLine)
        bottomLine.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(1)
        }
    }

    func configure(map: CustomMap, sort: CustomMapViewModel.SortMethod, delegate: MapHeaderDelegate) {
        self.delegate = delegate

        joinLabel.text = "\(map.likers.count) joined"
        joinMapButton.isHidden = map.likers.contains(UserDataModel.shared.uid) || map.secret
        joinLabel.isHidden = !joinMapButton.isHidden

        configureSelectedSort(sort: sort)
    }

    private func configureSelectedSort(sort: CustomMapViewModel.SortMethod) {
        // only using attributed strings because setTitleColor wasnt working

        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: SpotFonts.UniversCE.fontWith(size: 13),
            .foregroundColor: UIColor.white
        ]
        let unselectedAttributes: [NSAttributedString.Key: Any] = [
            .font: SpotFonts.UniversCE.fontWith(size: 13),
            .foregroundColor: UIColor.white.withAlphaComponent(0.5)
        ]

        switch sort {
        case .New:
            newButton.setAttributedTitle(NSAttributedString(string: "New", attributes: selectedAttributes), for: .normal)
            hotButton.setAttributedTitle(NSAttributedString(string: "Hot", attributes: unselectedAttributes), for: .normal)
        case .Hot:
            hotButton.setAttributedTitle(NSAttributedString(string: "Hot", attributes: selectedAttributes), for: .normal)
            newButton.setAttributedTitle(NSAttributedString(string: "New", attributes: unselectedAttributes), for: .normal)
        }
    }


    @objc func joinTap() {
        Mixpanel.mainInstance().track(event: "MapPageJoinTap")
        delegate?.joinMap()
    }

    @objc func newSortTap() {
        print("new sort")
        Mixpanel.mainInstance().track(event: "MapPageNewTap")
        delegate?.newSort()
    }

    @objc func hotSortTap() {
        print("hot sort")
        Mixpanel.mainInstance().track(event: "MapPageHotTap")
        delegate?.hotSort()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

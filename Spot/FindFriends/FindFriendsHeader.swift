//
//  SuggestedFriendsHeader.swift
//  Spot
//
//  Created by Kenny Barone on 10/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

class FindFriendsHeader: UITableViewHeaderFooterView {
    private lazy var label: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
        return label
    }()

    private lazy var refreshButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "RefreshIcon"), for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 4)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 7.5, right: 5)
        button.setTitle("Refresh", for: .normal)
        button.setTitleColor(UIColor(red: 0, green: 0, blue: 0, alpha: 1), for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14)
        button.contentVerticalAlignment = .center
        button.contentHorizontalAlignment = .center
        button.addTarget(self, action: #selector(refreshTap(_:)), for: .touchUpInside)
        return button
    }()

    var type: Int = 0 {
        didSet {
            if type == 0 {
                label.text = "Add contacts"
                refreshButton.isHidden = true
            } else {
                label.text = "Suggested friends"
                refreshButton.isHidden = false
            }
        }
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView

        contentView.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.bottom.equalToSuperview().offset(-10)
        }

        contentView.addSubview(refreshButton)
        refreshButton.snp.makeConstraints {
            $0.leading.equalTo(label.snp.trailing).offset(4)
            $0.bottom.equalTo(label.snp.bottom).offset(10)
            $0.width.equalTo(90)
            $0.height.equalTo(30)
        }
    }

    @objc func refreshTap(_ sender: UIButton) {
        if let vc = viewContainingController() as? FindFriendsController {
            Mixpanel.mainInstance().track(event: "FindFriendsRefresh")
            vc.suggestedUsers.shuffle()
            DispatchQueue.main.async { vc.tableView.reloadData() }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

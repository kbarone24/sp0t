//
//  FriendsMapCell.swift
//  Spot
//
//  Created by Kenny Barone on 11/16/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class FriendsMapCell: UICollectionViewCell {
    private lazy var contentArea: UIView = {
        let view = UIView()
        view.layer.borderWidth = 2.5
        view.layer.cornerRadius = 16
        return view
    }()

    private lazy var friendsCoverImage = ImageAvatarView()

    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.text = "Friends map"
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Semibold", size: 15)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    override var isSelected: Bool {
        didSet {
            setSelectedValues()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpView()
        setSelectedValues()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUpView() {
        backgroundColor = .white

        contentView.addSubview(contentArea)
        contentArea.snp.makeConstraints {
            $0.top.leading.equalToSuperview().offset(3)
            $0.bottom.trailing.equalToSuperview()
        }

        friendsCoverImage.clipsToBounds = true
        contentArea.addSubview(friendsCoverImage)
        friendsCoverImage.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(9)
            $0.bottom.equalToSuperview().inset(30)
        }

        contentArea.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(10)
            $0.top.equalTo(friendsCoverImage.snp.bottom).offset(2)
            $0.bottom.equalToSuperview().inset(2)
        }
    }

    func setUp(avatarURLs: [String]) {
        friendsCoverImage.setUp(avatarURLs: avatarURLs, annotation: false, completion: { _ in })
        friendsCoverImage.backgroundColor = .white
        friendsCoverImage.layer.cornerRadius = 9
        friendsCoverImage.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]

        setSelectedValues()
    }

    func setSelectedValues() {
        contentArea.backgroundColor = isSelected ? UIColor(red: 0.843, green: 0.992, blue: 1, alpha: 1) : UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1)
        contentArea.layer.borderColor = isSelected ? UIColor(named: "SpotGreen")?.cgColor : UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1).cgColor
    }
}

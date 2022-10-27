//
//  SearchContactsOutlet.swift
//  Spot
//
//  Created by Kenny Barone on 10/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class SearchContactsCell: UITableViewCell {
    private lazy var pillBackground: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
        view.layer.cornerRadius = 20
        return view
    }()

    private lazy var searchContactsIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.masksToBounds = false
        imageView.clipsToBounds = false
        imageView.contentMode = UIView.ContentMode.left
        imageView.isHidden = false
        imageView.translatesAutoresizingMaskIntoConstraints = true
        imageView.image = UIImage(named: "SearchContacts")
        imageView.layer.cornerRadius = 0
        return imageView
    }()

    private lazy var carat: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.masksToBounds = false
        imageView.clipsToBounds = false
        imageView.contentMode = UIView.ContentMode.right
        imageView.isHidden = false
        imageView.translatesAutoresizingMaskIntoConstraints = true
        imageView.image = UIImage(named: "SearchContactsCarat")
        imageView.layer.cornerRadius = 0
        return imageView
    }()

    private lazy var label: UILabel = {
        let label = UILabel()
        label.text = "Search contacts"
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Bold", size: 18.5)
        return label
    }()

    private lazy var sublabel: UILabel = {
        let label = UILabel()
        label.text = "See who you know on sp0t"
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 14)
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .white

        contentView.addSubview(pillBackground)
        pillBackground.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(15)
            $0.top.equalToSuperview()
            $0.height.equalTo(88)
        }

        pillBackground.addSubview(searchContactsIcon)
        searchContactsIcon.snp.makeConstraints {
            $0.width.height.equalTo(56)
            $0.centerY.equalToSuperview()
            $0.leading.equalToSuperview().offset(16)
        }

        pillBackground.addSubview(carat)
        carat.snp.makeConstraints {
            $0.width.equalTo(12.73)
            $0.height.equalTo(19.8)
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().offset(-20)
        }

        pillBackground.addSubview(label)
        label.snp.makeConstraints {
            $0.top.equalTo(searchContactsIcon).offset(6)
            $0.leading.equalTo(searchContactsIcon.snp.trailing).offset(10)
        }

        pillBackground.addSubview(sublabel)
        sublabel.snp.makeConstraints {
            $0.top.equalTo(label.snp.bottom).offset(2)
            $0.leading.equalTo(label)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//
//  ContactsTitleView.swift
//  Spot
//
//  Created by Kenny Barone on 3/8/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class ContactsTitleView: UIView {
    var title: UILabel = {
        let label = UILabel()
        label.text = "Contacts"
        label.font = UIFont(name: "SFCompactText-Heavy", size: 19)
        label.textColor = UIColor(named: "SpotWhite")
        return label
    }()

    var subtitle: UILabel = {
        let label = UILabel()
        label.text = "Send a request to see who they are on sp0t 👀"
        label.font = UIFont(name: "SFCompactText-Semibold", size: 14.5)
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        return label
    }()

    var contactsCount: Int = 0 {
        didSet {
            if contactsCount > 0 {
                title.text = "\(contactsCount) Contacts joined"
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(subtitle)
        subtitle.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().offset(-4)
        }

        addSubview(title)
        title.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalTo(subtitle.snp.top).offset(-2)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        print("title view frame", frame)
    }
}

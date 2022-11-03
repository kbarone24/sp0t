//
//  ExtraCountCell.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 11/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class ExtraCountCell: UICollectionViewCell {
    
    private lazy var label: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(hexString: "D6D6D6")
        label.font = UIFont(name: "SFCompactText-Bold", size: 30.0)
        label.numberOfLines = 0
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(hexString: "F5F5F5")
        contentView.backgroundColor = UIColor(hexString: "F5F5F5")
        
        contentView.addSubview(label)
        
        label.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.equalToSuperview().offset(20.0)
            $0.trailing.equalToSuperview().inset(20.0)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(text: String) {
        label.text = text
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        label.text = ""
    }
}

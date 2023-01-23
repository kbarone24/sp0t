//
//  CountryCodeView.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 1/19/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit

final class CountryCodeView: UIButton {
    var number: UILabel!
    
    private(set) lazy var editButton: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "DownCarat")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    var separatorLine: UIView!
    
    var code: String = "" {
        didSet {
            number.text = code
            number.sizeToFit()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        number = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 28)
            $0.textAlignment = .left
            addSubview($0)
        }
        
        number.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.top.equalTo(5)
        }
        
        addSubview(editButton)
        editButton.snp.makeConstraints {
            $0.leading.equalTo(number.snp.trailing).offset(3)
            $0.top.equalTo(20)
            $0.width.equalTo(12)
            $0.height.equalTo(9)
        }
        
        separatorLine = UIView {
            $0.backgroundColor = UIColor(red: 0.704, green: 0.704, blue: 0.704, alpha: 1.0)
            addSubview($0)
        }
        separatorLine.snp.makeConstraints {
            $0.leading.equalTo(editButton.snp.trailing).offset(12)
            $0.top.bottom.equalToSuperview()
            $0.width.equalTo(1)
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

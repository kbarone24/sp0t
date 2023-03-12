//
//  CountryCodeView.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 1/19/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit

final class CountryCodeView: UIButton {
    private(set) lazy var number: UILabel = {
        // TODO: replace with real font (UniversCE55Medium-Bold)
        let label = UILabel()
        label.textColor = UIColor(red: 0.358, green: 0.357, blue: 0.357, alpha: 1)
        label.font = UIFont(name: "UniversCE-Black", size: 22)
        label.textAlignment = .left
        return label
    }()
    
    private(set) lazy var editButton: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "DownCarat")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    var code: String {
        didSet {
            number.text = code
            number.sizeToFit()
        }
    }
    
    init(code: String) {
        self.code = code
        super.init(frame: .zero)

        addSubview(number)
        number.text = code
        number.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.top.equalTo(5)
        }
        
        addSubview(editButton)
        editButton.snp.makeConstraints {
            $0.leading.equalTo(number.snp.trailing).offset(3)
            $0.centerY.equalTo(number)
            $0.width.equalTo(12)
            $0.height.equalTo(9)
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//
//  ProgressBar.swift
//  Spot
//
//  Created by Kenny Barone on 10/6/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class ProgressBar: UIView {
    private(set) lazy var progressFill: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(named: "SpotGreen")
        view.layer.cornerRadius = 6.0
        
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor(named: "SpotGreen")?.withAlphaComponent(0.22)
        layer.cornerRadius = 6
        layer.borderWidth = 2
        layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        
        addSubview(progressFill)
        progressFill.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(1)
            $0.width.equalTo(0)
            $0.height.equalTo(16)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

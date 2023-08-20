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
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor(named: "SpotGreen")?.withAlphaComponent(0.22)

        addSubview(progressFill)
        progressFill.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(1)
            $0.width.equalTo(0)
            $0.top.bottom.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

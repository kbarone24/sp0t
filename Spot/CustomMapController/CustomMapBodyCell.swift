//
//  CustomMapBodyCell.swift
//  Spot
//
//  Created by Arnold on 7/24/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import SDWebImage
import UIKit

final class CustomMapBodyCell: UICollectionViewCell {
    
    private lazy var body: MapPostBody = {
        let body = MapPostBody()
        return body
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .white
        backgroundColor = .white
        
        contentView.addSubview(body)
        
        body.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        body.reset()
    }

    public func cellSetup(postData: MapPost) {
        body.configure(data: postData)
        layoutIfNeeded()
    }
}

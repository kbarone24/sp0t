//
//  MapMemberCell.swift
//  Spot
//
//  Created by Arnold on 8/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import FirebaseUI

class MapMemberCell: UICollectionViewCell {
    
    private var userImageView: UIImageView!
    private var userNameLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func cellSetUp(user: UserProfile) {
        if user.imageURL != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            userImageView.sd_setImage(with: URL(string: user.imageURL), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        } else {
            userImageView.image = UIImage(named: "AddMembers")
        }

        userNameLabel.text = user.name
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        userImageView.sd_cancelCurrentImageLoad()
    }
}

extension MapMemberCell {
    private func viewSetup() {
        contentView.backgroundColor = .white
        
        userImageView = UIImageView {
            $0.image = UIImage()
            $0.contentMode = .scaleAspectFill
            $0.layer.cornerRadius = 31
            $0.clipsToBounds = true
            contentView.addSubview($0)
        }
        userImageView.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.width.height.equalTo(62)
        }
        
        userNameLabel = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 14)
            $0.textAlignment = .center
            contentView.addSubview($0)
        }
        userNameLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(userImageView.snp.bottom).offset(6)
            $0.height.equalTo(17)
        }
    }
}

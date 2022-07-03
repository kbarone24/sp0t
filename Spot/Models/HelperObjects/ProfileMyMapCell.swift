//
//  ProfileMyMapCell.swift
//  Spot
//
//  Created by Arnold on 7/1/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

class ProfileMyMapCell: UICollectionViewCell {
    private var mapImageCollectionView: UICollectionView!
    var mapName: UILabel!
    var myMapImages: [UIImage] = [] {
        didSet {
            if myMapImages.count >= 9 {
                myMapImages = Array(myMapImages[0...8])
            } else if myMapImages.count >= 4 {
                myMapImages = Array(myMapImages[0...3])
            } else {
                myMapImages = [myMapImages[0]]
            }
            mapImageCollectionView.reloadData()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        
    }
}

extension ProfileMyMapCell {
    private func viewSetup() {
        contentView.backgroundColor = .white

        mapImageCollectionView = {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .vertical
            let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
            view.delegate = self
            view.dataSource = self
            view.backgroundColor = .clear
            view.layer.masksToBounds = true
            view.layer.cornerRadius = 14
            view.isUserInteractionEnabled = false
            view.register(ProfileMyMapImageCollectionViewCell.self, forCellWithReuseIdentifier: "ProfileMyMapImageCollectionViewCell")
            return view
        }()
        contentView.addSubview(mapImageCollectionView)
        mapImageCollectionView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(contentView.frame.width).multipliedBy(182/195)
        }
        
        mapName = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 16)
            $0.text = "\(UserDataModel.shared.userInfo.name)'s posts"
            contentView.addSubview($0)
        }
        mapName.snp.makeConstraints {
            $0.leading.trailing.equalTo(mapImageCollectionView)
            $0.top.equalTo(mapImageCollectionView.snp.bottom).offset(6)
        }
    }
}

extension ProfileMyMapCell: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return myMapImages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProfileMyMapImageCollectionViewCell", for: indexPath) as! ProfileMyMapImageCollectionViewCell
        cell.mapImageView.image = myMapImages[indexPath.row]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: (collectionView.frame.width - 2) / sqrt(CGFloat(myMapImages.count)) , height: (collectionView.frame.height - 2) / sqrt(CGFloat(myMapImages.count)))
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
}


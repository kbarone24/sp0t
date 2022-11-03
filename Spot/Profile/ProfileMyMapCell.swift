//
//  ProfileMyMapCell.swift
//  Spot
//
//  Created by Arnold on 7/1/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

class ProfileMyMapCell: UICollectionViewCell {
    private var posts: [MapPost] = [] {
        didSet {
            if posts.count >= 9 {
                posts = Array(posts[0...8])
            } else if posts.count >= 4 {
                posts = Array(posts[0...3])
            } else {
                posts = posts.isEmpty ? [] : [posts[0]]
            }
            DispatchQueue.main.async { self.mapImageCollectionView.reloadData() }
        }
    }

    private lazy var mapImageCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = UIColor(named: "BlankImage")
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 14
        view.isUserInteractionEnabled = false
        view.register(ProfileMyMapImageCollectionViewCell.self, forCellWithReuseIdentifier: "ProfileMyMapImageCollectionViewCell")
        return view
    }()

    private lazy var mapPrivateBlurView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.clipsToBounds = true
        blurEffectView.frame = CGRect(x: 0, y: 0, width: contentView.frame.width, height: contentView.frame.width * 182 / 195)
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return blurEffectView
    }()

    private lazy var mapPrivateIcon = UIImageView(image: UIImage(named: "UsersMapNotFriends"))

    private lazy var mapName: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Semibold", size: 16)
        label.text = "@\(UserDataModel.shared.userInfo.username)'s map"
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func cellSetup(userAccount: String, posts: [MapPost], relation: ProfileRelation) {
        self.posts = posts
        mapName.text = "@\(userAccount)'s map"
        mapPrivateBlurView.isHidden = !(relation == .stranger || relation == .pending || relation == .received)
        mapPrivateIcon.isHidden = !(relation == .stranger || relation == .pending || relation == .received)
    }
}

extension ProfileMyMapCell {
    private func viewSetup() {
        contentView.backgroundColor = .white

        mapImageCollectionView.delegate = self
        mapImageCollectionView.dataSource = self
        contentView.addSubview(mapImageCollectionView)
        mapImageCollectionView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(contentView.frame.width).multipliedBy(182 / 195)
        }

        mapImageCollectionView.addSubview(mapPrivateBlurView)

        mapImageCollectionView.addSubview(mapPrivateIcon)
        mapPrivateIcon.snp.makeConstraints {
            $0.center.equalToSuperview()
        }

        contentView.addSubview(mapName)
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
        return posts.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let reuseID = "ProfileMyMapImageCollectionViewCell"
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseID, for: indexPath) as? ProfileMyMapImageCollectionViewCell else { return UICollectionViewCell() }
        cell.count = posts.count
        cell.imageURL = posts[indexPath.row].imageURLs.first ?? ""
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let seperateLineWidth = 2 * (sqrt(CGFloat(posts.count)) - 1)
        return CGSize(width: (collectionView.frame.width - seperateLineWidth) / sqrt(CGFloat(posts.count)), height: (collectionView.frame.height - seperateLineWidth) / sqrt(CGFloat(posts.count)))
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 2
    }
}
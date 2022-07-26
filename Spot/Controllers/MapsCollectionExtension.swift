//
//  MapsCollectionExtension.swift
//  Spot
//
//  Created by Kenny Barone on 7/21/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

extension MapController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return feedLoaded ? UserDataModel.shared.userInfo.mapsList.count + 1 : 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MapCell", for: indexPath) as? MapHomeCell {
            let map = UserDataModel.shared.userInfo.mapsList[safe: indexPath.row - 1]
            var avatarURLs = map == nil ? friendsPostsDictionary.values.map({$0.userInfo?.avatarURL ?? ""}).prefix(7) : []
            if avatarURLs.isEmpty { avatarURLs.append(UserDataModel.shared.userInfo.avatarURL ?? "") }
            cell.setUp(map: map, avatarURLs: Array(avatarURLs))
            return cell
        }
        return UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .left)
        selectedItemIndex = indexPath.item
        if selectedItemIndex != 0 { UserDataModel.shared.userInfo.mapsList[indexPath.row - 1].selected.toggle() }
    }
}

class MapHomeCell: UICollectionViewCell {
    var newIndicator: UIView!
    var contentArea: UIView!
    var mapCoverImage: UIImageView!
    var friendsCoverImage: ImageAvatarView!
    var lockIcon: UIImageView!
    var nameLabel: UILabel!
    
    override var isSelected: Bool {
        didSet {
            contentArea.backgroundColor = isSelected ? UIColor(red: 0.843, green: 0.992, blue: 1, alpha: 1) : UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1)
            contentArea.layer.borderColor = isSelected ? UIColor(named: "SpotGreen")!.cgColor : UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1).cgColor
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
                
        if contentArea != nil { contentArea.removeFromSuperview() }
        contentArea = UIView {
            $0.backgroundColor = isSelected ? UIColor(red: 0.843, green: 0.992, blue: 1, alpha: 1) : UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1)
            $0.layer.borderWidth = 2.5
            $0.layer.borderColor = isSelected ? UIColor(named: "SpotGreen")!.cgColor : UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1).cgColor
            $0.layer.cornerRadius = 16
            contentView.addSubview($0)
        }
        contentArea.snp.makeConstraints {
            $0.top.leading.equalToSuperview().offset(3)
            $0.bottom.trailing.equalToSuperview()
        }
        
        if newIndicator != nil { newIndicator.removeFromSuperview() }
        newIndicator = UIView {
            $0.backgroundColor = UIColor(named: "SpotGreen")
            $0.layer.cornerRadius = 20/2
            $0.isHidden = true
            contentView.addSubview($0)
        }
        newIndicator.snp.makeConstraints {
            $0.top.leading.equalToSuperview()
            $0.width.height.equalTo(20)
        }
        
        if mapCoverImage != nil { mapCoverImage.removeFromSuperview() }
        mapCoverImage = UIImageView {
            $0.layer.cornerRadius = 2
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFill
            $0.isHidden = true
            contentArea.addSubview($0)
        }
        mapCoverImage.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(9)
            $0.bottom.equalToSuperview().inset(30)
        }
        
        if friendsCoverImage != nil { friendsCoverImage.removeFromSuperview() }
        friendsCoverImage = ImageAvatarView {
            $0.clipsToBounds = true
            $0.isHidden = true
            contentArea.addSubview($0)
        }
        friendsCoverImage.snp.makeConstraints {
            $0.edges.equalTo(mapCoverImage.snp.edges)
        }
        
        if nameLabel != nil { nameLabel.removeFromSuperview() }
        nameLabel = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 15)
            $0.numberOfLines = 0
            $0.adjustsFontSizeToFitWidth = true
            $0.minimumScaleFactor = 0.75
            $0.textAlignment = .center
            $0.lineBreakMode = .byTruncatingTail
            contentArea.addSubview($0)
        }
        nameLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(10)
            $0.top.equalTo(mapCoverImage.snp.bottom).offset(2)
            $0.bottom.equalToSuperview().inset(2)
        }
        
        if lockIcon != nil { lockIcon.removeFromSuperview() }
        lockIcon = UIImageView {
            $0.image = UIImage(named: "HomeLockIcon")
            $0.isHidden = true
            addSubview($0)
        }
        lockIcon.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(13.5)
            $0.width.equalTo(21)
            $0.height.equalTo(19)
        }
        
        layoutIfNeeded()
        /// add image bottom corner radius
        let maskPath = UIBezierPath(roundedRect: mapCoverImage.bounds,
                                    byRoundingCorners: [.topLeft, .topRight],
                                    cornerRadii: CGSize(width: 9.0, height: 0.0))
        let maskLayer = CAShapeLayer()
        maskLayer.path = maskPath.cgPath
        mapCoverImage.layer.mask = maskLayer
        friendsCoverImage.layer.mask = maskLayer

    }
    
    func setUp(map: CustomMap?, avatarURLs: [String]) {
        if map != nil {
            mapCoverImage.isHidden = false
            mapCoverImage.sd_setImage(with: URL(string: map!.imageURL))
            let textString = NSMutableAttributedString(string: map?.mapName ?? "").shrinkLineHeight()
            nameLabel.attributedText = textString
            nameLabel.sizeToFit()
            if map!.secret { lockIcon.isHidden = false }
        } else {
            friendsCoverImage.isHidden = false
            friendsCoverImage.setUp(avatarURLs: avatarURLs)
            let textString = NSMutableAttributedString(string: "Friends").shrinkLineHeight()
            nameLabel.attributedText = textString
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if mapCoverImage != nil { mapCoverImage.sd_cancelCurrentImageLoad() }
    }
}

extension NSAttributedString {
    func shrinkLineHeight() -> NSAttributedString {
        let attributedString = NSMutableAttributedString(attributedString: self)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.lineHeightMultiple = 0.75
        paragraphStyle.alignment = .center
        attributedString.addAttribute(.paragraphStyle,
                                      value: paragraphStyle,
                                      range: NSRange(location: 0, length: string.count))
        return NSAttributedString(attributedString: attributedString)
    }
}

//
//  UploadChooseSpotCell.swift
//  Spot
//
//  Created by Kenny Barone on 9/16/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class UploadChooseSpotCell: UITableViewCell {
    
    var loaded = false
    
    var topLine: UIView!
    var titleLabel: UILabel!
    
    var newSpotView: UIView!
    var profilePic: UIImageView!
    var exitButton: UIButton!
    
    var chooseSpotCollection: UploadPillCollectionView  = UploadPillCollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())

    func setUp(newSpotName: String, post: MapPost) {
        
        backgroundColor = .black
        contentView.backgroundColor = .black
                
        resetView()
        
        topLine = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
        topLine.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        contentView.addSubview(topLine)
        
        titleLabel = UILabel(frame: CGRect(x: 16, y: 12, width: 150, height: 18))
        titleLabel.text = newSpotName == "" ? "Choose a spot" : "New spot"
        titleLabel.textColor = UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1)
        titleLabel.font = UIFont(name: "SFCamera-Regular", size: 13.5)
        contentView.addSubview(titleLabel)
        
        /// add new spot label
        if newSpotName != "" {
            
            newSpotView = UIView(frame: CGRect(x: 16, y: titleLabel.frame.maxY + 10, width: UIScreen.main.bounds.width - 16, height: 40))
            newSpotView.backgroundColor = nil
            contentView.addSubview(newSpotView)
            
            let spotName = UILabel(frame: CGRect(x: 0, y: 0, width: newSpotView.bounds.width, height: 20))
            spotName.text = newSpotName
            spotName.textColor = UIColor(red: 0.525, green: 0.525, blue: 0.525, alpha: 1)
            spotName.font = UIFont(name: "SFCamera-Semibold", size: 13.5)
            newSpotView.addSubview(spotName)
            
            let usernameLabel = UILabel(frame: CGRect(x: 0, y: spotName.frame.maxY + 4, width: newSpotView.bounds.width - 32, height: 13))
            usernameLabel.text = post.userInfo == nil ? "" : "by \(post.userInfo.username)"
            usernameLabel.textColor = UIColor(red: 0.262, green: 0.262, blue: 0.262, alpha: 1.0)
            usernameLabel.font = UIFont(name: "SFCamera-Semibold", size: 11)
            newSpotView.addSubview(usernameLabel)
            
            exitButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 52, y: spotName.frame.minY, width: 32, height: 32))
            exitButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            exitButton.setImage(UIImage(named: "CancelButton")?.withTintColor(UIColor(red: 0.77, green: 0.77, blue: 0.77, alpha: 1.00)), for: .normal)
            exitButton.addTarget(self, action: #selector(exitNewSpot(_:)), for: .touchUpInside)
            newSpotView.addSubview(exitButton)

        } else {
        /// add choose spot collection
            
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .horizontal
            layout.sectionInset = UIEdgeInsets(top: 0, left: 13, bottom: 0, right: 13)
            
            chooseSpotCollection.frame = CGRect(x: 0, y: 39, width: UIScreen.main.bounds.width, height: 43)
            chooseSpotCollection.backgroundColor = .black
            chooseSpotCollection.delegate = self
            chooseSpotCollection.dataSource = self
            chooseSpotCollection.showsHorizontalScrollIndicator = false
            chooseSpotCollection.setCollectionViewLayout(layout, animated: false)
            chooseSpotCollection.register(ChooseSpotCollectionCell.self, forCellWithReuseIdentifier: "ChooseSpotCollection")
            chooseSpotCollection.register(AddSpotCell.self, forCellWithReuseIdentifier: "AddSpot")
            chooseSpotCollection.register(SeeAllCell.self, forCellWithReuseIdentifier: "SeeAll")
            contentView.addSubview(chooseSpotCollection)
            
            chooseSpotCollection.reloadSections(IndexSet(0...0))
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        /// push location picker once content offset pushes 50 pts past the natural boundary
        if scrollView.contentOffset.x > scrollView.contentSize.width - UIScreen.main.bounds.width + 60 {
            guard let uploadVC = viewContainingController() as? UploadPostController else { return }
            uploadVC.pushLocationPicker()
        }
    }
    
    func resetView() {
        if topLine != nil { topLine.backgroundColor = nil }
        if titleLabel != nil { titleLabel.text = "" }
        if newSpotView != nil { for sub in newSpotView.subviews {sub.removeFromSuperview()} }
        if profilePic != nil { profilePic.image = UIImage(); profilePic.sd_cancelCurrentImageLoad() }
        chooseSpotCollection.removeFromSuperview()
    }
    
    @objc func exitNewSpot(_ sender: UIButton) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        uploadVC.exitNewSpot()
    }
}

extension UploadChooseSpotCell: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return min(UploadImageModel.shared.nearbySpots.count + 2, 9)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        var alpha = UploadImageModel.shared.nearbySpots.contains(where: {$0.selected!}) ? 0.6 : 1.0

        if indexPath.row == 0 {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AddSpot", for: indexPath) as? AddSpotCell else { return UICollectionViewCell() }
            cell.setAlphas(alpha: alpha)
            return cell
        }
        
        if indexPath.row == min(UploadImageModel.shared.nearbySpots.count + 1, 8) {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SeeAll", for: indexPath) as? SeeAllCell else { return UICollectionViewCell() }
            cell.setUp(empty: loaded && UploadImageModel.shared.nearbySpots.count == 0)
            cell.setAlphas(alpha: alpha)
            return cell
        }
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ChooseSpotCollection", for: indexPath) as? ChooseSpotCollectionCell else { return UICollectionViewCell() }
        
        let spot = UploadImageModel.shared.nearbySpots[indexPath.row - 1]
        cell.setUp(spot: spot)
        if spot.selected! { alpha = 1.0 }
        cell.setAlphas(alpha: alpha)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if indexPath.row == 0 { return CGSize(width: 43, height: 43) }
        if indexPath.row == min(UploadImageModel.shared.nearbySpots.count + 1, 8) { return CGSize(width: loaded && UploadImageModel.shared.nearbySpots.count == 0 ? 152 : 57, height: 43) } /// return full width if empty state, otherwise just "see all"
        
        let spot = UploadImageModel.shared.nearbySpots[indexPath.row - 1]
        let cellWidth = getCellWidth(spot: spot)
        return CGSize(width: cellWidth, height: 43)
    }
    
    

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }

        /// present screen to name the new spot
        if indexPath.row == 0 {
            uploadVC.presentAddNew()
            return
        }
        
        if indexPath.row == min(UploadImageModel.shared.nearbySpots.count + 1, 8) {
            uploadVC.pushLocationPicker()
            return
        }
        
        /// select id, spot/poi, reload parent which will reload the cell -> this is kind of sloppy
        let spot = UploadImageModel.shared.nearbySpots[indexPath.row - 1]
        uploadVC.selectSpot(index: indexPath.row - 1, select: !spot.selected!, fromMap: false)
    }
    
    
    func getCellWidth(spot: MapSpot) -> CGFloat {
        
        let tempName = UILabel(frame: CGRect(x: 0, y: 0, width: 250, height: 20))
        tempName.font = UIFont(name: "SFCamera-Semibold", size: 13.5)
    
        let tempDetail = UILabel(frame: CGRect(x: 0, y: 0, width: 250, height: 15))
        tempDetail.font = UIFont(name: "SFCamera-Semibold", size: 11)
        
        tempName.text = spot.spotName
        tempName.sizeToFit()

        tempDetail.text = spot.spotDescription
        tempDetail.sizeToFit()
        
        let nameWidth = tempName.frame.width + 16
        let detailWidth = tempDetail.frame.width + 18
        
        return max(nameWidth, detailWidth)
    }
}

class AddSpotCell: UICollectionViewCell {
    
    var plusIcon: UIImageView!
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        
        plusIcon = UIImageView(frame: CGRect(x: 16, y: 16, width: 11, height: 11))
        plusIcon.image = UIImage(named: "AddIcon")
        plusIcon.isUserInteractionEnabled = false
        addSubview(plusIcon)
    }
    
    func setAlphas(alpha: CGFloat) {
        backgroundColor = UIColor(red: 0.112, green: 0.112, blue: 0.112, alpha: alpha)
        plusIcon.alpha = alpha
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SeeAllCell: UICollectionViewCell {
    
    var noneNearby: UILabel!
    var seeAll: UILabel!
    
    func setUp(empty: Bool) {
        
        var minX = 2
        
        if noneNearby != nil { noneNearby.text = "" }
        
        if empty {
            noneNearby = UILabel(frame: CGRect(x: minX, y: 16, width: 90, height: 14))
            noneNearby.text = "No spots nearby"
            noneNearby.textColor = UIColor(red: 0.363, green: 0.363, blue: 0.363, alpha: 1)
            noneNearby.font = UIFont(name: "SFCamera-Regular", size: 12)
            addSubview(noneNearby)
            
            minX += 97
        }
        
        if seeAll != nil { seeAll.text = "" }
        seeAll = UILabel(frame: CGRect(x: minX, y: 16, width: 55, height: 14))
        seeAll.text = "See all ->"
        seeAll.textColor = UIColor(named: "SpotGreen")
        seeAll.font = UIFont(name: "SFCamera-Regular", size: 12)
        addSubview(seeAll)
    }
    
    func setAlphas(alpha: CGFloat) {
        seeAll.alpha = alpha
    }
}

class ChooseSpotCollectionCell: UICollectionViewCell {
    
    var spotName: UILabel!
    var detailView: UILabel!
    var spot: MapSpot!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.borderWidth = 1
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp(spot: MapSpot) {
        
        self.spot = spot
        
        if spotName != nil { spotName.text = "" }
        spotName = UILabel(frame: CGRect(x: 8, y: 5, width: self.bounds.width - 16, height: 18.5))
        spotName.text = spot.spotName
        spotName.textColor = UIColor(red: 0.567, green: 0.567, blue: 0.567, alpha: 1)
        spotName.font = UIFont(name: "SFCamera-Semibold", size: 13.5)
        addSubview(spotName)
        
        if detailView != nil { detailView.text = "" }
        detailView = UILabel(frame: CGRect(x: 9, y: spotName.frame.maxY, width: self.bounds.width - 18, height: 15))
        detailView.text = spot.spotDescription
        detailView.font = UIFont(name: "SFCamera-Semibold", size: 11)
        detailView.textColor = UIColor(red: 0.34, green: 0.34, blue: 0.34, alpha: 1.00)
        addSubview(detailView)
        
        /// highlight founder username if applicable
        if spot.privacyLevel != "public" {
            let detail = spot.spotDescription
            let word = detail.getKeywordArray().last ?? ""
            let userNameRange = (detail as NSString).range(of: word)
            let attributedString = NSMutableAttributedString(string: detail)
            attributedString.setAttributes([NSAttributedString.Key.foregroundColor : UIColor(red: 0.47, green: 0.47, blue: 0.47, alpha: 1.00)], range: userNameRange)
            detailView.attributedText = attributedString
        }
        /// usernameDetail = UIColor(red: 0.47, green: 0.47, blue: 0.47, alpha: 1.00) ,
    }
    
    func setAlphas(alpha: CGFloat) {
        backgroundColor = spot.selected! ? UIColor(red: 0.00, green: 0.09, blue: 0.09, alpha: 1.00) : UIColor(red: 0.112, green: 0.112, blue: 0.112, alpha: alpha)
        layer.borderColor = spot.selected! ? UIColor(named: "SpotGreen")?.cgColor : UIColor(red: 0.112, green: 0.112, blue: 0.112, alpha: alpha).cgColor
        spotName.alpha = alpha
        detailView.alpha = alpha
    }
}

class UploadPillCollectionView: UICollectionView {
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if !__CGSizeEqualToSize(bounds.size, self.intrinsicContentSize) {
            self.invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        return contentSize
    }
}



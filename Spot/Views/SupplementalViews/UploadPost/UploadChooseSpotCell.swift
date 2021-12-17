//
//  UploadChooseSpotCell.swift
//  Spot
//
//  Created by Kenny Barone on 9/16/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

class UploadChooseSpotCell: UITableViewCell {
    
    var loaded = false
    var loading = true
    
    var topLine: UIView!
    var titleLabel: UILabel!
    
    var newSpotView: UIView!
    var profilePic: UIImageView!
    var exitButton: UIButton!

    var chooseSpotCollection: UploadPillCollectionView  = UploadPillCollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())

    func setUp(newSpotName: String, selected: Bool, post: MapPost) {
        
        if newSpotName != "" || selected { return } /// no need to reload when cell collapsed
        
        backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1.00)
        contentView.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1.00)
                
        resetView()
        
        topLine = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
        topLine.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        contentView.addSubview(topLine)
        
        titleLabel = UILabel(frame: CGRect(x: 16, y: 12, width: 150, height: 18))
        titleLabel.text = newSpotName == "" ? "Choose a spot" : "New spot"
        titleLabel.textColor = UIColor(red: 0.52, green: 0.52, blue: 0.52, alpha: 1.00)
        titleLabel.font = UIFont(name: "SFCamera-Regular", size: 13.5)
        contentView.addSubview(titleLabel)
                
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 6
        layout.sectionInset = UIEdgeInsets(top: 0, left: 13, bottom: 0, right: 13)
        
        chooseSpotCollection.frame = CGRect(x: 0, y: 39, width: UIScreen.main.bounds.width, height: 43)
        chooseSpotCollection.backgroundColor = nil

        chooseSpotCollection.delegate = self
        chooseSpotCollection.dataSource = self
        chooseSpotCollection.showsHorizontalScrollIndicator = false
        chooseSpotCollection.register(ChooseSpotCollectionCell.self, forCellWithReuseIdentifier: "ChooseSpotCollection")
        chooseSpotCollection.register(AddSpotCell.self, forCellWithReuseIdentifier: "AddSpot")
        chooseSpotCollection.register(SeeAllCell.self, forCellWithReuseIdentifier: "SeeAll")
        chooseSpotCollection.setCollectionViewLayout(layout, animated: false)
        contentView.addSubview(chooseSpotCollection)
        
        chooseSpotCollection.reloadSections(IndexSet(0...0))
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        /// push location picker once content offset pushes 50 pts past the natural boundary
        if scrollView.contentOffset.x > scrollView.contentSize.width - UIScreen.main.bounds.width + 80 && !loading {
            guard let uploadVC = viewContainingController() as? UploadPostController else { return }
            if !uploadVC.chooseSpotMode {
                Mixpanel.mainInstance().track(event: "UploadScrollLaunchMap", properties: nil)
                uploadVC.switchToChooseSpot()
            }
        }
    }
    
    func resetView() {
        if topLine != nil { topLine.backgroundColor = nil }
        if titleLabel != nil { titleLabel.text = "" }
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
        /// just show add new while loading
        return loading ? 1 : min(UploadImageModel.shared.nearbySpots.count + 2, 9)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if indexPath.row == 0 {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AddSpot", for: indexPath) as? AddSpotCell else { return UICollectionViewCell() }
            return cell
        }
        
        if indexPath.row == min(UploadImageModel.shared.nearbySpots.count + 1, 8) {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SeeAll", for: indexPath) as? SeeAllCell else { return UICollectionViewCell() }
            cell.setUp(empty: loaded && UploadImageModel.shared.nearbySpots.count == 0)
            return cell
        }
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ChooseSpotCollection", for: indexPath) as? ChooseSpotCollectionCell else { return UICollectionViewCell() }
        guard let spot = UploadImageModel.shared.nearbySpots[safe: indexPath.row - 1] else { return cell }
        
        cell.setUp(spot: spot)
        if spot.selected! { alpha = 1.0 }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if indexPath.row == 0 { return CGSize(width: 47, height: 43) }
        if indexPath.row == min(UploadImageModel.shared.nearbySpots.count + 1, 8) { return CGSize(width: loaded && UploadImageModel.shared.nearbySpots.count == 0 ? 152 : 57, height: 43) } /// return full width if empty state, otherwise just "see all"
        
        guard let spot = UploadImageModel.shared.nearbySpots[safe: indexPath.row - 1] else { return CGSize(width: 10, height: 10) }
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
            Mixpanel.mainInstance().track(event: "UploadSeeAllLaunchMap", properties: nil)
            uploadVC.switchToChooseSpot()
            return
        }
        
        /// select id, spot/poi, reload parent which will reload the cell -> this is kind of sloppy
        guard let spot = UploadImageModel.shared.nearbySpots[safe: indexPath.row - 1] else { return }
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
        backgroundColor = UIColor(red: 0.112, green: 0.112, blue: 0.112, alpha: alpha)
        
        plusIcon = UIImageView(frame: CGRect(x: 11, y: 5, width: 25, height: 33.5))
        plusIcon.image = UIImage(named: "NewSpotButton")
        plusIcon.isUserInteractionEnabled = false
        addSubview(plusIcon)
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
        backgroundColor = UIColor(red: 0.112, green: 0.112, blue: 0.112, alpha: alpha)
        layer.borderColor = UIColor(red: 0.112, green: 0.112, blue: 0.112, alpha: alpha).cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp(spot: MapSpot) {
        
        self.spot = spot
        
        /// slide spot name down if no description
        let minY: CGFloat = spot.spotDescription == "" ? 11 : 5
        if spotName != nil { spotName.text = "" }
        spotName = UILabel(frame: CGRect(x: 8, y: minY, width: self.bounds.width - 16, height: 18.5))
        spotName.text = spot.spotName
        spotName.textColor = UIColor(red: 0.565, green: 0.565, blue: 0.565, alpha: 1)
        spotName.font = UIFont(name: "SFCamera-Semibold", size: 13.5)
        addSubview(spotName)
        
        if detailView != nil { detailView.text = "" }
        if spot.spotDescription != "" {
            detailView = UILabel(frame: CGRect(x: 9, y: spotName.frame.maxY, width: self.bounds.width - 18, height: 15))
            detailView.text = spot.spotDescription
            detailView.font = UIFont(name: "SFCamera-Semibold", size: 11)
            detailView.textColor = UIColor(red: 0.342, green: 0.342, blue: 0.342, alpha: 1)
            addSubview(detailView)
        }
        
        /// highlight founder username if applicable
        if spot.privacyLevel != "public" {
            let detail = spot.spotDescription
            let word = detail.getKeywordArray().last ?? ""
            let userNameRange = (detail as NSString).range(of: word)
            let attributedString = NSMutableAttributedString(string: detail)
            attributedString.setAttributes([NSAttributedString.Key.foregroundColor : UIColor(red: 0.47, green: 0.47, blue: 0.47, alpha: 1.00)], range: userNameRange)
            detailView.attributedText = attributedString
        }
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



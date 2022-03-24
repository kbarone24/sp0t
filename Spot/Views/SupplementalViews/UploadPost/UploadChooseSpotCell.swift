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
import CoreLocation

class UploadChooseSpotCell: UITableViewCell {
    
    var loaded = false
    var loading = true
    
    var topLine: UIView!
    var titleLabel: UILabel!
    
    var newSpotView: UIView!
    var profilePic: UIImageView!
    var exitButton: UIButton!

    var spotScroll: UIScrollView!
    var collection0: UploadPillCollectionView!
    var collection1: UploadPillCollectionView!

    func setUp(newSpotName: String, selected: Bool, post: MapPost) {
        
        if newSpotName != "" || selected { return } /// no need to reload when cell collapsed
        
        backgroundColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        contentView.backgroundColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
                
        resetView()
        
        topLine = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
        topLine.backgroundColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        contentView.addSubview(topLine)
        
        titleLabel = UILabel(frame: CGRect(x: 16, y: 12, width: 150, height: 18))
        titleLabel.text = newSpotName == "" ? "Choose a spot" : "New spot"
        titleLabel.textColor = UIColor(red: 0.479, green: 0.479, blue: 0.479, alpha: 1)
        titleLabel.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
        contentView.addSubview(titleLabel)
                        
        spotScroll = UIScrollView(frame: CGRect(x: 0, y: 39, width: UIScreen.main.bounds.width, height: 70))
        spotScroll.backgroundColor = .clear
        spotScroll.showsHorizontalScrollIndicator = false
        contentView.addSubview(spotScroll)
        
        let layout0 = UICollectionViewFlowLayout()
        layout0.scrollDirection = .horizontal
        layout0.minimumInteritemSpacing = 6

        collection0 = UploadPillCollectionView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 32), collectionViewLayout: layout0)
        collection0.delegate = self
        collection0.dataSource = self
        spotScroll.addSubview(collection0)
        
        let layout1 = UICollectionViewFlowLayout()
        layout1.scrollDirection = .horizontal
        layout1.minimumInteritemSpacing = 6
        
        collection1 = UploadPillCollectionView(frame: CGRect(x: 0, y: collection0.frame.maxY + 6, width: UIScreen.main.bounds.width, height: 32), collectionViewLayout: layout1)
        collection1.delegate = self
        collection1.dataSource = self
        collection1.tag = 1
        spotScroll.addSubview(collection1)
    }
    
    func reloadCollections(animated: Bool, resort: Bool, coordinate: CLLocationCoordinate2D) {
        
        if collection0 == nil || collection1 == nil { return }
        
        DispatchQueue.main.async {
            
            if !animated {
                self.collection0.reloadData()
                self.collection1.reloadData()
                
            } else {
                self.loading = false
                
                if resort {
                    /// if not selecting, resort
                    if !UploadImageModel.shared.nearbySpots.isEmpty {
                        UploadImageModel.shared.resortSpots(coordinate: coordinate)
                    }
                }
                self.setScrollViewSize()
            }
        }
    }
    
    func setScrollViewSize() {
        var topWidth: CGFloat = 20 /// edge insets 13 px each side - 6 px for last space
        var bottomWidth: CGFloat = 20
        let cellCount = min(UploadImageModel.shared.nearbySpots.count + 2, 14)
        for i in 0...cellCount - 1 {
            let topRow = i % 2 == 0
            let index = i / 2
            let width = getSizeForCell(row: index, collectionTag: topRow ? 0 : 1).width
            if topRow { topWidth += 6 + width } else { bottomWidth += 6 + width }
        }
        let contentWidth = max(UIScreen.main.bounds.width, max(topWidth, bottomWidth))
        
        spotScroll.contentSize = CGSize(width: contentWidth, height: spotScroll.contentSize.height)
        collection0.frame = CGRect(x: collection0.frame.minX, y: collection0.frame.minY, width: topWidth, height: collection0.frame.height)
        collection1.frame = CGRect(x: collection1.frame.minX, y: collection1.frame.minY, width: bottomWidth, height: collection1.frame.height)
        collection0.reloadData()
        collection1.reloadData()
    }
    
    func resetView() {
        if topLine != nil { topLine.backgroundColor = nil }
        if titleLabel != nil { titleLabel.text = "" }
        if profilePic != nil { profilePic.image = UIImage(); profilePic.sd_cancelCurrentImageLoad() }
        if collection0 != nil { collection0.removeFromSuperview() }
        if collection1 != nil { collection1.removeFromSuperview() }
    }
    
    @objc func exitNewSpot(_ sender: UIButton) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        uploadVC.exitNewSpot()
    }
}

extension UploadChooseSpotCell: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        /// just show add new while loading
        return loading ? 1 : min((UploadImageModel.shared.nearbySpots.count + 2)/2, 7)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if indexPath.row == 0 {
            if collectionView.tag == 0 {
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Add", for: indexPath) as? ChooseSpotAddCell else { return UICollectionViewCell() }
                return cell
            } else {
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Search", for: indexPath) as? ChooseSpotSearchCell else { return UICollectionViewCell() }
                return cell
            }
        }

        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Collection", for: indexPath) as? ChooseSpotCollectionCell else { return UICollectionViewCell() }
        let index = indexPath.row * 2 - (collectionView.tag == 0 ? 2 : 1)
        guard let spot = UploadImageModel.shared.nearbySpots[safe: index] else { return cell }
        
        cell.setUp(spot: spot)
        if spot.selected! { alpha = 1.0 }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return getSizeForCell(row: indexPath.row, collectionTag: collectionView.tag)
    }
    
    func getSizeForCell(row: Int, collectionTag: Int) -> CGSize {
        
        if row == 0 { return collectionTag == 0 ? CGSize(width: 52, height: 32) : CGSize(width: 81, height: 32) }
        
        let index = row * 2 - (collectionTag == 0 ? 2 : 1)
        guard let spot = UploadImageModel.shared.nearbySpots[safe: index] else { return CGSize(width: 100, height: 32) }
        let cellWidth = getCellWidth(spot: spot)
        return CGSize(width: cellWidth, height: 32)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {

        return UIEdgeInsets(top: 0, left: 13, bottom: 0, right: 13)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }

        /// present screen to name the new spot
        if indexPath.row == 0 {
            if collectionView.tag == 0 {
                uploadVC.presentAddNew()
                return
            } else {
                Mixpanel.mainInstance().track(event: "UploadSeeAllLaunchMap", properties: nil)
                uploadVC.switchToChooseSpot()
                return
            }
        }
        
        /// select id, spot/poi, reload parent which will reload the cell -> this is kind of sloppy
        let index = indexPath.row * 2 - (collectionView.tag == 0 ? 2 : 1)
        guard let spot = UploadImageModel.shared.nearbySpots[safe: index] else { return }
        uploadVC.selectSpot(index: index, select: !spot.selected!, fromMap: false)
    }
    
    
    func getCellWidth(spot: MapSpot) -> CGFloat {
        
        let tempName = UILabel(frame: CGRect(x: 0, y: 0, width: 250, height: 20))
        tempName.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
    
        tempName.text = spot.spotName
        tempName.sizeToFit()

        return tempName.frame.width + 16
    }
}

class ChooseSpotAddCell: UICollectionViewCell {
    
    var newLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        backgroundColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        
        if newLabel != nil { newLabel.text = "" }
        
        newLabel = UILabel(frame: CGRect(x: 9, y: 8, width: 34, height: 16))
        newLabel.text = "NEW"
        newLabel.textColor = UIColor(named: "SpotGreen")
        newLabel.font = UIFont(name: "SFCompactText-Bold", size: 13)
        newLabel.textAlignment = .center
        addSubview(newLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ChooseSpotSearchCell: UICollectionViewCell {
    
    var searchLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        backgroundColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
                
        if searchLabel != nil { searchLabel.text = "" }
        
        searchLabel = UILabel(frame: CGRect(x: 9, y: 8, width: 63.5, height: 16))
        searchLabel.text = "SEARCH"
        searchLabel.textColor = UIColor(red: 0.421, green: 0.421, blue: 0.421, alpha: 1)
        searchLabel.font = UIFont(name: "SFCompactText-Bold", size: 13)
        searchLabel.textAlignment = .center
        addSubview(searchLabel)
    }
 
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

class ChooseSpotCollectionCell: UICollectionViewCell {
    
    var spotName: UILabel!
    var detailView: UILabel!
    var spot: MapSpot!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        backgroundColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp(spot: MapSpot) {
        
        self.spot = spot
        
        /// slide spot name down if no description
        let minY: CGFloat = 5
        if spotName != nil { spotName.text = "" }
        spotName = UILabel(frame: CGRect(x: 8, y: minY, width: self.bounds.width - 16, height: 20))
        spotName.text = spot.spotName
        spotName.textColor = UIColor(red: 0.567, green: 0.567, blue: 0.567, alpha: 1)
        spotName.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
        addSubview(spotName)
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
    
    override init(frame: CGRect, collectionViewLayout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: collectionViewLayout)
        backgroundColor = nil
        showsHorizontalScrollIndicator = false
        isScrollEnabled = false
        register(ChooseSpotCollectionCell.self, forCellWithReuseIdentifier: "Collection")
        register(ChooseSpotAddCell.self, forCellWithReuseIdentifier: "Add")
        register(ChooseSpotSearchCell.self, forCellWithReuseIdentifier: "Search")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



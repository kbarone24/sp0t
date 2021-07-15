//
//  SpotPostsViewController.swift
//  Spot
//
//  Created by Kenny Barone on 6/22/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import SDWebImage
import MapKit
import Mixpanel

class SpotPostsViewController: UIViewController {
    
    unowned var spotVC: SpotViewController!
    unowned var mapVC: MapViewController!
    weak var postVC: PostViewController!

    let postsCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout.init()
    
    override func viewDidLoad() {
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        
        layout.scrollDirection = .vertical
        let width = (UIScreen.main.bounds.width - 10.5) / 3
        let height = width * 1.374
        
        layout.itemSize = CGSize(width: width, height: height)
        layout.minimumInteritemSpacing = 5
        layout.minimumLineSpacing = 5
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        layout.headerReferenceSize = CGSize(width: UIScreen.main.bounds.width, height: 39)
        
        postsCollection.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        postsCollection.setCollectionViewLayout(layout, animated: false)
        postsCollection.delegate = self
        postsCollection.dataSource = self
        postsCollection.showsVerticalScrollIndicator = false
        postsCollection.backgroundColor = nil
        postsCollection.register(GuestbookCell.self, forCellWithReuseIdentifier: "GuestbookCell")
        postsCollection.register(TimestampHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "TimestampHeader")
        postsCollection.isScrollEnabled = false
        postsCollection.bounces = false
        view.addSubview(postsCollection)
        
        postsCollection.removeGestureRecognizer(postsCollection.panGestureRecognizer)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "SpotPostsOpen")
    }
    
    func resetView() {
        DispatchQueue.main.async { self.postsCollection.reloadData() }
    }
    
    func cancelDownloads() {
        for cell in postsCollection.visibleCells {
            guard let guestbookCell = cell as? GuestbookCell else { return }
            guestbookCell.imagePreview.sd_cancelCurrentImageLoad()
        }
    }
}

extension SpotPostsViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return spotVC.postDates.count
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "TimestampHeader", for: indexPath) as! TimestampHeader
        view.setUp(date: spotVC.postDates[indexPath.section].date)
        return view
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        var count = 0
        for preview in spotVC.guestbookPreviews {
            if preview.date == spotVC.postDates[section].date { count += 1 }
        }
        return count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GuestbookCell", for: indexPath) as? GuestbookCell else { return UICollectionViewCell() }
        
        /// break out guestbook previews  into subsets for each date
        var subset: [GuestbookPreview] = []
        for preview in spotVC.guestbookPreviews {
            if preview.date == spotVC.postDates[indexPath.section].date {
                subset.append(preview)
            }
        }

        if subset.count <= indexPath.row { return cell }
        cell.setUp(preview: subset[indexPath.row])
        return cell
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? GuestbookCell else { return }
        openPostPage(postID: cell.postID, imageIndex: cell.imageIndex)
    }
    
    func openPostPage(postID: String, imageIndex: Int) {
        if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(identifier: "Post") as? PostViewController {
            
            if self.mapVC.prePanY < 200 {
                if spotVC.shadowScroll.contentOffset.y == 0 { spotVC.shadowScroll.setContentOffset(CGPoint(x: 0, y: 1), animated: false)}
            }
            
            cancelDownloads()
            
            let index = spotVC.postsList.firstIndex(where: {$0.id == postID}) ?? 0
            vc.postsList = spotVC.postsList
            vc.postsList[index].selectedImageIndex = imageIndex
            vc.selectedPostIndex = index
            /// set frame index and go to that image
            
            mapVC.spotViewController = nil
            mapVC.hideSpotButtons()
            mapVC.toggleMapTouch(enable: true)
            
            vc.mapVC = mapVC
            vc.parentVC = .spot
            vc.spotObject = spotVC.spotObject
            
            if spotVC.addToSpotButton != nil { spotVC.addToSpotButton.isHidden = true }
            
            vc.view.frame = UIScreen.main.bounds
            spotVC.addChild(vc)
            spotVC.view.addSubview(vc.view)
            vc.didMove(toParent: spotVC)
            
            let infoPass = ["selectedPost": index, "firstOpen": true, "parentVC": PostViewController.parentViewController.spot] as [String : Any]
            NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: infoPass)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {

        guard let cell = cell as? GuestbookCell else { return }
        cell.imagePreview.image = UIImage()
        
        var subset: [GuestbookPreview] = []
        for preview in spotVC.guestbookPreviews {
            if preview.date == spotVC.postDates[indexPath.section].date {
                subset.append(preview)
            }
        }
        
        guard let preview = subset[safe: indexPath.row] else { return }
        
        let itemWidth = (UIScreen.main.bounds.width - 10.5) / 3
        let itemHeight = itemWidth * 1.374

        /// resize to aspect ratio * 2 + added padding for rounding errors
        let transformer = SDImageResizingTransformer(size: CGSize(width: itemWidth * 2, height: itemHeight * 2 + 5), scaleMode: .aspectFill)
        cell.imagePreview.sd_setImage(with: URL(string: preview.imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer], progress: nil)
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
        guard let cell = cell as? GuestbookCell else { return }
        cell.imagePreview.sd_cancelCurrentImageLoad()
    }

    
    
}

class GuestbookCell: UICollectionViewCell {
    
    var postID: String = ""
    var imageIndex = 0
    lazy var imagePreview = UIImageView()
        
    func setUp(preview: GuestbookPreview) {
        
        postID = preview.postID
        imageIndex = preview.imageIndex
        
        backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1.00)
        layer.cornerRadius = 3
        clipsToBounds = true
        
        imagePreview.frame = bounds
        imagePreview.contentMode = .scaleAspectFill
        imagePreview.clipsToBounds = true
        addSubview(imagePreview)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
}


class TimestampHeader: UICollectionReusableView {
    
    var dateLabel: UILabel!
    
    func setUp(date: String) {
        if dateLabel != nil { dateLabel.text = "" }
        dateLabel = UILabel(frame: CGRect(x: 9, y: 13.5, width: UIScreen.main.bounds.width - 28, height: 16))
        dateLabel.text = date
        dateLabel.font = UIFont(name: "SFCamera-Regular", size: 13)
        dateLabel.textColor = UIColor(red: 0.60, green: 0.60, blue: 0.60, alpha: 1.00)
        dateLabel.sizeToFit()
        addSubview(dateLabel)
    }
}

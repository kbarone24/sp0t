//
//  ReviewPublicController.swift
//  Spot
//
//  Created by Kenny Barone on 4/1/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import FirebaseUI

class ReviewPublicController: UIViewController {
    
    let db = Firestore.firestore()
    var pendingSpots: [MapSpot] = []
    var spotsTable: UITableView!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        headerView.backgroundColor = nil
        view.addSubview(headerView)
        
        let exitButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 56, y: 8, width: 44, height: 36))
        exitButton.imageEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        exitButton.setImage(UIImage(named: "CancelButton"), for: .normal)
        exitButton.addTarget(self, action: #selector(exit(_:)), for: .touchUpInside)
        headerView.addSubview(exitButton)

        spotsTable = UITableView(frame: CGRect(x: 0, y: 50, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        spotsTable.backgroundColor = UIColor(named: "SpotBlack")
        spotsTable.delegate = self
        spotsTable.dataSource = self
        spotsTable.isScrollEnabled = false
        spotsTable.backgroundColor = nil
        spotsTable.allowsSelection = false
        spotsTable.separatorStyle = .none
        spotsTable.register(NearbySpotCell.self, forCellReuseIdentifier: "NearbySpotCell")
        spotsTable.removeGestureRecognizer(spotsTable.panGestureRecognizer)
        view.addSubview(spotsTable)
        
        getSpots()
    }
    
    @objc func exit(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
    func getSpots() {
        
        db.collection("submissions").getDocuments { [weak self] (snap, err) in
            guard let self = self else { return }
            
            for doc in snap!.documents {

                self.db.collection("spots").document(doc.documentID).getDocument { [weak self] (postDoc, err) in
                    guard let self = self else { return }
                    
                    do {
                        
                        let postInfo = try postDoc?.data(as: MapSpot.self)
                        guard var info = postInfo else { return }
                        
                        info.id = postDoc!.documentID
                        let timestamp = postDoc!.get("checkInTime") as? Timestamp ?? Timestamp()
                        info.checkInTime = timestamp.seconds
                        self.pendingSpots.append(info)
                        self.spotsTable.reloadData()
                        
                    } catch {
                        print("catch", doc.documentID)
                        return
                    }
                }
            }
        }
    }
}

extension ReviewPublicController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pendingSpots.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "NearbySpotCell") as? NearbySpotCell else { return UITableViewCell() }
        cell.setUp(spot: pendingSpots[indexPath.row])
        cell.setUpPublicReview()
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 140
    }
}

class NearbySpotCell: UITableViewCell {
    
    var spotObject: MapSpot!
    
    var topLine: UIView!
    var spotImage: UIImageView!
    var friendCount: UILabel!
    var friendIcon: UIImageView!
    var spotName: UILabel!
    var spotDescription: UILabel!
    var locationIcon: UIImageView!
    var distanceLabel: UILabel!
    
    /// only used for public review
    var acceptButton: UIButton!
    var rejectButton: UIButton!
    
    func setUp(spot: MapSpot) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        contentView.isUserInteractionEnabled = false
        spotObject = spot
        
        resetCell()
        
        topLine = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
        topLine.backgroundColor = UIColor(red: 0.121, green: 0.121, blue: 0.121, alpha: 1)
        addSubview(topLine)
        
        spotImage = UIImageView(frame: CGRect(x: 14, y: 16, width: 66, height: 66))
        spotImage.layer.cornerRadius = 7.5
        spotImage.layer.masksToBounds = true
        spotImage.clipsToBounds = true
        spotImage.contentMode = .scaleAspectFill
        addSubview(spotImage)
        
        let url = spot.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            spotImage.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }
        
        if spot.friendVisitors > 0 {
            friendCount = UILabel(frame: CGRect(x: spotImage.frame.maxX + 10, y: 14, width: 30, height: 16))
            friendCount.text = String(spot.friendVisitors)
            friendCount.textColor = UIColor(named: "SpotGreen")
            friendCount.font = UIFont(name: "SFCompactText-Semibold", size: 13)
            friendCount.sizeToFit()
            addSubview(friendCount)
            
            friendIcon = UIImageView(frame: CGRect(x: friendCount.frame.maxX + 3, y: 17.5, width: 10.8, height: 9))
            friendIcon.image = UIImage(named: "FriendCountIcon")
            addSubview(friendIcon)
        }
        
        let nameY: CGFloat = spot.friendVisitors == 0 ? 24 : friendCount.frame.maxY + 2
            
        spotName = UILabel(frame: CGRect(x: spotImage.frame.maxX + 10, y: nameY, width: UIScreen.main.bounds.width - (spotImage.frame.maxX + 10) - 66, height: 16))
        spotName.text = spot.spotName
        spotName.font = UIFont(name: "SFCompactText-Semibold", size: 15)
        spotName.lineBreakMode = .byTruncatingTail
        spotName.textColor = UIColor(red: 0.946, green: 0.946, blue: 0.946, alpha: 1)
        addSubview(spotName)
        
        spotDescription = UILabel(frame: CGRect(x: spotImage.frame.maxX + 10, y: spotName.frame.maxY + 2, width: UIScreen.main.bounds.width - 103, height: 29))
        spotDescription.text = spot.spotDescription
        spotDescription.font = UIFont(name: "SFCompactText-Regular", size: 12.5)
        spotDescription.textColor = UIColor(red: 0.773, green: 0.773, blue: 0.773, alpha: 1)
        let descriptionHeight = getDescriptonHeight(spotDescription: spot.spotDescription)
        spotDescription.numberOfLines = descriptionHeight > 17 ? 2 : 1
        spotDescription.lineBreakMode = .byTruncatingTail
        spotDescription.sizeToFit()
        addSubview(spotDescription)
        
        /// adjust based on number of desription lines
        let adjustY: CGFloat = descriptionHeight > 17 ? 0 : descriptionHeight > 5 ? 4.5 : 9
        if adjustY > 0 {
            if friendCount != nil { friendCount.frame = CGRect(x: friendCount.frame.minX, y: friendCount.frame.minY + adjustY, width: friendCount.frame.width, height: friendCount.frame.height )}
            if friendIcon != nil { friendIcon.frame = CGRect(x: friendIcon.frame.minX, y: friendIcon.frame.minY + adjustY, width: friendIcon.frame.width, height: friendIcon.frame.height)}
            spotName.frame = CGRect(x: spotName.frame.minX, y: spotName.frame.minY + adjustY, width: spotName.frame.width, height: spotName.frame.height)
            spotDescription.frame = CGRect(x: spotDescription.frame.minX, y: spotDescription.frame.minY + adjustY, width: spotDescription.frame.width, height: spotDescription.frame.height)
        }
        
        distanceLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width - 45, y: 17, width: 70, height: 15))
        distanceLabel.text = spot.distance.getLocationString()
        distanceLabel.textColor = UIColor(red: 0.688, green: 0.688, blue: 0.688, alpha: 1)
        distanceLabel.font = UIFont(name: "SFCompactText-Regular", size: 10.5)
        distanceLabel.sizeToFit()
        distanceLabel.frame = CGRect(x: UIScreen.main.bounds.width - distanceLabel.frame.width - 10, y: 17, width: distanceLabel.frame.width, height: distanceLabel.frame.height)
        addSubview(distanceLabel)
        
        locationIcon = UIImageView(frame: CGRect(x: distanceLabel.frame.minX - 10, y: 18.5, width: 6, height: 8.5))
        locationIcon.image = UIImage(named: "DistanceIcon")
        self.addSubview(locationIcon)
    }
    
    func setUpPublicReview() {
        if acceptButton != nil { acceptButton.setTitle("", for: .normal) }
        if rejectButton != nil { rejectButton.setTitle("", for: .normal) }

        acceptButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 110, y: 100, width: 100, height: 25))
        acceptButton.setTitle("Accept", for: .normal)
        acceptButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        acceptButton.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 14)
        acceptButton.contentVerticalAlignment = .center
        acceptButton.contentHorizontalAlignment = .center
        acceptButton.addTarget(self, action: #selector(acceptPublicSpot(_:)), for: .touchUpInside)
        addSubview(acceptButton)
        
        rejectButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 + 10, y: 100, width: 100, height: 25))
        rejectButton.setTitle("Reject", for: .normal)
        rejectButton.setTitleColor(UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1), for: .normal)
        rejectButton.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 14)
        rejectButton.contentVerticalAlignment = .center
        rejectButton.contentHorizontalAlignment = .center
        rejectButton.addTarget(self, action: #selector(rejectPublicSpot(_:)), for: .touchUpInside)
        addSubview(rejectButton)
    }
    
    @objc func acceptPublicSpot(_ sender: UIButton) {
        sendAcceptPublicNotification(spot: spotObject)
        if let reviewPublic = viewContainingController() as? ReviewPublicController {
            reviewPublic.pendingSpots.removeAll(where: {$0.id == spotObject.id})
            reviewPublic.spotsTable.reloadData()
        }
    }
    
    @objc func rejectPublicSpot(_ sender: UIButton) {
        
      ///  sendRejectPublicNotification(spot: spotObject) -> don't really think this is even necessary
        let db = Firestore.firestore()
        db.collection("submissions").document(spotObject.id!).delete() /// deleting here now that not deleting from noti send
        
        if let reviewPublic = viewContainingController() as? ReviewPublicController {
            reviewPublic.pendingSpots.removeAll(where: {$0.id == spotObject.id})
            reviewPublic.spotsTable.reloadData()
        }
    }
    
    func getDescriptonHeight(spotDescription: String) -> CGFloat {
        let tempLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 103, height: 29))
        tempLabel.text = spotDescription
        tempLabel.font = UIFont(name: "SFCompactText-Regular", size: 12.5)
        tempLabel.numberOfLines = 0
        tempLabel.lineBreakMode = .byWordWrapping
        tempLabel.sizeToFit()
        return tempLabel.frame.height
    }
    
    func resetCell() {
        if topLine != nil { topLine.backgroundColor = nil }
        if spotImage != nil { spotImage.image = UIImage() }
        if friendCount != nil { friendCount.text = "" }
        if friendIcon != nil { friendIcon.image = UIImage() }
        if spotName != nil { spotName.text = "" }
        if spotDescription != nil { spotDescription.text = "" }
        if locationIcon != nil { locationIcon.image = UIImage() }
        if distanceLabel != nil { distanceLabel.text = "" }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if spotImage != nil { spotImage.sd_cancelCurrentImageLoad() }
    }
}


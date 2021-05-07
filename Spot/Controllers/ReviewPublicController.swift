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

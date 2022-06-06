//
//  ChooseSpotCell.swift
//  Spot
//
//  Created by Kenny Barone on 5/5/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation

class ChooseSpotCell: UITableViewCell {
    
    var topLine: UIView!
    var spotName: UILabel!
    var descriptionLabel: UILabel!
    
    var separatorView: UIView!
    var distanceLabel: UILabel!
    var friendsLabel: UILabel!
    
    var spotID = ""
    
    func setUp(spot: MapSpot) {
        
        backgroundColor = spot.selected! ? UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 0.4) : .white
        spotID = spot.id!
        
        resetCell()
                
        /// tag = 1 for nearbySpots, tag = 2 for querySpots
        spotName = UILabel(frame: CGRect(x: 20, y: 11, width: UIScreen.main.bounds.width - 78, height: 17))
        spotName.text = spot.spotName
        spotName.lineBreakMode = .byTruncatingTail
        spotName.font = UIFont(name: "SFCompactText-Semibold", size: 15.5)
        spotName.textColor = .black
        contentView.addSubview(spotName)
        
        var lineX: CGFloat = 20
        /// add spot description - either
        if spot.spotDescription != "" {
            descriptionLabel = UILabel(frame: CGRect(x: lineX, y: spotName.frame.maxY + 2, width: UIScreen.main.bounds.width - 78, height: 16))
            descriptionLabel.text = spot.spotDescription
            descriptionLabel.textColor = UIColor(red: 0.654, green: 0.654, blue: 0.654, alpha: 1)
            descriptionLabel.font = UIFont(name: "SFCompactText-Semibold", size: 13)
            descriptionLabel.lineBreakMode = .byTruncatingTail
            descriptionLabel.sizeToFit()
            contentView.addSubview(descriptionLabel)
            
            lineX = descriptionLabel.frame.maxX + 5
        }
        
        if spot.friendVisitors > 0 {
            /// if addedDescription, add separator
            if spot.spotDescription != "" {
                separatorView = UIView(frame: CGRect(x: lineX, y: descriptionLabel.frame.midY - 1, width: 3, height: 3))
                separatorView.backgroundColor = UIColor(red: 0.769, green: 0.769, blue: 0.769, alpha: 1)
                contentView.addSubview(separatorView)
                
                lineX += 8
            }
            
            friendsLabel = UILabel(frame: CGRect(x: lineX, y: spotName.frame.maxY + 2, width: 150, height: 17))
            friendsLabel.textColor = UIColor(red: 0.119, green: 0.771, blue: 0.732, alpha: 1)
            friendsLabel.font = UIFont(name: "SFCompactText-Bold", size: 13)
            
            var friendsText = "\(spot.friendVisitors) friend"
            if spot.friendVisitors > 1 { friendsText += "s" }
            friendsLabel.text = friendsText
            friendsLabel.sizeToFit()
            contentView.addSubview(friendsLabel)
        }
        
        /// slide spotName down if no description label
        if spot.friendVisitors == 0 && spot.spotDescription == "" { spotName.frame = CGRect(x: spotName.frame.minX, y: 19, width: spotName.frame.width, height: spotName.frame.height) }
        
        topLine = UIView(frame: CGRect(x: 0, y: 57, width: UIScreen.main.bounds.width, height: 1))
        topLine.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
        contentView.addSubview(topLine)

        /// add distance for nearby cell
        distanceLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width - 113.25, y: 21, width: 100, height: 15))
        distanceLabel.text = spot.distance.getLocationString()
        distanceLabel.textAlignment = .right
        distanceLabel.textColor = UIColor(red: 0.808, green: 0.808, blue: 0.808, alpha: 1)
        distanceLabel.font = UIFont(name: "SFCompactText-Semibold", size: 13)
        contentView.addSubview(distanceLabel)
    
        let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        contentView.addGestureRecognizer(tap)
    }
    
    @objc func tap(_ sender: UITapGestureRecognizer) {
        guard let infoVC = viewContainingController() as? PostInfoController else { return }
        infoVC.selectSpot(id: spotID)
    }
        
    func resetCell() {
        if topLine != nil { topLine.backgroundColor = nil }
        if spotName != nil { spotName.text = "" }
        if descriptionLabel != nil { descriptionLabel.text = "" }
        if friendsLabel != nil { friendsLabel.text = "" }
        if separatorView != nil { separatorView.backgroundColor = nil }
        if distanceLabel != nil { distanceLabel.text = "" }
    }
}


class ChooseSpotLoadingCell: UITableViewCell {
    
    var activityIndicator: CustomActivityIndicator!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp() {
    
        if activityIndicator != nil { activityIndicator.removeFromSuperview() }
        
        activityIndicator = CustomActivityIndicator(frame: CGRect(x: 15, y: 10, width: 30, height: 30))
        activityIndicator.startAnimating()
        self.addSubview(activityIndicator)
    }
}

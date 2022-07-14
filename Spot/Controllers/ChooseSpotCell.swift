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
    var postsLabel: UILabel!
    
    var spotID = ""
    
    func setUp(spot: MapSpot) {
        selectionStyle = .none
        backgroundColor = spot.selected! ? UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 0.4) : .white
        spotID = spot.id!
        
        resetCell()
                
        distanceLabel = UILabel {
            $0.frame = CGRect(x: UIScreen.main.bounds.width - 113.25, y: 21, width: 100, height: 15)
            $0.text = spot.distance.getLocationString()
            $0.textAlignment = .right
            $0.textColor = UIColor(red: 0.808, green: 0.808, blue: 0.808, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 13)
            $0.sizeToFit()
            contentView.addSubview($0)
        }
        distanceLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(13)
            $0.top.equalTo(21)
            $0.height.equalTo(15)
        }

        /// tag = 1 for nearbySpots, tag = 2 for querySpots
        spotName = UILabel {
            $0.text = spot.spotName
            $0.lineBreakMode = .byTruncatingTail
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 16)
            $0.textColor = .black
            contentView.addSubview($0)
        }
        spotName.snp.makeConstraints {
            $0.leading.equalTo(20)
            $0.top.equalTo(11)
            $0.trailing.equalTo(distanceLabel.snp.leading).offset(-5)
            $0.height.equalTo(17)
        }
        
        /// add spot description - either
        if spot.spotDescription != "" {
            descriptionLabel = UILabel {
                $0.text = spot.spotDescription
                $0.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
                $0.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
                $0.lineBreakMode = .byTruncatingTail
                $0.sizeToFit()
                contentView.addSubview($0)
            }
            descriptionLabel.snp.makeConstraints {
                $0.leading.equalTo(20)
                $0.top.equalTo(spotName.snp.bottom).offset(2)
              //  $0.trailing.equalTo(distanceLabel.snp.leading).offset(-5)
            }
        }
        
        if spot.postIDs.count > 0 {
            /// if addedDescription, add separator
            if spot.spotDescription != "" {
                separatorView = UIView {
                    $0.backgroundColor = UIColor(red: 0.839, green: 0.839, blue: 0.839, alpha: 1)
                    contentView.addSubview($0)
                }
                separatorView.snp.makeConstraints {
                    $0.leading.equalTo(descriptionLabel.snp.trailing).offset(5)
                    $0.top.equalTo(descriptionLabel.snp.centerY).offset(-1)
                    $0.width.height.equalTo(3)
                }
            }
            
            var postsText = "\(spot.postIDs.count) post"
            if spot.postIDs.count > 1 { postsText += "s" }
            postsLabel = UILabel {
                $0.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
                $0.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
                $0.text = postsText
                $0.sizeToFit()
                contentView.addSubview($0)
            }
            postsLabel.snp.makeConstraints {
                if spot.spotDescription == "" {
                    $0.leading.equalTo(20)
                } else {
                    $0.leading.equalTo(separatorView.snp.trailing).offset(5)
                }
                $0.top.equalTo(spotName.snp.bottom).offset(2)
                $0.width.equalTo(100)
            }
        }
        
        /// slide spotName down if no description label
        if spot.friendVisitors == 0 && spot.spotDescription == "" { spotName.frame = CGRect(x: spotName.frame.minX, y: 19, width: spotName.frame.width, height: spotName.frame.height) }
        
        topLine = UIView {
            $0.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            contentView.addSubview($0)
        }
        topLine.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(1)
        }
    }
    
    @objc func tap(_ sender: UITapGestureRecognizer) {
    }
        
    func resetCell() {
        if topLine != nil { topLine.removeFromSuperview() }
        if spotName != nil { spotName.removeFromSuperview() }
        if descriptionLabel != nil { descriptionLabel.removeFromSuperview() }
        if postsLabel != nil { postsLabel.removeFromSuperview() }
        if separatorView != nil { separatorView.removeFromSuperview() }
        if distanceLabel != nil { distanceLabel.removeFromSuperview() }
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
        
        activityIndicator = CustomActivityIndicator {
            $0.startAnimating()
            addSubview($0)
        }
        activityIndicator.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.top.equalTo(10)
            $0.width.height.equalTo(30)
        }
    }
}

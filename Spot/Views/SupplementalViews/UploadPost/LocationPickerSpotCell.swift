//
//  LocationPickerCell.swift
//  Spot
//
//  Created by Kenny Barone on 11/19/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation

class LocationPickerSpotCell: UITableViewCell {
    
    var topLine: UIView!
    var spotName: UILabel!
    var descriptionLabel: UILabel!
    
    var separatorView: UIView!
    var cityLabel: UILabel!
    var distanceLabel: UILabel!
    
    func setUp(spot: MapSpot) {
        
        self.backgroundColor = .black
        self.selectionStyle = .none
        
        resetCell()
                
        /// tag = 1 for nearbySpots, tag = 2 for querySpots
        let nameY: CGFloat = tag == 1 ? 17 : 11
        spotName = UILabel(frame: CGRect(x: 18, y: nameY, width: UIScreen.main.bounds.width - 78, height: 16))
        spotName.text = spot.spotName
        spotName.lineBreakMode = .byTruncatingTail
        spotName.font = UIFont(name: "SFCamera-Regular", size: 15)
        spotName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        contentView.addSubview(spotName)
        
        var separatorX: CGFloat = 18
        if spot.spotDescription != "" {
            descriptionLabel = UILabel(frame: CGRect(x: 18, y: spotName.frame.maxY + 2, width: UIScreen.main.bounds.width - 78, height: 16))
            descriptionLabel.text = spot.spotDescription
            descriptionLabel.textColor = UIColor(red: 0.363, green: 0.363, blue: 0.363, alpha: 1)
            descriptionLabel.font = UIFont(name: "SFCamera-Semibold", size: 12.5)
            descriptionLabel.lineBreakMode = .byTruncatingTail
            descriptionLabel.sizeToFit()
            contentView.addSubview(descriptionLabel)
            
            separatorX = descriptionLabel.frame.maxX + 4
            
        } else if tag == 1 {
            /// move spot name down for nearby cell only
            spotName.frame = CGRect(x: spotName.frame.minX, y: spotName.frame.minY + 8, width: spotName.frame.width, height: spotName.frame.height)
        }
        
        if tag == 2 {
            /// add city for search cell
            if separatorX != 18 {
                separatorView = UIView(frame: CGRect(x: separatorX, y: descriptionLabel.frame.midY - 1, width: 3, height: 3))
                separatorView.backgroundColor = UIColor(red: 0.363, green: 0.363, blue: 0.363, alpha: 1)
                separatorView.layer.cornerRadius = 1.5
                contentView.addSubview(separatorView)
                
                separatorX += 7
            }
            
            cityLabel = UILabel(frame: CGRect(x: separatorX, y: spotName.frame.maxY + 2, width: UIScreen.main.bounds.width - separatorX - 18, height: 16))
            cityLabel.text = spot.city ?? ""
            cityLabel.textColor = UIColor(red: 0.363, green: 0.363, blue: 0.363, alpha: 1)
            cityLabel.font = UIFont(name: "SFCamera-Semibold", size: 12.5)
            cityLabel.lineBreakMode = .byTruncatingTail
            contentView.addSubview(cityLabel)
            
            /// for POIs will need to fetch city here
            let localName = spot.spotName
            if cityLabel.text == "" {
                reverseGeocodeFromCoordinate(numberOfFields: 2, location: CLLocation(latitude: spot.spotLat, longitude: spot.spotLong)) { [weak self] city in
                    guard let self = self else { return }
                    if localName == spot.spotName { self.cityLabel.text = city }
                }
            }
            
        } else {
            
            topLine = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
            topLine.backgroundColor = UIColor(red: 0.062, green: 0.062, blue: 0.062, alpha: 1)
            contentView.addSubview(topLine)

            /// add distance for nearby cell
            distanceLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width - 63.25, y: 21, width: 50, height: 15))
            distanceLabel.text = spot.distance.getLocationString()
            distanceLabel.textAlignment = .right
            distanceLabel.textColor = UIColor(red: 0.262, green: 0.262, blue: 0.262, alpha: 1)
            distanceLabel.font = UIFont(name: "SFCamera-Semibold", size: 10.5)
            contentView.addSubview(distanceLabel)
        }
    }
        
    func resetCell() {
        if topLine != nil { topLine.backgroundColor = nil }
        if spotName != nil { spotName.text = "" }
        if descriptionLabel != nil { descriptionLabel.text = "" }
        if separatorView != nil { separatorView.backgroundColor = nil }
        if cityLabel != nil { cityLabel.text = "" }
        if distanceLabel != nil { distanceLabel.text = "" }
    }
}


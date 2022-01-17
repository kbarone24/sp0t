//
//  SpotSearchCell.swift
//  Spot
//
//  Created by Kenny Barone on 11/19/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import FirebaseUI
import MapKit

class SpotSearchCell: UITableViewCell {

    var thumbnailImage: UIImageView!
    var spotName: UILabel!
    var profilePic: UIImageView!
    var name: UILabel!
    var username: UILabel!
    var address: UILabel!
    var bottomLine: UIView!
    
    func setUp(spot: MapSpot) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        
        resetCell()
        
        thumbnailImage = UIImageView(frame: CGRect(x: 18, y: 7, width: 36, height: 36))
        thumbnailImage.layer.cornerRadius = 4
        thumbnailImage.layer.masksToBounds = true
        thumbnailImage.clipsToBounds = true
        thumbnailImage.contentMode = .scaleAspectFill
        addSubview(thumbnailImage)

        let url = spot.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            thumbnailImage.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        } else {
            /// adjust cell to look like POI cell
            thumbnailImage.image = UIImage(named: "POIIcon")
            thumbnailImage.frame = CGRect(x: 16, y: 5, width: 38, height: 38)
        }

        spotName = UILabel(frame: CGRect(x: thumbnailImage.frame.maxX + 12, y: 15, width: 250, height: 16))
        spotName.text = spot.spotName
        spotName.font = UIFont(name: "SFCompactText-Regular", size: 13)
        spotName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        spotName.sizeToFit()
        addSubview(spotName)
    }
    
    func setUp(POI: POI) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        
        resetCell()
        
        thumbnailImage = UIImageView(frame: CGRect(x: 16, y: 7, width: 38, height: 38))
        thumbnailImage.layer.cornerRadius = 4
        thumbnailImage.layer.masksToBounds = true
        thumbnailImage.clipsToBounds = true
        thumbnailImage.contentMode = .scaleAspectFill
        thumbnailImage.image = UIImage(named: "POIIcon")
        addSubview(thumbnailImage)

        spotName = UILabel(frame: CGRect(x: thumbnailImage.frame.maxX + 12, y: 9, width: UIScreen.main.bounds.width - 84, height: 16))
        spotName.lineBreakMode = .byTruncatingTail
        spotName.text = POI.name
        spotName.font = UIFont(name: "SFCompactText-Semibold", size: 13)
        spotName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        addSubview(spotName)

        address = UILabel(frame: CGRect(x: thumbnailImage.frame.maxX + 12, y: spotName.frame.maxY + 1, width: UIScreen.main.bounds.width - 84, height: 16))
        address.text = POI.address
        address.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        address.font = UIFont(name: "SFCompactText-Regular", size: 12)
        address.lineBreakMode = .byTruncatingTail
        addSubview(address)
    }
    
    
    func setUpSpot(spot: ResultSpot) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        
        resetCell()

        thumbnailImage = UIImageView(frame: CGRect(x: 18, y: 12, width: 36, height: 36))
        thumbnailImage.layer.cornerRadius = 4
        thumbnailImage.layer.masksToBounds = true
        thumbnailImage.clipsToBounds = true
        thumbnailImage.contentMode = .scaleAspectFill
        addSubview(thumbnailImage)
        
        let url = spot.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            thumbnailImage.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }

        
        spotName = UILabel(frame: CGRect(x: thumbnailImage.frame.maxX + 8, y: 22, width: 250, height: 16))
        spotName.text = spot.spotName
        spotName.font = UIFont(name: "SFCompactText-Regular", size: 13)
        spotName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        spotName.sizeToFit()
        addSubview(spotName)
    }
        
    func setUpUser(user: UserProfile) {

        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        
        resetCell()
        
        profilePic = UIImageView(frame: CGRect(x: 18, y: 12, width: 36, height: 36))
        profilePic.layer.cornerRadius = 18
        profilePic.clipsToBounds = true
        profilePic.layer.masksToBounds = true
        profilePic.contentMode = .scaleAspectFill
        addSubview(profilePic)

        let url = user.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }

        name = UILabel(frame: CGRect(x: profilePic.frame.maxX + 8, y: 12, width: 250, height: 20))
        name.text = user.name
        name.font = UIFont(name: "SFCompactText-Semibold", size: 13)
        name.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        name.sizeToFit()
        addSubview(name)
        
        username = UILabel(frame: CGRect(x: profilePic.frame.maxX + 8, y: name.frame.maxY + 1, width: 250, height: 20))
        username.text = user.username
        username.font = UIFont(name: "SFCompactText-Regular", size: 13)
        username.textColor = UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha: 1)
        username.sizeToFit()
        addSubview(username)
    }
    
    func setUpCity(cityName: String) {

        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        
        resetCell()
        
        spotName = UILabel(frame: CGRect(x: 28.5, y: 22, width: 250, height: 16))
        spotName.text = cityName
        spotName.font = UIFont(name: "SFCompactText-Semibold", size: 15)
        spotName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        spotName.sizeToFit()
        addSubview(spotName)
        
        bottomLine = UIView(frame: CGRect(x: 14, y: 64, width: UIScreen.main.bounds.width - 28, height: 1))
        bottomLine.backgroundColor = UIColor(red: 0.121, green: 0.121, blue: 0.121, alpha: 1)
        addSubview(bottomLine)
    }
    
    func resetCell() {
        if thumbnailImage != nil { thumbnailImage.image = UIImage() }
        if spotName != nil {spotName.text = ""}
        if profilePic != nil {profilePic.image = UIImage()}
        if name != nil {name.text = ""}
        if username != nil {username.text = ""}
        if address != nil { address.text = "" }
        if bottomLine != nil { bottomLine.backgroundColor = nil }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if thumbnailImage != nil { thumbnailImage.sd_cancelCurrentImageLoad(); thumbnailImage.image = UIImage() }
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
    }
}

extension MKPointOfInterestCategory {
    
    func toString() -> String {
        
        /// convert POI type into readable string
        var text = rawValue
        var counter = 13
        while counter > 0 { text = String(text.dropFirst()); counter -= 1 }
        
        /// insert space in POI type if necessary
        counter = 0
        var uppercaseIndex = 0
        for letter in text {if letter.isUppercase && counter != 0 { uppercaseIndex = counter }; counter += 1}
        if uppercaseIndex != 0 { text.insert(" ", at: text.index(text.startIndex, offsetBy: uppercaseIndex)) }

        return text
    }
}


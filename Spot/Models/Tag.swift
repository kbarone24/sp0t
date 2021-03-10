//
//  Tag.swift
//  Spot
//
//  Created by kbarone on 1/8/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class Tag {
    
    var name: String
    var image: UIImage
    var selected: Bool
    var spotCount: Int
    
    init(name: String) {
        self.name = name
        selected = false
        spotCount = 0
        
        image = UIImage()
        image = getImage(name: name)
    }
    
    func getImage(name: String) -> UIImage {
        
        var tagImage = UIImage()
        
        switch name {
        
        case "Active":
            tagImage = UIImage(named: "ActiveTag")!
            
        case "Art":
            tagImage = UIImage(named: "ArtTag")!
            
        case "Chill":
            tagImage = UIImage(named: "ChillTag")!
            
        case "Coffee":
            tagImage = UIImage(named: "CoffeeTag")!
            
        case "Drink":
            tagImage = UIImage(named: "DrinkTag")!
            
        case "Food":
            tagImage = UIImage(named: "FoodTag")!
            
        case "History":
            tagImage = UIImage(named: "HistoryTag")!
            
        case "Nature":
            tagImage = UIImage(named: "NatureTag")!
            
        case "Shop":
            tagImage = UIImage(named: "ShopTag")!
            
        case "Stay":
            tagImage = UIImage(named: "StayTag")!
            
        case "Sunset":
            tagImage = UIImage(named: "SunsetTag")!
            
        case "Weird":
            tagImage = UIImage(named: "WeirdTag")!
            
        default:
            tagImage = UIImage()
            
        }
        
        return tagImage
    }
}

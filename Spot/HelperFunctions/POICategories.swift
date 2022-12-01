//
//  POICategories.swift
//  Spot
//
//  Created by Kenny Barone on 11/23/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation

enum POICategory: String {
    case Airport
    case AmusementPark
    case Aquarium
    case Bakery
    case Beach
    case Brewery
    case Cafe
    case Campground
    case FoodMarket
    case Library
    case Marina
    case Museum
    case MovieTheater
    case Nightlife
    case NationalPark
    case Park
    case Restaurant
    case Store
    case School
    case Stadium
    case Theater
    case University
    case Winery
    case Zoo
}

class POIImageFetcher {
    func getPOIImage(category: POICategory) -> UIImage {
        return UIImage(named: "\(category.rawValue)Tag") ?? UIImage()
    }
}

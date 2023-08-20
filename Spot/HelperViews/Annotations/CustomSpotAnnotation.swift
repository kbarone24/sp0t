//
//  CustomSpotAnnotation.swift
//  Spot
//
//  Created by Kenny Barone on 1/17/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import MapKit

class CustomSpotAnnotation: MKPointAnnotation {

    var spotInfo: MapSpot!
    var rank: CGFloat = 0
    var isHidden = true

    override init() {
        super.init()
    }
}

class SpotClusterAnnotation: MKClusterAnnotation {
    //  var topSpot: ((MapSpot, Int))!
    override init(memberAnnotations: [MKAnnotation]) {
        super.init(memberAnnotations: memberAnnotations)
    }
}

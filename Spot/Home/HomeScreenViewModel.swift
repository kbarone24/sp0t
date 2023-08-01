//
//  HomeScreenViewModel.swift
//  Spot
//
//  Created by Kenny Barone on 7/6/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase
import FirebaseStorage
import CoreLocation
import Combine

class HomeScreenViewModel {
    let postService: MapPostServiceProtocol
    let spotService: SpotServiceProtocol
    let locationService: LocationServiceProtocol

    init(serviceContainer: ServiceContainer) {
        guard let postService = try? serviceContainer.service(for: \.mapPostService),
              let spotService = try? serviceContainer.service(for: \.spotService),
              let locationService = try? serviceContainer.service(for: \.locationService)
        else {
            let imageVideoService = ImageVideoService(fireStore: Firestore.firestore(), storage: Storage.storage())
            self.postService = MapPostService(fireStore: Firestore.firestore(), imageVideoService: imageVideoService)
            self.spotService = SpotService(fireStore: Firestore.firestore())
            self.locationService = LocationService(locationManager: CLLocationManager())
            return
        }
        self.postService = postService
        self.spotService = spotService
        self.locationService = locationService
    }
}

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
import IdentifiedCollections

class HomeScreenViewModel {
    typealias Section = HomeScreenController.Section
    typealias Item = HomeScreenController.Item
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

    struct Input {
        let refresh: PassthroughSubject<Bool, Never>
    }

    struct Output {
        let snapshot: AnyPublisher<Snapshot, Never>
    }

    let postService: MapPostServiceProtocol
    let spotService: SpotServiceProtocol
    let locationService: LocationServiceProtocol

    var cachedTopSpots: IdentifiedArrayOf<MapSpot> = []
    var cachedNearbySpots: IdentifiedArrayOf<MapSpot> = []

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

    func bind(to input: Input) -> Output {
        let request = input.refresh
            .receive(on: DispatchQueue.global(qos: .background))
            .flatMap { [unowned self] refresh in
                (self.fetchSpots(refresh: refresh))
            }
            .map { $0 }

        let snapshot = request
            .receive(on: DispatchQueue.main)
            .map { topSpots, nearbySpots in

                var snapshot = Snapshot()
                let topTitle = "🔥hot rn"
                let nearbyTitle = "📍nearby"

                snapshot.appendSections([.top(title: topTitle), .nearby(title: nearbyTitle)])

                _ = topSpots.map {
                    snapshot.appendItems([.item(spot: $0)], toSection: .top(title: topTitle))
                }

                _ = nearbySpots.map {
                    snapshot.appendItems([.item(spot: $0)], toSection: .nearby(title: nearbyTitle))
                }
                return snapshot
            }
            .eraseToAnyPublisher()
        return Output(snapshot: snapshot)
    }

    private func fetchSpots(
        refresh: Bool
    ) -> AnyPublisher<([MapSpot], [MapSpot]), Never> {
        Deferred {
            Future { [weak self] promise in
                guard let self else {
                    promise(.success(([], [])))
                    return
                }

                guard refresh else {
                    promise(.success((self.cachedTopSpots.elements, self.cachedNearbySpots.elements)))
                    return
                }

                Task {
                    print("fetch spots")
                    // 1. fetch top spots for city
                    let topSpots = try? await self.spotService.fetchTopSpots(searchLimit: 50, returnLimit: 1)

                    // 2. fetch nearby spots
                    let nearbySpots = try? await self.spotService.runNearbySpotsFetch(radius: nil)
                    promise(.success((topSpots ?? [], nearbySpots ?? [])))

                    self.cachedTopSpots = IdentifiedArrayOf(uniqueElements: topSpots ?? [])
                    self.cachedNearbySpots = IdentifiedArrayOf(uniqueElements: nearbySpots ?? [])
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func setSeenLocally(spot: MapSpot) {
        guard let id = spot.id, !id.isEmpty else {
            return
        }
        // set seen and add to visitor list if user is in range
        if self.cachedNearbySpots[id: id] != nil {
            self.cachedNearbySpots[id: id]?.seenList?.append(UserDataModel.shared.uid)
            if spot.userInRange() {
                self.cachedNearbySpots[id: id]?.visitorList.append(UserDataModel.shared.uid)
            }
        }

        if self.cachedTopSpots[id: id] != nil {
            self.cachedTopSpots[id: id]?.seenList?.append(UserDataModel.shared.uid)
            if spot.userInRange() {
                self.cachedTopSpots[id: id]?.visitorList.append(UserDataModel.shared.uid)
            }
        }
    }
}

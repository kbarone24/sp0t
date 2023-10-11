//
//  ChooseSpotDataSource.swift
//  Spot
//
//  Created by Kenny Barone on 10/2/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import Combine
import Firebase
import CoreLocation

class ChooseSpotViewModel {
    typealias Section = ChooseSpotController.Section
    typealias Item = ChooseSpotController.Item
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

    struct Input {
        let refresh: PassthroughSubject<Bool, Never>
    }

    struct Output {
        let snapshot: AnyPublisher<Snapshot, Never>
    }

    let spotService: SpotServiceProtocol
    let userLocation: CLLocationCoordinate2D

    init(serviceContainer: ServiceContainer, userLocation: CLLocationCoordinate2D) {
        self.userLocation = userLocation
        guard let spotService = try? serviceContainer.service(for: \.spotService) else {
            self.spotService = SpotService(fireStore: Firestore.firestore())
            return
        }
        self.spotService = spotService
    }

    func bind(to input: Input) -> Output {
        let request = input.refresh
            .receive(on: DispatchQueue.global())
            .flatMap { [unowned self] refresh in
                (self.fetchSpots(refresh: refresh))
            }
            .map { $0 }

        let snapshot = request
            .receive(on: DispatchQueue.main)
            .map { spots in
                var snapshot = Snapshot()
                snapshot.appendSections([.main])
                _ = spots.map {
                    snapshot.appendItems([.item(spot: $0)], toSection: .main)
                }
                return snapshot
            }
            .eraseToAnyPublisher()
        return Output(snapshot: snapshot)
    }

    private func fetchSpots(
        refresh: Bool
    ) -> AnyPublisher<([Spot]), Never> {
        Deferred {
            Future { [weak self] promise in
                guard let self else {
                    promise(.success([]))
                    return
                }

                Task {
                    let spots = try? await self.spotService.fetchNearbySpots(for: self.userLocation, radius: nil).removingDuplicates()
                    promise(.success(spots ?? []))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

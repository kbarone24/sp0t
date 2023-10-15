//
//  ChooseMapViewModel.swift
//  Spot
//
//  Created by Kenny Barone on 10/3/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase
import Combine
import IdentifiedCollections

class ChooseMapViewModel {
    typealias Section = ChooseMapController.Section
    typealias Item = ChooseMapController.Item
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

    struct Input {
        let refresh: PassthroughSubject<Bool, Never>
    }

    struct Output {
        let snapshot: AnyPublisher<Snapshot, Never>
    }

    let mapService: MapServiceProtocol

    init(serviceContainer: ServiceContainer) {
        guard let mapService = try? serviceContainer.service(for: \.mapService) else {
            self.mapService = MapService(fireStore: Firestore.firestore())
            return
        }
        self.mapService = mapService
    }

    func bind(to input: Input) -> Output {
        let request = input.refresh
            .receive(on: DispatchQueue.global())
            .flatMap { [unowned self] refresh in
                (self.fetchMaps(refresh: refresh))
            }
            .map { $0 }

        let snapshot = request
            .receive(on: DispatchQueue.main)
            .map { spots in
                var snapshot = Snapshot()
                snapshot.appendSections([.main])
                snapshot.appendItems([.new])
                _ = spots.map {
                    snapshot.appendItems([.custom(map: $0)], toSection: .main)
                }
                return snapshot
            }
            .eraseToAnyPublisher()
        return Output(snapshot: snapshot)
    }

    private func fetchMaps(
        refresh: Bool
    ) -> AnyPublisher<([CustomMap]), Never> {
        Deferred {
            Future { [weak self] promise in
                guard let self else {
                    promise(.success([]))
                    return
                }

                Task {
                    let maps = try? await self.mapService.getUserMaps().removingDuplicates()
                    promise(.success(maps ?? []))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

//
//  ExploreMapViewModel.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Combine
import Firebase
import Foundation

final class ExploreMapViewModel {
    typealias Section = ExploreMapViewController.Section
    typealias Item = ExploreMapViewController.Item
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

    struct TitleData {
        let title: String
        let description: String
    }

    struct Input {
        let refresh: PassthroughSubject<Void, Never>
    }

    private let service: MapServiceProtocol
    @Published private(set) var snapshot = Snapshot()
    @Published private(set) var titleData = TitleData(title: "", description: "")
    @Published private(set) var isLoading = true
    private var subscriptions = Set<AnyCancellable>()

    init(serviceContainer: ServiceContainer) {
        guard let mapService = try? serviceContainer.service(for: \.mapsService) else {
            service = MapService(fireStore: Firestore.firestore())
            return
        }

        service = mapService
    }

    deinit {
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
    }

    func bind(to input: Input) {
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()

        let request = input.refresh
            .flatMap { [unowned self] in
                self.fetchMaps()
            }
            .map { $0 }
            .share()

        request
            .receive(on: DispatchQueue.global(qos: .background))
            .sink { [weak self] titleData, customMapData in
                guard let self else { return }
                
                var snapshot = Snapshot()
                snapshot.appendSections([.body])
                customMapData.forEach {
                    snapshot.appendItems([.item(data: $0)], toSection: .body)
                }
                
                self.snapshot = snapshot
                self.titleData = titleData
                self.isLoading = false
            }
            .store(in: &subscriptions)
    }

    private func fetchMaps() -> AnyPublisher<(TitleData, [CustomMap]), Never> {
        Deferred {
            Future { [weak self] promise in
                guard let self else {
                    return
                }
                // TODO: This will be fetched from the service eventually
                let titleData = TitleData(
                    title: "UNC Maps",
                    description: "Join community maps created by fellow Tarheels"
                )
                
                self.isLoading = true

                Task {
                    do {
                        let customMaps = try await self.service.fetchMaps()
                        promise(.success((titleData, customMaps)))
                    } catch {
                        print(error.localizedDescription)
                        promise(.success((titleData, [])))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

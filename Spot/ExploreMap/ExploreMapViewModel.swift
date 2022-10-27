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
        let refresh: PassthroughSubject<Bool, Never>
    }

    private let service: MapServiceProtocol
    @Published private(set) var snapshot = Snapshot()
    @Published private(set) var titleData = TitleData(title: "", description: "")
    @Published private(set) var isLoading = true
    @Published private(set) var selectedIds: [String] = []
    
    private var cachedMaps: [CustomMap] = []
    private var cachedTitleData = TitleData(title: "", description: "")
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
            .flatMap { [unowned self] forced in
                self.fetchMaps(forced: forced)
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
                    let isSelected = self.selectedIds.contains($0.id ?? "")
                    snapshot.appendItems([.item(data: $0, isSelected: isSelected)], toSection: .body)
                }
                
                self.titleData = titleData
                self.isLoading = false
                self.snapshot = snapshot
            }
            .store(in: &subscriptions)
    }
    
    func selectMap(with id: String) {
        if selectedIds.contains(id) {
            selectedIds.removeAll(where: { $0 == id })
        } else {
            selectedIds.append(id)
        }
    }
    
    func joinMap() {
        // TODO: function to join map
    }

    private func fetchMaps(forced: Bool) -> AnyPublisher<(TitleData, [CustomMap]), Never> {
        Deferred {
            Future { [weak self] promise in
                guard let self else {
                    return
                }
                
                guard forced else {
                    promise(.success((self.cachedTitleData, self.cachedMaps)))
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
                        self.cachedMaps = customMaps
                        self.cachedTitleData = titleData
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

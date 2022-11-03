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
import Mixpanel

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
    @Published private(set) var selectedMaps: [CustomMap] = []
    
    private var cachedMaps: [CustomMap: [MapPost]] = [:]
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
                customMapData.forEach { data in
                    let isSelected = self.selectedMaps.contains(data.key)
                    snapshot.appendItems([.item(customMap: data.key, data: data.value, isSelected: isSelected)], toSection: .body)
                }
                
                self.titleData = titleData
                self.isLoading = false
                self.snapshot = snapshot
            }
            .store(in: &subscriptions)
    }
    
    func selectMap(with customMap: CustomMap) {
        if selectedMaps.contains(customMap) {
            selectedMaps.removeAll(where: { $0 == customMap })
            Mixpanel.mainInstance().track(event: "ExploreMapsToggleMap", properties: ["selected": false])
        } else {
            selectedMaps.append(customMap)
            Mixpanel.mainInstance().track(event: "ExploreMapsToggleMap", properties: ["selected": true])
        }
    }
    
    func joinMap(completion: @escaping (() -> Void)) {
        Mixpanel.mainInstance().track(event: "ExploreMapsJoinTap", properties: ["mapCount": selectedMaps.count])
        
        for map in selectedMaps {
            service.joinMap(customMap: map) { [weak self] _ in
                if map == self?.selectedMaps.last {
                    self?.selectedMaps.removeAll()
                    completion()
                }
            }
        }
    }

    private func fetchMaps(forced: Bool) -> AnyPublisher<(TitleData, [CustomMap: [MapPost]]), Never> {
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
                        var mapData: [CustomMap: [MapPost]] = [:]
                        let customMaps = try await self.service.fetchMaps()
                        
                        for map in customMaps {
                            guard let id = map.id else { return }
                            mapData[map] = try await self.service.fetchMapPosts(id: id, limit: 7)
                        }
                        
                        self.cachedMaps = mapData
                        self.cachedTitleData = titleData
                        promise(.success((titleData, mapData)))
                    } catch {
                        print(error.localizedDescription)
                        promise(.success((titleData, [:])))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

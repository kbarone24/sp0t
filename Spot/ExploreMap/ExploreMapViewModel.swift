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
    
    enum OpenedFrom: Hashable {
        case mapController
        case onBoarding
    }
    
    enum JoinButtonType: Hashable {
        case joinedText
        case checkmark
    }
    
    struct TitleData: Hashable {
        let title: String
        let description: String
    }
    
    struct Input {
        let refresh: PassthroughSubject<Bool, Never>
        let loading: PassthroughSubject<Bool, Never>
        let selectMap: PassthroughSubject<CustomMap?, Never>
    }
    
    struct Output {
        let snapshot: AnyPublisher<Snapshot, Never>
        let isLoading: AnyPublisher<Bool, Never>
        let selectedMaps: AnyPublisher<[CustomMap], Never>
        let joinButtonIsHidden: AnyPublisher<Bool, Never>
    }
    
    private let service: MapServiceProtocol
    private let openedFrom: OpenedFrom
    
    private let selectMapPassthroughSubject = PassthroughSubject<CustomMap?, Never>()
    
    private var selectedMaps: [CustomMap] = []
    private var cachedMaps: [CustomMap: [MapPost]] = [:]
    private var cachedTitleData = TitleData(title: "", description: "")
    
    init(serviceContainer: ServiceContainer, from: OpenedFrom) {
        guard let mapService = try? serviceContainer.service(for: \.mapsService) else {
            service = MapService(fireStore: Firestore.firestore())
            openedFrom = .onBoarding
            return
        }
        
        service = mapService
        openedFrom = from
    }
    
    func bind(to input: Input) -> Output {
        
        let request = input.refresh
            .receive(on: DispatchQueue.global(qos: .background))
            .flatMap { [unowned self] forced in
                (self.fetchMaps(forced: forced))
            }
            .map { $0 }
        
        let snapshot = request
            .receive(on: DispatchQueue.global(qos: .background))
            .map { [weak self] title, customMapData, refreshed -> Snapshot in
                guard let self else {
                    return Snapshot()
                }
                
                var snapshot = Snapshot()
                snapshot.appendSections([.body(title: title)])
                let mainCampusMaps: [CustomMap]
                
                let buttonType: JoinButtonType
                switch self.openedFrom {
                case .mapController:
                    buttonType = .joinedText
                    mainCampusMaps = []
                    self.selectMapPassthroughSubject.send(nil)
                    
                case .onBoarding:
                    buttonType = .checkmark
                    mainCampusMaps = customMapData.keys.filter { $0.mainCampusMap == true }
                    mainCampusMaps.forEach { map in
                        if let mapData = customMapData[map] {
                            let isSelected = refreshed || self.selectedMaps.contains(map)
                            snapshot.appendItems([.item(customMap: map, data: mapData, isSelected: isSelected, buttonType: buttonType)], toSection: .body(title: title))
                        }
                        
                        if refreshed {
                            self.selectMapPassthroughSubject.send(map)
                        }
                    }
                }
                
                customMapData
                    .filter { data in
                        return !mainCampusMaps.contains(where: { $0.id == data.key.id })
                    }
                    .sorted {
                        $0.key.mapName.lowercased() < $1.key.mapName.lowercased()
                    }
                    .forEach { data in
                        let isSelected: Bool
                        
                        switch self.openedFrom {
                        case .onBoarding:
                            isSelected = self.selectedMaps.contains(data.key)
                            
                        case .mapController:
                            isSelected = data.key.memberIDs.contains(UserDataModel.shared.uid)
                        }
                        
                        snapshot.appendItems([.item(customMap: data.key, data: data.value, isSelected: isSelected, buttonType: buttonType)], toSection: .body(title: title))
                    }
                
                return snapshot
            }
            .eraseToAnyPublisher()
        
        let isLoading = input.loading
            .receive(on: DispatchQueue.global(qos: .background))
            .eraseToAnyPublisher()
        
        let selectedMaps = Publishers.CombineLatest(
            input.selectMap,
            selectMapPassthroughSubject.removeDuplicates()
        )
            .receive(on: DispatchQueue.global(qos: .background))
            .map { [weak self] inputCustomMap, selectedMapPassedThrough -> [CustomMap] in
                guard let self else { return [] }
                guard let inputCustomMap else {
                    if let selectedMapPassedThrough {
                        self.selectedMaps.append(selectedMapPassedThrough)
                    }
                    return self.selectedMaps
                }
                
                if let selectedMapPassedThrough {
                    if self.selectedMaps.contains(inputCustomMap) {
                        self.selectedMaps.removeAll(where: { $0 == inputCustomMap })
                        Mixpanel.mainInstance().track(event: "ExploreMapsToggleMap", properties: ["selected": false])
                        
                    } else if self.selectedMaps.contains(selectedMapPassedThrough) {
                        if inputCustomMap == selectedMapPassedThrough {
                            self.selectedMaps.removeAll(where: { $0 == selectedMapPassedThrough })
                            Mixpanel.mainInstance().track(event: "ExploreMapsToggleMap", properties: ["selected": false])
                        } else {
                            self.selectedMaps.append(inputCustomMap)
                            Mixpanel.mainInstance().track(event: "ExploreMapsToggleMap", properties: ["selected": true])
                        }
                        
                    } else {
                        self.selectedMaps.append(inputCustomMap)
                        Mixpanel.mainInstance().track(event: "ExploreMapsToggleMap", properties: ["selected": true])
                    }
                } else {
                    if self.selectedMaps.contains(inputCustomMap) {
                        self.selectedMaps.removeAll(where: { $0 == inputCustomMap })
                        Mixpanel.mainInstance().track(event: "ExploreMapsToggleMap", properties: ["selected": false])
                        
                    } else {
                        self.selectedMaps.append(inputCustomMap)
                        Mixpanel.mainInstance().track(event: "ExploreMapsToggleMap", properties: ["selected": true])
                    }
                }
                
                return self.selectedMaps
            }
            .eraseToAnyPublisher()
        
        let joinButtonIsHidden = input.refresh
            .receive(on: DispatchQueue.global(qos: .background))
            .map { [weak self] _ -> Bool in
                guard let self else { return true }
                switch self.openedFrom {
                case .mapController:
                    return true
                case .onBoarding:
                    return false
                }
            }
            .eraseToAnyPublisher()
        
        return Output(
            snapshot: snapshot,
            isLoading: isLoading,
            selectedMaps: selectedMaps,
            joinButtonIsHidden: joinButtonIsHidden
        )
    }
    
    func joinAllSelectedMaps(completion: @escaping (() -> Void)) {
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
    
    func joinMap(map: CustomMap, completion: @escaping ((Bool) -> Void)) {
        if selectedMaps.contains(where: { $0 == map }) || map.memberIDs.contains(UserDataModel.shared.uid) {
            service.leaveMap(customMap: map) { [weak self] error in
                if error == nil {
                    self?.selectedMaps.removeAll(where: { $0 == map })
                    UserDataModel.shared.userInfo.mapsList.removeAll(where: { $0.id == map.id })
                    completion(true)
                } else {
                    completion(false)
                }
            }
            Mixpanel.mainInstance().track(event: "ExploreMapsLeftMap", properties: [:])
            
        } else {
            service.joinMap(customMap: map) { [weak self] error in
                if error == nil {
                    self?.selectedMaps.append(map)
                    completion(true)
                } else {
                    completion(false)
                }
            }
            Mixpanel.mainInstance().track(event: "ExploreMapsJoinTap", properties: ["mapCount": 1])
        }
    }
    
    private func fetchMaps(forced: Bool) -> AnyPublisher<(TitleData, [CustomMap: [MapPost]], Bool), Never> {
        Deferred {
            Future { [weak self] promise in
                guard let self else {
                    return
                }
                
                guard forced else {
                    promise(.success((self.cachedTitleData, self.cachedMaps, forced)))
                    return
                }
                
                // TODO: This will be fetched from the service eventually
                let titleData = TitleData(
                    title: "UNC Maps",
                    description: "Join community maps created by fellow Tarheels"
                )
                
                Task {
                    do {
                        var mapData: [CustomMap: [MapPost]] = [:]
                        let allMaps = try await self.service.fetchMaps()
                        
                        for map in allMaps {
                            guard let id = map.id else { return }
                            mapData[map] = try await self.service.fetchMapPosts(id: id, limit: 7)
                        }
                        
                        self.cachedMaps = mapData
                        self.cachedTitleData = titleData
                        promise(.success((titleData, mapData, forced)))
                    } catch {
                        print(error.localizedDescription)
                        promise(.success((titleData, [:], forced)))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

//
//  ExploreMapViewModel.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Combine
import Firebase
import FirebaseFirestore
import FirebaseStorage
import Mixpanel

final class ExploreMapViewModel {
    typealias Section = ExploreMapViewController.Section
    typealias Item = ExploreMapViewController.Item
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

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
    }
    
    let mapService: MapServiceProtocol
    let postService: MapPostServiceProtocol
    private let selectMapPassthroughSubject = PassthroughSubject<CustomMap?, Never>()
    
    var cachedMaps: [CustomMap: [MapPost]] = [:]
    private var cachedTitleData = TitleData(title: "", description: "")
    private var cachedOffsets: [AnyHashable: CGPoint] = [:]
    
    init(serviceContainer: ServiceContainer) {
        guard let mapService = try? serviceContainer.service(for: \.mapsService),
        let postService = try? serviceContainer.service(for: \.mapPostService)
        else {
            self.mapService = MapService(fireStore: Firestore.firestore())
            let imageVideoService = ImageVideoService(fireStore: Firestore.firestore(), storage: Storage.storage())
            self.postService = MapPostService(fireStore: Firestore.firestore(), imageVideoService: imageVideoService)
            return
        }
        self.mapService = mapService
        self.postService = postService
    }
    
    func bind(to input: Input) -> Output {
        let request = input.refresh
            .receive(on: DispatchQueue.global())
            .flatMap { [unowned self] forced in
                (self.fetchMaps(forced: forced))
            }
            .map { $0 }

        let snapshot = request
            .receive(on: DispatchQueue.global())
            .map { [weak self] title, customMapData, _ -> Snapshot in
                guard let self else {
                    return Snapshot()
                }

                var snapshot = Snapshot()
                snapshot.appendSections([.body(title: title)])
                self.selectMapPassthroughSubject.send(nil)
                customMapData
                    .sorted {
                        $0.key.adjustedMapScore > $1.key.adjustedMapScore
                    }
                    .forEach { data in
                        let isSelected: Bool
                        let offset: CGPoint = self.cachedOffsets[data.key] ?? .zero
                        isSelected = data.key.likers.contains(UserDataModel.shared.uid)
                        snapshot.appendItems(
                            [.item(
                                customMap: data.key,
                                data: data.value,
                                isSelected: isSelected,
                                offsetBy: offset
                            )
                            ], toSection: .body(title: title)
                        )
                    }
                
                return snapshot
            }
            .eraseToAnyPublisher()
        
        let isLoading = input.loading
            .receive(on: DispatchQueue.global(qos: .background))
            .eraseToAnyPublisher()

        return Output(
            snapshot: snapshot,
            isLoading: isLoading
        )
    }

    func joinMap(map: CustomMap, writeToFirebase: Bool, completion: @escaping ((Bool) -> Void)) {
        var map = map
        map.likers.append(UserDataModel.shared.uid)
        if map.communityMap ?? false { map.memberIDs.append(UserDataModel.shared.uid) }
        updateMapCache(map: map)
        completion(true)

        if writeToFirebase {
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.mapService.followMap(customMap: map) { error in
                    if error != nil {
                        completion(false)
                    }
                }
                Mixpanel.mainInstance().track(event: "ExploreMapsJoinTap", properties: ["mapCount": 1])
            }
        }
    }

    func editMap(map: CustomMap) {
        updateMapCache(map: map)
    }

    private func updateMapCache(map: CustomMap) {
        if let i = cachedMaps.firstIndex(where: { $0.key.id == map.id }) {
            let posts = cachedMaps.removeValue(forKey: cachedMaps[i].key)
            cachedMaps[map] = posts
        }
    }
    
    func cacheScrollPosition(map: CustomMap, position: CGPoint) {
        cachedOffsets[map] = position
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
                    title: "",
                    description: ""
                )
                
                Task {
                    do {
                        var mapData: [CustomMap: [MapPost]] = [:]
                        let allMaps = try await self.mapService.fetchTopMaps(limit: 100)
                        let topMaps = allMaps.sorted(by: { $0.adjustedMapScore > $1.adjustedMapScore }).prefix(10)

                        for map in topMaps {
                            guard let mapID = map.id else { return }

                            let recentPostIDs = Array(map.postIDs.suffix(12))
                            let recentPostURLs = Array(map.postImageURLs.suffix(12))
                            var posts: [MapPost] = []

                            for i in 0..<recentPostIDs.count {
                                // just download thumbnail, download posts only once user taps into them
                                var post = MapPost(spotID: "", spotName: "", mapID: mapID, mapName: map.mapName)
                                post.id = map.postIDs[i]
                                post.imageURLs = [recentPostURLs[safe: i] ?? ""]
                                posts.insert(post, at: 0)
                            }
                            mapData[map] = posts
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

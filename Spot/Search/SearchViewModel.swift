//
//  SearchViewModel.swift
//  Spot
//
//  Created by Kenny Barone on 6/15/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Combine
import UIKit
import Firebase

final class SearchViewModel {
    typealias Section = SearchController.Section
    typealias Item = SearchController.Item
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

    struct Input {
        let searchText: PassthroughSubject<String, Never>
    }

    struct Output {
        let snapshot: AnyPublisher<Snapshot, Never>
    }
    private var cancellables = Set<AnyCancellable>()

    let mapService: MapServiceProtocol
    let spotService: SpotServiceProtocol
    let userService: UserServiceProtocol

    lazy var cachedSearchResults = [SearchResult]()

    init(serviceContainer: ServiceContainer) {
        guard let mapService = try? serviceContainer.service(for: \.mapsService),
              let spotService = try? serviceContainer.service(for: \.spotService),
              let userService = try? serviceContainer.service(for: \.userService)
        else {
            self.mapService = MapService(fireStore: Firestore.firestore())
            self.spotService = SpotService(fireStore: Firestore.firestore())
            self.userService = UserService(fireStore: Firestore.firestore())
            return
        }
        self.mapService = mapService
        self.spotService = spotService
        self.userService = userService
    }

    func bind(to input: Input) -> Output {
        let cachedPublisher = input.searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.global())
            .receive(on: DispatchQueue.global())
            .removeDuplicates()
            .flatMap { [unowned self] searchText in
                fetchCachedResults(searchText: searchText)
            }

        let databasePublisher = input.searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.global())
            .receive(on: DispatchQueue.global())
            .removeDuplicates()
            .flatMap { [unowned self] searchText in
                runFetchFromDatabase(searchText: searchText)
            }

        let mergedPublisher = Publishers.CombineLatest(cachedPublisher, databasePublisher)
            .map { (cachedResults, databaseResults) in
                var results = cachedResults
                var ids = cachedResults.map { $0.id ?? "" }
                for result in databaseResults {
                    if !ids.contains(result.id ?? "") {
                        results.append(result)
                        ids.append(result.id ?? "")
                    }
                }
                return results
            }

        let snapshot = mergedPublisher
            .receive(on: DispatchQueue.global())
            .map { searchResults in
                var snapshot = Snapshot()
                snapshot.appendSections([.main])
                _ = searchResults.map {
                    snapshot.appendItems([.item(searchResult: $0)], toSection: .main)
                }
                return snapshot
            }
            .eraseToAnyPublisher()
        return Output(snapshot: snapshot)


        /*
        let request = input.searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.global())
            .receive(on: DispatchQueue.global())
            .removeDuplicates()
            .map { [unowned self] searchText in
                Publishers.Merge(
                    self.fetchCachedSightings(searchText: searchText),
                    self.runFetchFromDatabase(searchText: searchText)
                )
            }
            .switchToLatest()
            .map { $0 }
        */

    }

    private func fetchCachedResults(searchText: String) -> AnyPublisher<[SearchResult], Never> {
        let searchResults = getLocalSearchResults(searchText: searchText)
        self.cachedSearchResults = searchResults
        return Just(searchResults).eraseToAnyPublisher()
    }

    private func runFetchFromDatabase(searchText: String) -> AnyPublisher<[SearchResult], Never> {
        Deferred {
            Future { [weak self] promise in
                guard let self else { return }
                guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
                    promise(.success([]))
                    return
                }

                Task(priority: .high) {
                    do {
                        var searchResults = [SearchResult]()
                        let maps = try await self.mapService.getMapsFrom(searchText: searchText, limit: 5)
                        for map in maps {
                            var searchResult = SearchResult(id: map.id, type: .map, ranking: 0)
                            searchResult.map = map
                            searchResults.append(searchResult)
                        }

                        let users = try await self.userService.getUsersFrom(searchText: searchText, limit: 5)
                        for user in users {
                            var searchResult = SearchResult(id: user.id, type: .user, ranking: 0)
                            searchResult.user = user
                            searchResults.append(searchResult)
                        }

                        let spots = try await self.spotService.getSpotsFrom(searchText: searchText, limit: 5)
                        for spot in spots {
                            let ranking = spot.visitorList.contains(UserDataModel.shared.uid) ? 1 : 0
                            var searchResult = SearchResult(id: spot.id, type: .spot, ranking: ranking)
                            searchResult.spot = spot
                            searchResults.append(searchResult)
                        }

                        //TODO: rank and sort
                        searchResults.sort(by: { $0.ranking > $1.ranking })
                        searchResults.append(contentsOf: self.getLocalSearchResults(searchText: searchText))
                        searchResults.removeDuplicates()
                        promise(.success((searchResults)))

                        self.cachedSearchResults = searchResults
                    } catch {
                        promise(.success(([])))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func getLocalSearchResults(searchText: String) -> [SearchResult] {
        let userMaps = mapService.queryMapsFrom(mapsList: UserDataModel.shared.userInfo.mapsList, searchText: searchText)
        let userFriends = userService.queryFriendsFromFriendsList(searchText: searchText)
        var localResults = [SearchResult]()

        for user in userFriends {
            var searchResult = SearchResult(id: user.id, type: .user, ranking: 1)
            searchResult.user = user
            localResults.append(searchResult)
        }

        for map in userMaps {
            var searchResult = SearchResult(id: map.id, type: .map, ranking: 1)
            searchResult.map = map
            localResults.append(searchResult)
        }

        return localResults
    }
}

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

    let mapService: MapServiceProtocol
    let spotService: SpotServiceProtocol
    let userService: UserServiceProtocol

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
        let request = input.searchText
            .receive(on: DispatchQueue.global())
            .map { [unowned self] searchText in
                (self.runFetch(searchText: searchText))

            }
            .switchToLatest()
            .map { $0 }

        let snapshot = request
            .removeDuplicates()
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
    }

    private func runFetch(searchText: String) -> AnyPublisher<[SearchResult], Never> {
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
                        let maps = try await self.mapService.getMapsFrom(searchText: searchText)
                        for map in maps {
                            var searchResult = SearchResult(id: map.id, type: .map, ranking: 0)
                            searchResult.map = map
                            searchResults.append(searchResult)
                        }

                        let spots = try await self.spotService.getSpotsFrom(searchText: searchText)
                        for spot in spots {
                            var searchResult = SearchResult(id: spot.id, type: .spot, ranking: 0)
                            searchResult.spot = spot
                            searchResults.append(searchResult)
                        }

                        let users = try await self.userService.getUsersFrom(searchText: searchText)
                        for user in users {
                            var searchResult = SearchResult(id: user.id, type: .user, ranking: 0)
                            searchResult.user = user
                            searchResults.append(searchResult)
                        }
                        //TODO: rank and sort

                        promise(.success((searchResults)))
                    } catch {
                        promise(.success(([])))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

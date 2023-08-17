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

    let spotService: SpotServiceProtocol
    let userService: UserServiceProtocol

    lazy var cachedSearchResults = [SearchResult]()

    init(serviceContainer: ServiceContainer) {
        guard let spotService = try? serviceContainer.service(for: \.spotService),
              let userService = try? serviceContainer.service(for: \.userService)
        else {
            self.spotService = SpotService(fireStore: Firestore.firestore())
            self.userService = UserService(fireStore: Firestore.firestore())
            return
        }
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
                results.append(contentsOf: databaseResults)
                results = results.sorted(by: { $0.ranking > $1.ranking }).removingDuplicates()
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

                        searchResults.append(contentsOf: self.getLocalSearchResults(searchText: searchText))

                        let users = try await self.userService.getUsersFrom(searchText: searchText, limit: 5)
                        for user in users {
                            let ranking = self.getRankingFor(user: user)
                            var searchResult = SearchResult(id: user.id, type: .user, ranking: ranking)
                            searchResult.user = user
                            searchResults.append(searchResult)
                        }

                        let spots = try await self.spotService.getSpotsFrom(searchText: searchText, limit: 5)
                        for spot in spots {
                            let ranking = self.getRankingFor(spot: spot)
                            var searchResult = SearchResult(id: spot.id, type: .spot, ranking: ranking)
                            searchResult.spot = spot
                            searchResults.append(searchResult)
                        }

                        searchResults = searchResults.sorted(by: { $0.ranking > $1.ranking }).removingDuplicates()
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

    private func getRankingFor(spot: MapSpot) -> Int {
        // ranking based on # of times user has posted to this spot
        var ranking = (spot.posterIDs.map({ $0 == UserDataModel.shared.uid }).count) * 3
        // increment if user or any friends have visited
        if spot.visitorList.contains(UserDataModel.shared.uid) { ranking += 5 }
        for friendID in UserDataModel.shared.userInfo.friendIDs {
            if spot.visitorList.contains(friendID) { ranking += 1 }
        }
        return ranking
    }

    private func getRankingFor(user: UserProfile) -> Int {
        if let ranking = UserDataModel.shared.userInfo.topFriends?[user.id ?? ""] {
            return ranking

        } else {
            // rank based on number of mutuals you have with the person
            var ranking = 1
            for user in user.friendIDs {
                if UserDataModel.shared.userInfo.friendIDs.contains(user) {
                    ranking += 2
                }
            }
            return ranking
        }
    }

    private func getLocalSearchResults(searchText: String) -> [SearchResult] {
        let userFriends = userService.queryFriendsFromFriendsList(searchText: searchText)
        var localResults = [SearchResult]()

        for user in userFriends {
            // ranking = user's friends ranking
            let ranking = UserDataModel.shared.userInfo.topFriends?[user.id ?? ""] ?? 1
            var searchResult = SearchResult(id: user.id, type: .user, ranking: ranking)
            searchResult.user = user
            localResults.append(searchResult)
        }

        return localResults
    }
}

//
//  NearbyPostsViewModel.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 2/24/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit
import Combine
import Firebase

final class NearbyPostsViewModel {
    typealias Section = ExploreMapViewController.Section
    typealias Item = ExploreMapViewController.Item
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    
    struct Input {
        let refresh: PassthroughSubject<Bool, Never>
    }
    
    struct Output {
        let snapshot: AnyPublisher<Snapshot, Never>
        let isLoading: AnyPublisher<Bool, Never>
    }
    
    private let mapService: MapServiceProtocol
    private let postService: MapPostServiceProtocol
    private let spotService: SpotServiceProtocol
    private let userService: UserServiceProtocol
    
    init(serviceContainer: ServiceContainer) {
        guard let mapService = try? serviceContainer.service(for: \.mapsService),
              let postService = try? serviceContainer.service(for: \.mapPostService),
              let spotService = try? serviceContainer.service(for: \.spotService),
              let userService = try? serviceContainer.service(for: \.userService)
        else {
            mapService = MapService(fireStore: Firestore.firestore())
            postService = MapPostService(fireStore: Firestore.firestore())
            spotService = SpotService(fireStore: Firestore.firestore())
            userService = UserService(fireStore: Firestore.firestore())
            return
        }
        
        self.userService = userService
        self.spotService = spotService
        self.mapService = mapService
        self.postService = postService
    }
    
    func bind(to input: Input) -> Output {
        
    }
}

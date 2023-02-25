//
//  AllPostsViewModel.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 2/24/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import Combine

final class AllPostsViewModel {
    
    // TODO: Add subscription to Friends Collection and Map Posts
    // TODO: Add the update post logic
    
    /*
     if !myPostsFetched {
         addFriendsListener(query: friendsQuery)
         addMapListener(query: mapsQuery)
     } else {
         getFriendsPosts(query: friendsQuery)
         getMapPosts(query: mapsQuery)
     }
     */
    
    /*
     class FriendsViewModel: ObservableObject {
         @Published var friends: [Document<User>] = []
         var cancellable: AnyCancellable? = nil
         @ObservedObject var authStore = AuthStore(auth: Auth.auth())
         init() {
             bind()
         }
         func bind() {
             cancellable = Document<Room>.listen(query: Firestore.firestore().collection("user").whereField("friends", arrayContains: Auth.auth().currentUser!.uid).limit(to: 10)).sink(receiveCompletion: { error in
             }, receiveValue: { [weak self] friends in
                 print("My friends..",friends.joined(separator: ","))
                 self?.friends = friends
             })
         }
     }
     */
}

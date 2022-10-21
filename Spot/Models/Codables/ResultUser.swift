//
//  ResultUser.swift
//  Spot
//
//  Created by kbarone on 6/25/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import FirebaseFirestoreSwift
import Foundation
import UIKit

struct ResultUser: Identifiable, Codable, Hashable {

    @DocumentID var id: String?
    var imageURL: String
    var name: String
    var username: String
    var image: UIImage = UIImage()

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case username
        case imageURL
    }
}

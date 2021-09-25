//
//  Tag.swift
//  Spot
//
//  Created by kbarone on 1/8/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase

struct Tag {
    
    var name: String
    var image: UIImage
    var imageURL: String
    var selected: Bool
    var spotCount: Int
    
    init(name: String) {
        self.name = name
        selected = false
        spotCount = 0
        image = UIImage(named: "\(name)Tag") ?? UIImage()
        imageURL = ""
    }
    
    // download image from firebase if user doesn't have this tag stored locally (probably doesn't have most recent version)
    func getImageURL(completion: @escaping (_ URL: String) -> Void) {
        
        var imageURL = ""
        let db = Firestore.firestore()
        db.collection("tags").whereField("tagName", isEqualTo: name).getDocuments { snap, err in
            
            if err != nil || snap!.documents.count == 0 { completion(imageURL); return }
            
            guard let doc = snap?.documents.first else { completion(imageURL); return }
            imageURL = doc.get("imageURL") as? String ?? ""
            completion(imageURL)
        }
    }
}

//
//  Tag.swift
//  Spot
//
//  Created by kbarone on 1/8/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation

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

    var category: Int {
        switch name {
        // active
        case "Active", "Art", "Basketball", "Bike", "Billiards", "Boat", "Boogie", "Books", "Camp", "Cards", "Carnival", "Fish", "Garden", "Golf", "History", "Music", "Race", "Shop", "Skate", "Ski", "Surf", "Swim", "Tennis", "View":
            return 1
        // eat / drink
        case "Bread", "Burger", "Cake", "Carrot", "Cocktail", "Coffee", "Cook", "Cream", "Donut", "Drink", "Eat", "Egg", "Fries", "Glizzy", "Honey", "Liquor", "Meat", "Pizza", "Salad", "Strawberry", "Sushi", "Taco", "Tea", "Wine":
            return 2
        // life
        case "Alien", "Bodega", "Car", "Casino", "Castle", "Chill", "Cig", "Danger", "Gas", "Heels", "Home", "Money", "NSFW", "Pills", "Pirate", "Plane", "Reaper", "Siren", "Skyscraper",             "Smoke", "Suitcase", "Toilet", "Train", "Weird":
            return 3
        // nature
        case "Bear", "Bird", "Bug", "Cactus", "Cat", "Cityset", "Cow", "Dog", "Flower", "Leaf", "Log", "Monkey", "Moon", "Mountain", "Nature", "Park", "Rainbow", "Snake", "Snow", "Star", "Sunset", "Trail", "Tropical", "Umbrella", "Water", "Whale":
            return 4
        default: return 5
        }
    }
}

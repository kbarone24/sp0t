//
//  SpotDraft+CoreDataProperties.swift
//  Spot
//
//  Created by kbarone on 5/18/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//
//

import Foundation
import CoreData


extension SpotDraft {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SpotDraft> {
        return NSFetchRequest<SpotDraft>(entityName: "SpotDraft")
    }
    
    @NSManaged public var spotName: String?
    @NSManaged public var spotDescription: String?
    @NSManaged public var tags: [String]?
    @NSManaged public var taggedUsernames: [String]?
    @NSManaged public var taggedIDs: [String]?
    @NSManaged public var spotLat: Double
    @NSManaged public var spotLong: Double
    @NSManaged public var postLat: Double
    @NSManaged public var postLong: Double
    @NSManaged public var spotID: String?
    @NSManaged public var timestamp: Int64
    @NSManaged public var images: NSSet?
    @NSManaged public var uid: String?
    @NSManaged public var privacyLevel: String?
    @NSManaged public var inviteList: [String]?
    @NSManaged public var phone: String?
    @NSManaged public var submitPublic: Bool
    @NSManaged public var postToPOI: Bool
    @NSManaged public var hideFromFeed: Bool
    @NSManaged public var frameIndexes: [Int]?
}

// MARK: Generated accessors for images
extension SpotDraft {

    @objc(addImagesObject:)
    @NSManaged public func addToImages(_ value: ImageModel)

    @objc(removeImagesObject:)
    @NSManaged public func removeFromImages(_ value: ImageModel)

    @objc(addImages:)
    @NSManaged public func addToImages(_ values: NSSet)

    @objc(removeImages:)
    @NSManaged public func removeFromImages(_ values: NSSet)

}

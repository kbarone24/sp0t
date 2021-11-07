//
//  PostDraft+CoreDataProperties.swift
//  Spot
//
//  Created by kbarone on 5/18/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//
//

import Foundation
import CoreData


extension PostDraft {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PostDraft> {
        return NSFetchRequest<PostDraft>(entityName: "PostDraft")
    }

    @NSManaged public var addedUsers: [String]?
    @NSManaged public var aspectRatios: [Float]?
    @NSManaged public var caption: String?
    @NSManaged public var city: String?
    @NSManaged public var createdBy: String?
    @NSManaged public var inviteList: [String]?
    @NSManaged public var privacyLevel: String?
    @NSManaged public var spotPrivacy: String?
    @NSManaged public var spotID: String?
    @NSManaged public var postLat: Double
    @NSManaged public var postLong: Double
    @NSManaged public var spotLat: Double
    @NSManaged public var spotLong: Double
    @NSManaged public var spotName: String?
    @NSManaged public var taggedUsers: [String]?
    @NSManaged public var taggedUserIDs: [String]?
    @NSManaged public var timestamp: Int64
    @NSManaged public var images: NSSet?
    @NSManaged public var hideFromFeed: Bool
    @NSManaged public var uid: String?
    @NSManaged public var isFirst: Bool
    @NSManaged public var visitorList: [String]?
    @NSManaged public var friendsList: [String]?
    @NSManaged public var frameIndexes: [Int]?
    @NSManaged public var gif: Bool
    @NSManaged public var tag: String
}

// MARK: Generated accessors for images
extension PostDraft {

    @objc(addImagesObject:)
    @NSManaged public func addToImages(_ value: ImageModel)

    @objc(removeImagesObject:)
    @NSManaged public func removeFromImages(_ value: ImageModel)

    @objc(addImages:)
    @NSManaged public func addToImages(_ values: NSSet)

    @objc(removeImages:)
    @NSManaged public func removeFromImages(_ values: NSSet)

}

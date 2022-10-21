//
//  ImagesArray+CoreDataProperties.swift
//  Spot
//
//  Created by kbarone on 5/18/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//
//

import CoreData
import Foundation

extension ImagesArray {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ImagesArray> {
        return NSFetchRequest<ImagesArray>(entityName: "ImagesArray")
    }

    @NSManaged public var postLat: NSNumber?
    @NSManaged public var postLong: NSNumber?
    @NSManaged public var id: Int64
    @NSManaged public var images: NSSet?
    @NSManaged public var uid: String?
}

// MARK: Generated accessors for images
extension ImagesArray {

    @objc(addImagesObject:)
    @NSManaged public func addToImages(_ value: ImageModel)

    @objc(removeImagesObject:)
    @NSManaged public func removeFromImages(_ value: ImageModel)

    @objc(addImages:)
    @NSManaged public func addToImages(_ values: NSSet)

    @objc(removeImages:)
    @NSManaged public func removeFromImages(_ values: NSSet)

}

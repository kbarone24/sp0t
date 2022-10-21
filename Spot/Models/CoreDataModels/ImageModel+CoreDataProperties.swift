//
//  ImageModel+CoreDataProperties.swift
//  Spot
//
//  Created by kbarone on 5/18/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//
//

import CoreData
import Foundation

extension ImageModel {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ImageModel> {
        return NSFetchRequest<ImageModel>(entityName: "ImageModel")
    }

    @NSManaged public var imageData: Data?
    @NSManaged public var imagesArray: ImagesArray?
    @NSManaged public var post: PostDraft?
    @NSManaged public var position: Int16
}

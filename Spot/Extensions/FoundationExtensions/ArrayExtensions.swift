//
//  ArrayExtensions.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
    
    func difference(from other: [Element]) -> [Element] {
        let thisSet = Set(self)
        let otherSet = Set(other)
        return Array(thisSet.symmetricDifference(otherSet))
    }
    
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()

        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }

    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }
}

extension Array where Element == MapPost {
    func removingDuplicates() -> [Element] {
        var addedDict = [String: Bool]()

        return filter {
            addedDict.updateValue(true, forKey: $0.id ?? "empty") == nil
        }
    }

    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }
}

extension Array where Element == MapSpot {
    func removingDuplicates() -> [Element] {
        var addedDict = [String: Bool]()

        return filter {
            addedDict.updateValue(true, forKey: $0.id ?? "empty") == nil
        }
    }

    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }
}

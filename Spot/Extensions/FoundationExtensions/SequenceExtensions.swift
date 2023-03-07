//
//  SequenceExtensions.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 3/2/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation

extension Sequence where Element: Sendable {
    @inlinable public func throwingAsyncValues<T>(
        of type: T.Type = T.self,
        body: @escaping @Sendable (Element) async throws -> T
    ) async rethrows -> [T] {
        try await withThrowingTaskGroup(of: (Int, T).self) { group in
            for (index, value) in enumerated() {
                group.addTask { try await (index, body(value)) }
            }

            let dictionary = try await group.reduce(into: [:]) { $0[$1.0] = $1.1 }
            return enumerated().compactMap { dictionary[$0.0] }
        }
    }
}

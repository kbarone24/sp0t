//
//  ServiceContainer.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/21/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation

final class ServiceContainer {

    // MARK: Error Types

    enum RegistrationError: Error {
        case alreadyRegistered
        case readOnlyViolation
    }

    enum FetchError: Error {
        case notFound
    }

    // MARK: Network Services

    private(set) var mapsService: MapServiceProtocol?

    // MARK: Interface

    func register<T>(service: T, for keyPath: KeyPath<ServiceContainer, T?>) throws {

        guard let writeableKeyPath = keyPath as? ReferenceWritableKeyPath else {
            throw RegistrationError.readOnlyViolation
        }

        guard self[keyPath: writeableKeyPath] == nil else {
            throw RegistrationError.alreadyRegistered
        }

        self[keyPath: writeableKeyPath] = service
    }

    func service<T>(for keyPath: KeyPath<ServiceContainer, T?>) throws -> T {
        guard let service = self[keyPath: keyPath] else {
            throw FetchError.notFound
        }
        return service
    }
}

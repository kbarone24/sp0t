//
//  CacheService.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 2/25/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation

final class CacheService<Key: Hashable, Value> {

    private let wrapped = NSCache<WrappedKey, Entry>()
    private let dateProvider: () -> Date
    private let entryLifetime: TimeInterval
    private let keyTracker = KeyTracker()

    init(dateProvider: @escaping () -> Date = Date.init,
         entryLifetime: TimeInterval = 12 * 60 * 60,
         maximumEntryCount: Int = 150) {
        self.dateProvider = dateProvider
        self.entryLifetime = entryLifetime
        wrapped.countLimit = maximumEntryCount
        wrapped.delegate = keyTracker
    }
    
    func allCachedValues() -> [Value] {
        keyTracker.keys.map {
            self.entry(forKey: $0)?.value
        }
        .compactMap { $0 }
    }
    
    func allCachedKeys() -> [Key] {
        keyTracker.keys.map { $0 }
    }
    
    func allCachedEntries() -> [Entry] {
        keyTracker.keys.map {
            self.entry(forKey: $0)
        }
        .compactMap { $0 }
    }
    
    func entry(forKey key: Key) -> Entry? {
        guard let entry = wrapped.object(forKey: WrappedKey(key)) else {
            return nil
        }

        guard dateProvider() < entry.expirationDate else {
            removeValue(forKey: key)
            return nil
        }

        return entry
    }

    func insert(_ entry: Entry) {
        wrapped.setObject(entry, forKey: WrappedKey(entry.key))
        keyTracker.keys.insert(entry.key)
    }
    
    func removeValue(forKey key: Key) {
        wrapped.removeObject(forKey: WrappedKey(key))
    }
}

private extension CacheService {
    final class WrappedKey: NSObject {
        let key: Key

        init(_ key: Key) { self.key = key }

        override var hash: Int { return key.hashValue }

        override func isEqual(_ object: Any?) -> Bool {
            guard let value = object as? WrappedKey else {
                return false
            }

            return value.key == key
        }
    }
}

extension CacheService {
    final class Entry {
        let key: Key
        let value: Value
        let expirationDate: Date

        init(
            key: Key,
            value: Value,
            expirationDate: Date = Calendar.current.date(byAdding: .second, value: 12 * 60 * 60, to: Date()) ?? Date(timeIntervalSinceNow: 12 * 60 * 60)
        ) {
            self.key = key
            self.value = value
            self.expirationDate = expirationDate
        }
    }
}

extension CacheService.Entry: Codable where Key: Codable, Value: Codable {}

private extension CacheService {
    final class KeyTracker: NSObject, NSCacheDelegate {
        var keys = Set<Key>()

        func cache(_ cache: NSCache<AnyObject, AnyObject>,
                   willEvictObject object: Any) {
            guard let entry = object as? Entry else {
                return
            }

            keys.remove(entry.key)
        }
    }
}

extension CacheService: Codable where Key: Codable, Value: Codable {
    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.singleValueContainer()
        let entries = try container.decode([Entry].self)
        entries.forEach(insert)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(keyTracker.keys.compactMap(entry))
    }
    
    func allCachedValues() -> [Value] {
        keyTracker.keys.map {
            self.entry(forKey: $0)?.value
        }
        .compactMap { $0 }
    }
    
    func allCachedKeys() -> [Key] {
        keyTracker.keys.map { $0 }
    }
    
    func allCachedEntries() -> [Entry] {
        keyTracker.keys.map {
            self.entry(forKey: $0)
        }
        .compactMap { $0 }
    }
    
    func entry(forKey key: Key) -> Entry? {
        guard let entry = wrapped.object(forKey: WrappedKey(key)) else {
            return nil
        }

        guard dateProvider() < entry.expirationDate else {
            removeValue(forKey: key)
            return nil
        }

        return entry
    }

    func insert(_ entry: Entry) {
        wrapped.setObject(entry, forKey: WrappedKey(entry.key))
        keyTracker.keys.insert(entry.key)
        try? saveToDisk(withName: "\(entry.key)")
    }
    
    func removeValue(forKey key: Key) {
        wrapped.removeObject(forKey: WrappedKey(key))
        try? deleteFromDisk(fileName: "\(key)")
    }
}

private extension CacheService where Key: Codable, Value: Codable {
    func saveToDisk(
        withName name: String,
        using fileManager: FileManager = .default
    ) throws {
        let folderURLs = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )

        let fileURL = folderURLs[0].appendingPathComponent(name + ".cache")
        let data = try JSONEncoder().encode(self)
        try data.write(to: fileURL)
    }
    
    func deleteFromDisk(
        fileName name: String,
        using fileManager: FileManager = .default
    ) throws {
        let folderURLs = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )
        
        let fileURL = folderURLs[0].appendingPathComponent(name + ".cache")
        try fileManager.removeItem(at: fileURL)
    }
}

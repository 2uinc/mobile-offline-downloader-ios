//
// This file is part of Canvas.
// Copyright (C) 2023-present  Instructure, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import RealmSwift
import Foundation

protocol Applyable { }

extension Applyable {
    // MARK: - Appearance
    @discardableResult
    func apply(_ configuration: (Self) throws -> Void) rethrows -> Self {
        try configuration(self)
        return self
    }
}
extension NSObject: Applyable { }

extension Realm: Applyable {}
extension RealmDatabaseThread: Applyable {}

private enum DispatchQueueLabels {
    static let backgroundLabel: String = "io.realm.Database.backgroundQueue"
}

final class RealmDatabaseThread {

    typealias Key = String
    typealias WorkingQueue = (_ key: Key) -> DispatchQueue?

    // MARK: - Properties
    // MARK: Content

    private lazy var realms: [Key: Realm] = [:]

    // MARK: Inputs

    var workingQueue: WorkingQueue?

    // MARK: - Appearance

    func getInstance() throws -> Realm {
        let key = try threadKey()
        return try realm(by: key).apply { realm in
            realm.refresh()
        }
    }

    private func realm(by key: Key) throws -> Realm {
        if realms.keys.contains(key) {
            let realm = realms[key]
            if realm?.isFrozen == true {
                realms.removeValue(forKey: key)
                return try self.realm(by: key)
            }
            guard let realm = realm else {
                throw RealmError.text("Realm init error")
            }
            return realm
        }
        let realm = try Realm(
            configuration: Realm.Configuration(
                schemaVersion: 1,
                migrationBlock: { _, _ in },
                deleteRealmIfMigrationNeeded: true
            ), queue: workingQueue?(key)
        )
        realms[key] = realm
        return realm
    }

    private func threadKey() throws -> Key {
        let key = __dispatch_queue_get_label(nil)
        guard let representableKey = Key(cString: key, encoding: .utf8) else {
            throw RealmError.text("Realm ThreadKey error")
        }
        return representableKey
    }
}

final class RealmDatabaseQueue {
    // MARK: - Properties

    private(set) lazy var background: DispatchQueue = .init(
        label: DispatchQueueLabels.backgroundLabel,
        qos: .userInitiated
    )

    private lazy var queues: [String: DispatchQueue] = [
        DispatchQueue.main.label: .main,
        background.label: background
    ]

    // MARK: - Appearane
    func get(by name: String) -> DispatchQueue? {
        queues[name]
    }
}

enum RealmError: Error {
    case text(String)
    case error
}

extension RealmError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .text(let text):
            return text
        case .error:
            return "Realm error"
        }
    }
}

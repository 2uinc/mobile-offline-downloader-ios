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

public protocol Storable: Object, RealmFetchable {
    static func all(
        in storage: LocalStorage,
        completionHandler: @escaping (Result<Results<Self>, Error>) -> Void
    )

    static func object<KeyType>(
        in storage: LocalStorage,
        forPrimaryKey key: KeyType,
        completionHandler: @escaping (_ value: Self?) -> Void
    )

    func addOrUpdate(
        in storage: LocalStorage,
        completionHandler: @escaping (Result<Void, Error>) -> Void
    )

    func delete(
        in storage: LocalStorage,
        completionHandler: @escaping (Result<Void, Error>) -> Void
    )
}

public extension Storable {
    static func all(
        in storage: LocalStorage,
        completionHandler: @escaping (Result<Results<Self>, Error>) -> Void
    ) {
        storage.objects(Self.self, completionHandler: completionHandler)
    }

    static func object<KeyType>(
        in storage: LocalStorage,
        forPrimaryKey key: KeyType,
        completionHandler: @escaping (_ value: Self?) -> Void
    ) {
        storage.object(Self.self, forPrimaryKey: key, completionHandler: completionHandler)
    }

    func addOrUpdate(
        in storage: LocalStorage,
        completionHandler: @escaping (Result<Void, Error>) -> Void
    ) {
        storage.addOrUpdate(value: self, completionHandler: completionHandler)
    }

    func delete(
        in storage: LocalStorage,
        completionHandler: @escaping (Result<Void, Error>) -> Void
    ) {
        storage.delete(Self.self, value: self, completionHandler: completionHandler)
    }
}

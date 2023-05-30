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

final public class RealmStorage: LocalStorage {

    static public let `default`: RealmStorage = RealmStorage()

    private init() {
    }

    let dataBaseQueue: RealmDatabaseQueue = .init()
    lazy var dataBaseThread: RealmDatabaseThread = RealmDatabaseThread().apply {
        $0.workingQueue = { [unowned self] key in
            self.dataBaseQueue.get(by: key)
        }
    }
    var realm: Realm? {
        do {
            return try dataBaseThread.getInstance()
        } catch {
            print("‼️ Realm error: \(error) ‼️")
            return nil
        }
    }

    public func addOrUpdate<T>(
        value: T,
        completionHandler: @escaping (Result<Void, Error>) -> Void
    ) where T: Storable {
        dataBaseQueue.background.async { [weak self] in
            guard let realm = self?.realm else {
                DispatchQueue.main.async {
                    completionHandler(.failure(RealmError.error))
                }
                return
            }
            do {
                try realm.write {
                    realm.add(value, update: .all)
                    DispatchQueue.main.async {
                        completionHandler(.success(()))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completionHandler(.failure(error))
                }
            }
        }
    }

    public func addOrUpdate<T>(
        values: [T],
        completionHandler: @escaping (Result<Void, Error>) -> Void
    ) where T: Storable {
        dataBaseQueue.background.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completionHandler(.failure(RealmError.error))
                }
                return
            }
            let group = DispatchGroup()
            values.forEach {
                group.enter()
                self.addOrUpdate(
                    value: $0
                ) { _ in
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                completionHandler(.success(()))
            }
        }
    }

    public func objects<T>(
        _ type: T.Type,
        completionHandler: @escaping (Result<Results<T>, Error>) -> Void
    ) where T: Storable {
        dataBaseQueue.background.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completionHandler(.failure(RealmError.error))
                }
                return
            }
            guard let realm = self.realm else {
                DispatchQueue.main.async {
                    completionHandler(.failure(RealmError.error))
                }
                return
            }

            let results = ThreadSafeReference(to: realm.objects(type))
            DispatchQueue.main.async {
                guard let resultsMain = self.realm?.resolve(results) else {
                    return
                }
                completionHandler(.success(resultsMain))
            }
        }
    }

    public func object<T, KeyType>(
        _ type: T.Type,
        forPrimaryKey key: KeyType,
        completionHandler: @escaping (T?) -> Void
    ) where T: Storable {
        dataBaseQueue.background.async { [weak self] in
            guard let realm = self?.realm else {
                DispatchQueue.main.async {
                    completionHandler(nil)
                }
                return
            }

            guard let object = realm.object(ofType: type, forPrimaryKey: key) else {
                DispatchQueue.main.async {
                    completionHandler(nil)
                }
                return
            }

            let results = ThreadSafeReference(to: object)
            DispatchQueue.main.async {
                guard let resultsMain = self?.realm?.resolve(results) else {
                    completionHandler(nil)
                    return
                }
                completionHandler(resultsMain)
            }
        }
    }

    public func delete<T>(
        _ type: T.Type,
        value: T,
        completionHandler: @escaping (Result<Void, Error>) -> Void
    ) where T: Storable {
        dataBaseQueue.background.async { [weak self] in
            guard let realm = self?.realm else {
                DispatchQueue.main.async {
                    completionHandler(.failure(RealmError.error))
                }
                return
            }
            do {
                try realm.write {
                    guard let value = value as? StoreObject else {
                        DispatchQueue.main.async {
                            completionHandler(.failure(RealmError.error))
                        }
                        return
                    }
                    guard let objToDelete = realm.object(
                        ofType: type.self,
                        forPrimaryKey: value.id
                    ) else {
                        DispatchQueue.main.async {
                            completionHandler(.failure(RealmError.error))
                        }
                        return
                    }
                    realm.delete(objToDelete)
                    DispatchQueue.main.async {
                        completionHandler(.success(()))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completionHandler(.failure(error))
                }
            }
        }
    }

    public func delete<T>(
        _ type: T.Type,
        values: [T],
        completionHandler: @escaping (Result<Void, Error>) -> Void
    ) where T: Storable {
        dataBaseQueue.background.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completionHandler(.failure(RealmError.error))
                }
                return
            }
            let group = DispatchGroup()
            values.forEach {
                group.enter()
                self.delete(
                    type,
                    value: $0
                ) { _ in
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                completionHandler(.success(()))
            }
        }
    }

    public func deleteAll(completionHandler: @escaping (Result<Void, Error>) -> Void) {
        dataBaseQueue.background.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completionHandler(.failure(RealmError.error))
                }
                return
            }
            do {
                try self.realm?.write {
                    self.realm?.deleteAll()
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

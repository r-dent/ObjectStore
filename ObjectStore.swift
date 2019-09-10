//
//  ObjectStore.swift
//  RapScript
//
//  Created by Roman Gille on 09.09.19.
//  Copyright © 2019 RapScript. All rights reserved.
//

import Foundation

protocol ObjectStoreElement {
    var id: Int { get }
}

protocol ObjectStore {

    typealias StorableObject = ObjectStoreElement & Codable

    var debugLog: Bool { get set }

    func add<T: StorableObject>(_ object: T)
    func remove<T: StorableObject>(_ object: T)
    func all<T: StorableObject>() -> [T]
    func all<T: StorableObject>(of elementType: T.Type) -> [T]
    func element<T: StorableObject>(with id: Int) -> T?
    func removeAll<T: StorableObject>(of elementType: T.Type)
}

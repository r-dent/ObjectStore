//
//  Database.swift
//  RapScript
//
//  Created by Roman Gille on 09.09.19.
//  Copyright © 2019 RapScript. All rights reserved.
//

import Foundation

protocol DatabaseElement {
    var id: Int { get }
}

protocol Database {

    typealias CodableDbElement = DatabaseElement & Codable

    func add<T: CodableDbElement>(_ object: T)
    func remove<T: CodableDbElement>(_ object: T)
    func all<T: CodableDbElement>() -> [T]
    func all<T: CodableDbElement>(of elementType: T.Type) -> [T]
    func removeAll<T: CodableDbElement>(of elementType: T.Type)
}

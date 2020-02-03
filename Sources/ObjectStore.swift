//
//  ObjectStore.swift
//  RapScript
//
//  Created by Roman Gille on 09.09.19.
//
//  Copyright (c) 2019 Roman Gille, http://romangille.com
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
//  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
//  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation

protocol ObjectStore {

    associatedtype Element: Hashable & Codable

    var elements: Set<Element> { get }

    func insert(_ element: Element)
    func update(with element: Element)
    func remove(_ element: Element)
}

@available(iOS, obsoleted: 13)
public protocol Identifiable {

    /// A type representing the stable identity of the entity associated with `self`.
    associatedtype ID : Hashable

    /// The stable identity of the entity associated with `self`.
    var id: Self.ID { get }
}

// MARK: - Extra methods for Identifiable elements.

extension ObjectStore where Element: Identifiable {

    mutating func removeElement(with id: Element.ID) {

        if let element = element(with: id) {
            remove(element)
        }
    }

    func element(with id: Element.ID) -> Element? {
        return elements.first(where: { $0.id == id })
    }
}

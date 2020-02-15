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

    func insert(_ elements: Set<Element>)
    func remove(_ elements: Set<Element>)
    func set(_ elements: Set<Element>)
}

// MARK: - Protocol backport.

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

extension ObjectStore {

    func insert(_ elements: [Element]) {
        insert(Set(elements))
    }

    func remove(_ elements: [Element]) {
        remove(Set(elements))
    }

    func set(_ elements: [Element]) {
        set(Set(elements))
    }
}

// MARK: - Type erasing type.

class AnyObjectStore<Element: Hashable & Codable> {

    private let getElements: () -> Set<Element>
    private let insertElement: (Element) -> Void
    private let updateElement: (Element) -> Void
    private let removeElement: (Element) -> Void

    private let insertElements: (Set<Element>) -> Void
    private let removeElements: (Set<Element>) -> Void
    private let setElements: (Set<Element>) -> Void

    init<Store: ObjectStore>(_ objectStore: Store) where Store.Element == Element {

        getElements = { return objectStore.elements }

        insertElement = objectStore.insert
        updateElement = objectStore.update
        removeElement = objectStore.remove

        insertElements = objectStore.insert
        removeElements = objectStore.remove
        setElements = objectStore.set
    }
}

extension AnyObjectStore: ObjectStore {

    var elements: Set<Element> {
        getElements()
    }

    func insert(_ element: Element) {
        insertElement(element)
    }

    func update(with element: Element) {
        updateElement(element)
    }

    func remove(_ element: Element) {
        removeElement(element)
    }

    func insert(_ elements: Set<Element>) {
        insertElements(elements)
    }

    func remove(_ elements: Set<Element>) {
        removeElements(elements)
    }

    func set(_ elements: Set<Element>) {
        setElements(elements)
    }
}

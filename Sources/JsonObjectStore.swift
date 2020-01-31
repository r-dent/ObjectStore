//
//  JsonObjectStore.swift
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

class JsonObjectStore<T: Codable & Hashable> {

    private(set) var elements: Set<T> = [] {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                self.shouldPersist = self.dataIsInitiallyLoaded && (oldValue != self.elements)
            }
        }
    }
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let throttleDelay: Int = 2

    private(set) var dataIsInitiallyLoaded: Bool = false
    private var shouldPersist: Bool = false
    private var writeTimer: DispatchSourceTimer!
    private var readyHandler: ElementsReadyBlock?

    let fileName: String
    var debugLog: Bool = false

    private lazy var fileUrl: URL = {
        let appSupportDir = try! FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let jsonDataDir = appSupportDir.appendingPathComponent("jsonData")

        if !FileManager.default.fileExists(atPath: jsonDataDir.relativePath) {
            try? FileManager.default.createDirectory(at: jsonDataDir, withIntermediateDirectories: true, attributes: nil)
        }

        return jsonDataDir.appendingPathComponent(self.fileName)
    }()

    init(fileName: String = String(describing: T.self)) {

        self.fileName = fileName

        // Prepare caches.
        DispatchQueue.global().async { [weak self] in

            try? self?.prepareCache()

            DispatchQueue.main.async {

                self?.readyHandler?(self?.elements)
                self?.dataIsInitiallyLoaded = true
                self?.readyHandler = nil
            }
        }
        // Prepare timer.
        writeTimer = DispatchSource.makeTimerSource()
        writeTimer.schedule(deadline: .now() + .seconds(throttleDelay), repeating: .seconds(throttleDelay))
        writeTimer.setEventHandler { [weak self] in
            try? self?.persistIfNeeded()
        }
        writeTimer.activate()
    }

    deinit {
        writeTimer.setEventHandler {}
        writeTimer.cancel()
        // If the timer is suspended, calling cancel without resuming triggers a crash.
        // This is documented here https://forums.developer.apple.com/thread/15902
        writeTimer.resume()
    }
}

// MARK: - Data persistence.

private extension JsonObjectStore {

    func persistIfNeeded() throws {

        if shouldPersist {
            try self.persistCache()
        }
        DispatchQueue.main.async { [weak self] in
            self?.shouldPersist = false
        }
    }

    /// Loads json file from disk an tries to parse it´s contents into the elements property.
    func prepareCache() throws {

        guard let jsonData = try? Data(contentsOf: fileUrl) else {

            self.elements = Set<T>()
            log("Could not find file \(fileUrl.lastPathComponent). Starting with empty data.")
            return
        }

        let elements = try decoder.decode([T].self, from: jsonData)
        self.elements = Set(elements)
        log("Did load \(elements.count) elements from \(fileUrl.lastPathComponent).")
    }

    /// Writes the contents of the elements property do disk.
    func persistCache() throws {

        let encoded = try encoder.encode(self.elements)
        let filePath = fileUrl.relativePath
        let wrote = fileManager.createFile(atPath: filePath, contents: encoded, attributes: nil)

        if wrote {
            log("Wrote \(elements.count) entries to \(fileUrl.lastPathComponent).")
        } else {
            log("Error writing file!")
        }
    }

    func log(_ text: @autoclosure () -> String) {
        if debugLog {
            print("JSON Store: \(text())")
        }
    }
}

extension JsonObjectStore: ObjectStore {

    typealias Element = T

    func onDataReady(_ handler: @escaping ElementsReadyBlock) {

        if dataIsInitiallyLoaded {
            handler(elements)
        } else {
            self.readyHandler = handler
        }
    }

    func set(_ elements: [T]) {
        self.elements = Set(elements)
    }

    func set(_ elements: Set<T>) {
        self.elements = elements
    }

    func add(_ elements: [T]) {
        self.elements.formUnion(elements)
    }

    func add(_ element: T) {
        elements.insert(element)
    }

    func remove(_ element: T) {
        elements.remove(element)
    }

    func clear() {
        elements = Set<Element>()
    }
}

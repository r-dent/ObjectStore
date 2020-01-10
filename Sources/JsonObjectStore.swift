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

    private(set) var data: Set<T> = [] {
        didSet { shouldPersist = true }
    }
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let throttleDelay: Int = 2
    private var shouldPersist: Bool = false
    private var writeTimer: DispatchSourceTimer!
    private var readyHandler: (([T]) -> Void)?

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

    init(fileName: String, completion: (([T]) -> ())? = nil) {

        self.fileName = fileName

        // Prepare caches.
        DispatchQueue.global().async { [weak self] in
            self?.prepareCache()
            DispatchQueue.main.async {
                if let self = self {
                    let result = Array(self.data)
                    completion?(result)
                    self.readyHandler?(result)
                }
            }
        }
        // Prepare timer.
        writeTimer = DispatchSource.makeTimerSource()
        writeTimer.schedule(deadline: .now() + .seconds(throttleDelay), repeating: .seconds(throttleDelay))
        writeTimer.setEventHandler { [weak self] in
            self?.persistIfNeeded()
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

    func persistIfNeeded() {

        if shouldPersist {
            self.persistCache()
        }
        DispatchQueue.main.async { [weak self] in
            self?.shouldPersist = false
        }
    }

    func prepareCache() {
        guard
            let jsonData = try? Data(contentsOf: fileUrl),
            let elements = try? decoder.decode([T].self, from: jsonData)
            else {
                self.data = Set<T>()
                return
        }
        self.data = Set(elements)

        if debugLog {
            print("JSON Store: Did load \(elements.count) elements from \(fileUrl.lastPathComponent).")
        }
    }

    func persistCache() {
        guard
            let encoded = try? encoder.encode(self.data)
            else { return }

        let filePath = fileUrl.relativePath
        fileManager.createFile(atPath: filePath, contents: encoded, attributes: nil)

        if debugLog {
            print("JSON Store: Wrote \(data.count) entries to \(fileUrl.lastPathComponent).")
        }
    }
}


extension JsonObjectStore: ObjectStore {

    typealias Element = T

    func ready(handler: (([T]) -> ())?) {
        self.readyHandler = handler
    }

    var elements: [T] {
        return Array(data)
    }

    func set(_ elements: [T]) {
        data = Set(elements)
    }

    func add(_ element: T) {
        data.insert(element)
    }

    func remove(_ element: T) {
        data.remove(element)
    }

    func clear() {
        data = Set<Element>()
    }
}

// MARK: - Extra methods for Identifiable elements.

@available(iOS 13, *)
extension JsonObjectStore where T: Identifiable {

    func removeElement(id: T.ID) {
        if let element = data.first(where: { $0.id == id }) {
            data.remove(element)
        }
    }

    func element(with id: T.ID) -> T? {
        return data.first(where: { $0.id == id })
    }
}

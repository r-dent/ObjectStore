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

    typealias ElementsReadyBlock = (Result<JsonObjectStore, Error>) -> ()

    private(set) var elements: Set<T>
    private let fileManager: FileManagerProtocol
    private let ioQueue = DispatchQueue(label: UUID().uuidString)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let throttleDelay: TimeInterval
    private let fileUrl: URL
    private let fileName: String

    private var isThrottling: Bool = false
    private var shouldPersist: Bool = false
    private var writeTimer: DispatchSourceTimer?

    var debugLog: Bool = false

    init(
        fileName: String = String(describing: T.self) + ".json",
        throttleDelay: TimeInterval = 2,
        fileManager: FileManagerProtocol = FileManager.default,
        enableLogging: Bool = false
    ) throws {

        self.fileName = fileName
        self.fileManager = fileManager
        self.throttleDelay = throttleDelay
        self.debugLog = enableLogging
        self.fileUrl = try JsonObjectStore.prepareFileUrl(for: fileName, using: fileManager)

        // Prepare cache.
        if let jsonData = try? Data(contentsOf: fileUrl) {

            let elements = try decoder.decode([T].self, from: jsonData)
            self.elements = Set(elements)
            log("Did load \(elements.count) elements from \(fileUrl.lastPathComponent).")
        } else {

            self.elements = Set<T>()
            log("Could not find file \(fileUrl.lastPathComponent). Starting with empty data.")
        }
    }

    deinit {
        stopWriteTimer()
    }

    static func create(
        fileName: String = String(describing: T.self) + ".json",
        fileManager: FileManagerProtocol = FileManager.default,
        throttleDelay: TimeInterval = 2,
        enableLogging: Bool = false,
        completion: @escaping ElementsReadyBlock
    ) {
        DispatchQueue.global().async {
            do {

                let db = try JsonObjectStore(
                    fileName: fileName,
                    throttleDelay: throttleDelay,
                    fileManager: fileManager,
                    enableLogging: enableLogging
                )
                DispatchQueue.main.async {
                    completion(.success(db))
                }
            } catch {

                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}

// MARK: - Data persistence.

private extension JsonObjectStore {

    static func prepareFileUrl(for fileName: String, using fileManager: FileManagerProtocol) throws -> URL {

        let appSupportDir = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let jsonDataDir = appSupportDir.appendingPathComponent("jsonData")

        if !fileManager.fileExists(atPath: jsonDataDir.relativePath) {
            try fileManager.createDirectory(at: jsonDataDir, withIntermediateDirectories: true, attributes: nil)
        }

        return jsonDataDir.appendingPathComponent(fileName)
    }

    func newDataAvailable() {

        shouldPersist = true
        if !isThrottling {
            startThrottledWriting()
        }
    }

    /// Writes the contents of the elements property do disk.
    func persistCache() {

        var encoded: Data?
        do {
            encoded = try encoder.encode(self.elements)
        } catch {
            shouldPersist = true
            log("♦️Error: \(error)")
            return
        }

        let filePath = fileUrl.relativePath
        let wrote = fileManager.createFile(atPath: filePath, contents: encoded, attributes: nil)

        if wrote {
            log("Wrote \(elements.count) entries to \(fileUrl.lastPathComponent).")
        } else {
            shouldPersist = true
            log("♦️Error writing file!")
        }
    }

    func startThrottledWriting() {

        isThrottling = true
        log("Start throttle")

        let delay = Int(round(throttleDelay))
        writeTimer = DispatchSource.makeTimerSource(flags: [], queue: ioQueue)
        writeTimer?.schedule(deadline: .now() + .milliseconds(.random(in: 50...100)), repeating: .seconds(delay))
        writeTimer?.setEventHandler { [weak self] in

            if self?.shouldPersist == true {
                self?.shouldPersist = false
                self?.persistCache()
            } else {
                self?.stopWriteTimer()
            }
        }
        writeTimer?.activate()
    }

    func stopWriteTimer() {

        writeTimer?.setEventHandler {}
        writeTimer?.cancel()
        writeTimer = nil

        isThrottling = false
        log("Stop throttle")
    }

    func log(_ text: @autoclosure () -> String) {
        
        if debugLog {
            print("💾 \(fileName): \(text())")
        }
    }
}

// MARK: - ObjectStore cornformance

extension JsonObjectStore: ObjectStore {

    typealias Element = T

    func insert(_ element: T) {

        let elementsBefore = self.elements
        self.elements.insert(element)
        if elementsBefore != elements { newDataAvailable() }
    }

    func update(with element: T) {

        self.elements.update(with: element)
        newDataAvailable()
    }

    func remove(_ element: T) {

        let elementsBefore = self.elements
        self.elements.remove(element)
        if elementsBefore != elements { newDataAvailable() }
    }

    func set(_ elements: Set<T>) {

        let shouldWrite = self.elements != elements
        self.elements = elements
        if shouldWrite { newDataAvailable() }
    }

    func remove(_ elements: Set<T>) {

        let elementsBefore = self.elements
        self.elements.subtract(elements)
        if elementsBefore != elements { newDataAvailable() }
    }

    func insert(_ elements: Set<T>) {

        let elementsBefore = self.elements
        self.elements.formUnion(elements)
        if elementsBefore != elements { newDataAvailable() }
    }
}

// MARK: - FileManagerProtocol

protocol FileManagerProtocol {

    func fileExists(atPath path: String) -> Bool
    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey : Any]?) -> Bool
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]?) throws
    func url(for directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask, appropriateFor url: URL?, create shouldCreate: Bool) throws -> URL
}

extension FileManager: FileManagerProtocol {}

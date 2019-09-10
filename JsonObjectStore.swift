//
//  JsonObjectStore.swift
//  RapScript
//
//  Created by Roman Gille on 09.09.19.
//  Copyright © 2019 RapScript. All rights reserved.
//

import Foundation

class JsonObjectStore {

    private var data: [String : [StorableObject]] = [:]
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let throttleDelay: Int = 2
    private var shouldPersist: [String: () -> ()] = [:]
    private var writeTimer: DispatchSourceTimer!

    var debugLog: Bool = false

    private lazy var jsonDirectory: URL = {
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

        return jsonDataDir
    }()

    init<T: StorableObject>(with elementTypes: [T.Type]) {
        // Prepare caches.
        for elementType in elementTypes {
            prepareCache(for: elementType)
        }
        // Prepare timer.
        writeTimer = DispatchSource.makeTimerSource()
        writeTimer.schedule(deadline: .now(), repeating: .seconds(throttleDelay))
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

    func key<T: StorableObject>(for elementType: T.Type) -> String {
        return String(describing: elementType)
    }

    // MARK: - Data persistence.

    private func persistIfNeeded() {
        guard !shouldPersist.isEmpty
            else { return }

        for (_, operation) in shouldPersist {
            operation()
        }
        DispatchQueue.main.async { [weak self] in
            self?.shouldPersist = [:]
        }
    }

    func shouldPersist<T: StorableObject>(elementsOf elementType: T.Type) {
        guard shouldPersist[key(for: elementType)] == nil
            else { return }
        shouldPersist[key(for: elementType)] = { [weak self] in self?.persistCache(for: elementType) }
    }

    func fileUrl<T: StorableObject>(for elementType: T.Type) -> URL {
        return jsonDirectory.appendingPathComponent("\(key(for: elementType)).json")
    }

    func prepareCache<T: StorableObject>(for elementType: T.Type) {
        let fileUrl = self.fileUrl(for: elementType)
        guard
            let jsonData = try? Data(contentsOf: fileUrl),
            let elements = try? decoder.decode(Array<T>.self, from: jsonData)
            else {
                data[key(for: elementType)] = Array<T>()
                return
        }
        data[key(for: elementType)] = elements

        if debugLog {
            print("Did load \(elements.count) elements from \(fileUrl.lastPathComponent).")
        }
    }

    func persistCache<T: StorableObject>(for elementType: T.Type) {
        guard
            let elements = data[key(for: elementType)] as? [T],
            let encoded = try? encoder.encode(elements)
            else { return }

        let fileUrl = self.fileUrl(for: elementType)
        let filePath = fileUrl.relativePath
        fileManager.createFile(atPath: filePath, contents: encoded, attributes: nil)

        if debugLog {
            print("Wrote \(elements.count) entries to \(fileUrl.lastPathComponent).")
        }
    }
}

// MARK: - ObjectStore conformance.

extension JsonObjectStore: ObjectStore {

    func add<T: StorableObject>(_ object: T) {
        let key = self.key(for: T.self)

        if let index = data[key]?.firstIndex(where: { $0.id == object.id }) {
            data[key]?.remove(at: index)
            data[key]?.insert(object, at: index)
        } else {
            data[key]?.append(object)
        }

        shouldPersist(elementsOf: T.self)
    }

    func remove<T: StorableObject>(_ object: T) {
        data[key(for: T.self)]?.removeAll(where: { $0.id == object.id })
        shouldPersist(elementsOf: T.self)
    }

    func all<T: StorableObject>() -> [T] {
        return all(of: T.self)
    }

    func all<T: StorableObject>(of elementType: T.Type) -> [T] {
        return (data[key(for: elementType)] as? [T]) ?? []
    }

    func element<T: StorableObject>(with id: Int) -> T? {
        return all(of: T.self).first(where: { $0.id == id })
    }

    func removeAll<T: StorableObject>(of elementType: T.Type) {
        data.removeValue(forKey: key(for: elementType))
        shouldPersist(elementsOf: elementType)
    }
}

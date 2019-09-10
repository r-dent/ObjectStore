//
//  JsonDatabase.swift
//  RapScript
//
//  Created by Roman Gille on 09.09.19.
//  Copyright © 2019 RapScript. All rights reserved.
//

import Foundation

class JsonDatabase {

    var data: [String : [CodableDbElement]] = [:]

    func key<T: CodableDbElement>(for elementType: T.Type) -> String {
        return String(describing: elementType)
    }

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let throttleDelay: Int = 2
    private var shouldPersist: [String: () -> ()] = [:]
    private var writeTimer: DispatchSourceTimer!

    private lazy var jsonWriteQueue: DispatchQueue = {
        return DispatchQueue(label: "json_write_queue")
    }()

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

    init<T: CodableDbElement>(with elementTypes: [T.Type]) {
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

    func shouldPersist<T: CodableDbElement>(elementsOf elementType: T.Type) {
        guard shouldPersist[key(for: elementType)] == nil
            else { return }
        shouldPersist[key(for: elementType)] = { [weak self] in self?.persistCache(for: elementType) }
    }

    func fileUrl<T: CodableDbElement>(for elementType: T.Type) -> URL {
        return jsonDirectory.appendingPathComponent("\(key(for: elementType)).json")
    }

    func prepareCache<T: CodableDbElement>(for elementType: T.Type) {
        let fileUrl = self.fileUrl(for: elementType)
        guard
            let jsonData = try? Data(contentsOf: fileUrl),
            let elements = try? decoder.decode(Array<T>.self, from: jsonData)
            else {
                data[key(for: elementType)] = Array<T>()
                return
        }
        data[key(for: elementType)] = elements
        print("Did load \(elements.count) elements from \(fileUrl.lastPathComponent).")
    }

    func persistCache<T: CodableDbElement>(for elementType: T.Type) {
        guard
            let elements = data[key(for: elementType)] as? [T],
            let encoded = try? encoder.encode(elements)
            else { return }
        let fileUrl = self.fileUrl(for: elementType)
        let filePath = fileUrl.relativePath
        fileManager.createFile(atPath: filePath, contents: encoded, attributes: nil)
        print("Wrote \(elements.count) entries to \(fileUrl.lastPathComponent).")
    }
}

extension JsonDatabase: Database {

    func add<T: CodableDbElement>(_ object: T) {
        let key = self.key(for: T.self)

        if let index = data[key]?.firstIndex(where: { $0.id == object.id }) {
            data[key]?.remove(at: index)
            data[key]?.insert(object, at: index)
        } else {
            data[key]?.append(object)
        }

        shouldPersist(elementsOf: T.self)
    }

    func remove<T: CodableDbElement>(_ object: T) {
        data[key(for: T.self)]?.removeAll(where: { $0.id == object.id })
        shouldPersist(elementsOf: T.self)
    }

    func all<T: CodableDbElement>() -> [T] {
        return all(of: T.self)
    }

    func all<T: CodableDbElement>(of elementType: T.Type) -> [T] {
        return (data[key(for: elementType)] as? [T]) ?? []
    }

    func element<T: CodableDbElement>(with id: Int) -> T? {
        return all(of: T.self).first(where: { $0.id == id })
    }

    func removeAll<T: CodableDbElement>(of elementType: T.Type) {
        data.removeValue(forKey: key(for: elementType))
        shouldPersist(elementsOf: elementType)
    }
}

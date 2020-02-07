//
//  FileManagerMock.swift
//  SimpleJsonDBTests
//
//  Created by Roman Gille on 07.02.20.
//  Copyright © 2020 Roman Gille. All rights reserved.
//

import Foundation
@testable import SimpleJsonDB

class FileManagerMock {

    struct MockError: Error {
        let message: String
    }

    var fileExists: Bool = true

    var shouldCreateDirectory: (URL) throws -> Void = { _ in }
    var shouldWriteFile: (String, Data?) -> Bool = { _, _ in true }
    var urlForDirectory: (FileManager.SearchPathDirectory, FileManager.SearchPathDomainMask) throws -> URL = { _, _ in
        URL(fileURLWithPath: "dummy")
    }
}

// MARK: - FileManagerProtocol

extension FileManagerMock: FileManagerProtocol {

    func fileExists(atPath path: String) -> Bool {
        fileExists
    }

    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey : Any]?) -> Bool {
        shouldWriteFile(path, data)
    }

    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]?) throws {
        try shouldCreateDirectory(url)
    }

    func url(for directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask, appropriateFor url: URL?, create shouldCreate: Bool) throws -> URL {
        try urlForDirectory(directory, domain)
    }
}

//
//  SimpleJsonDBTests.swift
//  SimpleJsonDBTests
//
//  Created by Roman Gille on 09.09.19.
//  Copyright © 2019 Roman Gille. All rights reserved.
//

import XCTest
@testable import SimpleJsonDB

class SimpleJsonDBTests: XCTestCase {

    var db: AnyObjectStore<TestData>?
    var fileManager: FileManagerMock!

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        self.fileManager = FileManagerMock()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {


        let sut = try? JsonObjectStore<TestData>(
            fileName: "AlphaDummy.json",
            throttleDelay: 1,
            fileManager: fileManager,
            enableLogging: false
        )
        XCTAssertNotNil(sut)

        let testElement = TestData(id: 1, name: "A", uuid: "bbb", float: 0)
        let dataWritten = XCTestExpectation(description: "Data Written")

        fileManager.shouldWriteFile = { path, data in
            if
                let elements = try? JSONDecoder().decode([TestData].self, from: data!),
                elements.first == testElement
            {
                dataWritten.fulfill()
            }
            return true
        }

        sut?.insert(testElement)

        wait(for: [dataWritten], timeout: 1)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}

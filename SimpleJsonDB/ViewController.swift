//
//  ViewController.swift
//  SimpleJsonDB
//
//  Created by Roman Gille on 09.09.19.
//  Copyright © 2019 Roman Gille. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    let elements: [Int] = Array(0..<9000)

    var db: AnyObjectStore<TestData>?
    var db1: AnyObjectStore<TestData>?

    override func viewDidLoad() {
        super.viewDidLoad()

        let start = Date()

        JsonObjectStore<TestData>.create(fileName: "testdata-1.json", enableLogging: true) { [weak self] result in

            switch result {
            case .success(let db):
                self?.db = AnyObjectStore(db)
                let delta = Date().timeIntervalSince(start)
                print(String(format: "VC: Data ready after %.2f seconds.", delta))
                print("Found \(db.elements.count) objects.")

            case .failure(let error):
                print("♦️Error loading objects from json file")
                print(error)
            }
        }

        let table = UITableView(frame: view.bounds)
        table.dataSource = self
        table.delegate = self
        view.addSubview(table)
        table.reloadData()

        let delta = Date().timeIntervalSince(start)
        print(String(format: "VC: TableView ready after %.2f seconds.", delta))

        JsonObjectStore<TestData>.create(enableLogging: true) { [weak self] result in

            if case .success(let db) = result {

                self?.db1 = AnyObjectStore(db)
                db.insert(TestData(id: 1, name: "Test C", uuid: UUID().uuidString, float: 20))
                print("Test 2: elements", db.elements)
                db.update(with: TestData(id: 1, name: "Test G", uuid: UUID().uuidString, float: 30))
                print("Test 2: elements", db.elements)
            }
        }
    }
}

struct TestData: Codable, Hashable {

    static func ==(lhs: TestData, rhs: TestData) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: Int
    let created: Date = Date()
    let name: String
    let uuid: String
    let float: Float
}

extension ViewController: UITableViewDelegate {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        db?.insert( TestData(
            id: Int(floor(scrollView.contentOffset.y)),
            name: "\(Int.random(in: 0...1000))",
            uuid: UUID().uuidString,
            float: .random(in: 1...5)
        ))
    }
}

extension ViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return elements.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        if let existingCell = tableView.dequeueReusableCell(withIdentifier: "cell") {
            cell = existingCell
        } else {
            cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        }

        cell.textLabel?.text = "Cell Number \(elements[indexPath.row])"
        return cell
    }
}


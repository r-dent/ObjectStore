#  Poor Persons Object Store

A simple class that stores lists of `Codable` objects to JSON files. Providing an easy to use persistence solution for small amounts of data. 

## Installation

Just copy [ObjectStore.swift](ObjectStore.swift) and [JsonObjectStore.swift](JsonObjectStore.swift) to your project.

## Usage

Make your datatypes conform to `Codable` and `ObjectStoreElement` by providing an `id` property.

```swift
struct TestData: Codable, ObjectStoreElement {
    let id: Int // Required by ObjectStoreElement protocol.
    let created: Date = Date()
    let name: String
    let uuid: String
    let float: Float
}
```

Create an ObjectStore for your types.

```swift
let db = JsonObjectStore(with: [TestData.self]) { store in
    let data: [TestData] = store.all()
    print("Found \(data.count) objects.")
}
```

Add objects to the store.

```swift
db.add(TestData(
    id: 3,
    name: "A Name",
    uuid: UUID().uuidString,
    float: 2.345
))
```

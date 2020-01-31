#  Poor Persons Object Store

A simple class that stores a list of `Codable` objects to a JSON file. Providing an easy to use persistence solution for small amounts of data. 

The ObjectStore will save the data to JSON files in the ApplicationSupport directory.

## Installation

Just copy the contents of the [Sources](Sources) folder to your project.

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
db = JsonObjectStore<TestData>(fileName: "testdata.json") { elements in
    print("Found \(elements.count) objects.")
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

//: Playground - noun: a place where people can play

import PMJSON

// Print some pretty output so we can eyeball it and make sure it looks good
let json: JSON = [
    "foo": "bar",
    "array": [1,2,3,4,5],
    "dict": [
        "color": "red",
        "fruit": "apple"
    ],
    "empty_dict": [:],
    "empty_array": []
]

print(JSON.encodeAsString(json, options: [.pretty]))

// Also try some Encodable output

struct Person: Encodable {
    let name: String
    let age: Int
    let isAlive: Bool
    let favoriteColors: [String]
    let fruitRatings: [String: String]
}

let person = Person(name: "Anne", age: 24, isAlive: true, favoriteColors: ["red", "green", "blue"], fruitRatings: ["apple": "good", "pear": "better", "banana": "great", "melon": "okay"])
try print(JSON.Encoder().encodeAsString(person, options: [.pretty]))

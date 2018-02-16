//
//  SwiftDecoderTests.swift
//  PMJSONTests
//
//  Created by Kevin Ballard on 2/15/18.
//  Copyright © 2018 Kevin Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import XCTest
import PMJSON

private struct Person: Decodable, Equatable {
    enum Color: String, Decodable {
        case red
        case green
        case blue
    }
    
    var name: String
    var age: Int
    var isAlive: Bool
    var favoriteColors: [Color]
    var fruitRatings: [String: Int]
    var birthstone: String?
    
    static func ==(lhs: Person, rhs: Person) -> Bool {
        return (lhs.name, lhs.age) == (rhs.name, rhs.age)
            && lhs.favoriteColors == rhs.favoriteColors
            && lhs.fruitRatings == rhs.fruitRatings
            && lhs.birthstone == rhs.birthstone
    }
}

final class SwiftDecoderTests: XCTestCase {
    func testBasicDecodeFromJSON() throws {
        let json: JSON = [
            "name": "Anne",
            "age": 23,
            "isAlive": true,
            "favoriteColors": ["red", "green", "blue"],
            "fruitRatings": [
                "apple": 3,
                "pear": 4,
                "orange": 2
            ],
            "birthstone": "Opal"
        ]
        
        let person = try JSON.Decoder().decode(Person.self, from: json)
        XCTAssertEqual(person, Person(name: "Anne", age: 23, isAlive: true, favoriteColors: [.red, .green, .blue], fruitRatings: ["apple": 3, "pear": 4, "orange": 2], birthstone: "Opal"))
    }
    
    func testDecodeFromData() throws {
        let json: JSON = [
            "name": "Anne",
            "age": 23,
            "isAlive": true,
            "favoriteColors": ["red", "green", "blue"],
            "fruitRatings": [
                "apple": 3,
                "pear": 4,
                "orange": 2
            ],
            "birthstone": "Opal"
        ]
        let data = JSON.encodeAsData(json)
        
        let person = try JSON.Decoder().decode(Person.self, from: data)
        XCTAssertEqual(person, Person(name: "Anne", age: 23, isAlive: true, favoriteColors: [.red, .green, .blue], fruitRatings: ["apple": 3, "pear": 4, "orange": 2], birthstone: "Opal"))
    }
    
    func testDecodeFromString() throws {
        let json: JSON = [
            "name": "Anne",
            "age": 23,
            "isAlive": true,
            "favoriteColors": ["red", "green", "blue"],
            "fruitRatings": [
                "apple": 3,
                "pear": 4,
                "orange": 2
            ],
            "birthstone": "Opal"
        ]
        let string = JSON.encodeAsString(json)
        
        let person = try JSON.Decoder().decode(Person.self, from: string)
        XCTAssertEqual(person, Person(name: "Anne", age: 23, isAlive: true, favoriteColors: [.red, .green, .blue], fruitRatings: ["apple": 3, "pear": 4, "orange": 2], birthstone: "Opal"))
    }
    
    func testDecodeFromJSONWithNilOptionalValue() throws {
        let json: JSON = [
            "name": "Anne",
            "age": 23,
            "isAlive": true,
            "favoriteColors": ["red", "green", "blue"],
            "fruitRatings": [
                "apple": 3,
                "pear": 4,
                "orange": 2
            ]
        ]
        
        let person = try JSON.Decoder().decode(Person.self, from: json)
        XCTAssertEqual(person, Person(name: "Anne", age: 23, isAlive: true, favoriteColors: [.red, .green, .blue], fruitRatings: ["apple": 3, "pear": 4, "orange": 2], birthstone: nil))
    }
    
    func testDecodeThrowsMissingKeyError() {
        let json: JSON = [
            "name": "Anne"
        ]
        
        XCTAssertThrowsError(try JSON.Decoder().decode(Person.self, from: json)) { (error) in
            switch error {
            case let DecodingError.keyNotFound(key, context):
                XCTAssertEqual(key.stringValue, "age")
                XCTAssertEqual(context.codingPath.map({ $0.stringValue }), [])
                switch context.underlyingError {
                case JSONError.missingOrInvalidType?:
                    break
                case let error:
                    XCTFail("Expected underlying error to be JSONError.missingOrInvalidType, found \(error as Any)")
                }
            default:
                XCTFail("Expected DecodingError.keyNotFound, found \(error)")
            }
        }
    }
}

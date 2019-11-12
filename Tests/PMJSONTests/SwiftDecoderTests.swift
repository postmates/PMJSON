//
//  SwiftDecoderTests.swift
//  PMJSONTests
//
//  Created by Lily Ballard on 2/15/18.
//  Copyright © 2018 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import XCTest
import PMJSON
import Foundation

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
    
    func testDecodeSingleValue() throws {
        let json: JSON = "red"
        let color = try JSON.Decoder().decode(Person.Color.self, from: json)
        XCTAssertEqual(color, .red)
    }
    
    // MARK: - KeyDecodingStrategy
    
    func testConvertFromSnakeCase() throws {
        var decoder = JSON.Decoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        func assertEqual(_ key: String, _ expected: String, file: StaticString = #file, line: UInt = #line) throws {
            let json: JSON = [key: true]
            let dict = try decoder.decode([String: Bool].self, from: json)
            XCTAssertEqual(dict, [expected: true], file: file, line: line)
        }
        
        try assertEqual("", "")
        try assertEqual("hello", "hello")
        try assertEqual("HELLO", "HELLO")
        try assertEqual("123", "123")
        try assertEqual("foo_bar", "fooBar")
        try assertEqual("one_two_three", "oneTwoThree")
        try assertEqual("__foo_bar__", "__fooBar__")
        try assertEqual("__foo___bar__", "__fooBar__")
        try assertEqual("_fooBar_", "_fooBar_")
        try assertEqual("_qux_fooBar_", "_quxFoobar_")
        try assertEqual("23_skidoo", "23Skidoo")
        try assertEqual("foo_u\u{308}ber", "fooU\u{308}ber")
        try assertEqual("ends_with_single_x", "endsWithSingleX")
    }
    
    private struct Person2: Decodable, Equatable {
        let name: String
        let isAlive: Bool
        let favoriteColors: [Color]
        let fruitRankings: [String: String]
        
        struct Color: Decodable, Equatable {
            let name: String
            let isVibrant: Bool
            
            static func ==(lhs: Color, rhs: Color) -> Bool {
                return (lhs.name, lhs.isVibrant) == (rhs.name, rhs.isVibrant)
            }
        }
        
        static func ==(lhs: Person2, rhs: Person2) -> Bool {
            return (lhs.name, lhs.isAlive) == (rhs.name, rhs.isAlive)
                && lhs.favoriteColors == rhs.favoriteColors
                && lhs.fruitRankings == rhs.fruitRankings
        }
    }
    
    private struct MyKey: CodingKey {
        let stringValue: String
        var intValue: Int? { return nil }
        init(stringValue: String) {
            self.stringValue = stringValue
        }
        init?(intValue: Int) {
            return nil
        }
    }
    
    func testDecodingConvertFromSnakeCase() throws {
        var decoder = JSON.Decoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let json: JSON = [
            "name": "Anne",
            "is_alive": true,
            "favorite_colors": [
                [
                    "name": "red",
                    "is_vibrant": true
                ],
                [
                    "name": "blue",
                    "is_vibrant": false
                ]
            ],
            "fruit_rankings": [
                "apple": "good",
                "not_a_fruit": "bad"
            ]
        ]
        XCTAssertEqual(try decoder.decode(Person2.self, from: json), Person2(name: "Anne", isAlive: true, favoriteColors: [Person2.Color(name: "red", isVibrant: true), Person2.Color(name: "blue", isVibrant: false)], fruitRankings: ["apple": "good", "notAFruit": "bad"]))
    }
    
    func testDecodingObjectConvertFromSnakeCase() throws {
        var decoder = JSON.Decoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // use default applyKeyDecodingStrategyToJSONObject
        do { // JSON
            let json = try decoder.decode(JSON.self, from: [[
                "foo": "bar",
                "camel_case": false
                ]])
            XCTAssertEqual(json, [[
                "foo": "bar",
                "camel_case": false
                ]])
        }
        do { // JSONObject
            let json = try decoder.decode([JSONObject].self, from: [[
                "foo": "bar",
                "camel_case": false
                ]])
            XCTAssertEqual(json, [[
                "foo": "bar",
                "camel_case": false
                ]])
        }
        decoder.applyKeyDecodingStrategyToJSONObject = true
        do { // JSON
            let json = try decoder.decode(JSON.self, from: [[
                "foo": "bar",
                "camel_case": true
                ]])
            XCTAssertEqual(json, [[
                "foo": "bar",
                "camelCase": true
                ]])
        }
        do { // JSONObject
            let json = try decoder.decode([JSONObject].self, from: [[
                "foo": "bar",
                "camel_case": true
                ]])
            XCTAssertEqual(json, [[
                "foo": "bar",
                "camelCase": true
                ]])
        }
    }
    
    func testDecodingCustom() throws {
        var decoder = JSON.Decoder()
        decoder.keyDecodingStrategy = .custom({ (codingPath, key) -> CodingKey in
            switch key.stringValue {
            case "shade" where codingPath.first?.stringValue == "favoriteColors":
                return MyKey(stringValue: "name")
            case "firstName":
                return MyKey(stringValue: "name")
            case let s where s.unicodeScalars.last == "!":
                return MyKey(stringValue: String(s.unicodeScalars.dropLast()))
            default:
                return key
            }
        })
        do {
            let person = try decoder.decode(Person2.self, from: [
                "firstName": "Anne",
                "isAlive!": true,
                "favoriteColors!": [
                    [
                        "shade": "red",
                        "isVibrant!": true
                    ],
                    [
                        "shade": "blue",
                        "isVibrant!": false
                    ]
                ],
                "fruitRankings!": [
                    "apple!": "good",
                    "notAFruit!": "bad"
                ]
                ])
            XCTAssertEqual(person, Person2(name: "Anne", isAlive: true, favoriteColors: [Person2.Color(name: "red", isVibrant: true), Person2.Color(name: "blue", isVibrant: false)], fruitRankings: ["apple": "good", "notAFruit": "bad"]))
        } catch {
            XCTFail("error: \(error)")
        }
    }
    
    func testDecodingObjectCustom() throws {
        var decoder = JSON.Decoder()
        decoder.keyDecodingStrategy = .custom({ (codingPath, key) -> CodingKey in
            return MyKey(stringValue: String(key.stringValue.unicodeScalars.dropLast()))
        })
        // use default applyKeyDecodingStrategyToJSONObject
        do { // JSON
            let json = try decoder.decode(JSON.self, from: [[
                "foo": "bar",
                "camelCase": true
                ]])
            XCTAssertEqual(json, [[
                "foo": "bar",
                "camelCase": true
                ]])
        }
        do { // JSONObject
            let json = try decoder.decode([JSONObject].self, from: [[
                "foo": "bar",
                "camelCase": true
                ]])
            XCTAssertEqual(json, [[
                "foo": "bar",
                "camelCase": true
                ]])
        }
        decoder.applyKeyDecodingStrategyToJSONObject = true
        do { // JSON
            let json = try decoder.decode(JSON.self, from: [[
                "foo": "bar",
                "camelCase": true
                ]])
            XCTAssertEqual(json, [[
                "fo": "bar",
                "camelCas": true
                ]])
        }
        do { // JSONObject
            let json = try decoder.decode([JSONObject].self, from: [[
                "foo": "bar",
                "camelCase": true
                ]])
            XCTAssertEqual(json, [[
                "fo": "bar",
                "camelCas": true
                ]])
        }
    }
    
    // MARK: - DateDecodingStrategy
    
    // round dates to the nearest millisecond to avoid floating point precision issues when
    // round-tripping through JSON
    
    func testDecodeDateDefaultStrategy() throws {
        let now = Date().millisecondRounded
        let decoder = JSON.Decoder()
        // don't assume the default format since that's up to Date, just encode it first
        let json = try JSON.Encoder().encodeAsJSON(now)
        let date = try decoder.decode(Date.self, from: json).millisecondRounded
        XCTAssertEqual(date, now)
    }
    
    func testDecodeDateSecondsSince1970() throws {
        let now = Date().millisecondRounded
        var decoder = JSON.Decoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let date = try decoder.decode(Date.self, from: JSON(now.timeIntervalSince1970)).millisecondRounded
        XCTAssertEqual(date, now)
    }
    
    func testDecodeDateMillisecondsSince1970() throws {
        let now = Date().millisecondRounded
        var decoder = JSON.Decoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let date = try decoder.decode(Date.self, from: JSON(now.timeIntervalSince1970 * 1000)).millisecondRounded
        XCTAssertEqual(date, now)
    }
    
    @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
    func testDecodeDateISO8601() throws {
        var decoder = JSON.Decoder()
        decoder.dateDecodingStrategy = .iso8601
        let date = try decoder.decode(Date.self, from: "2018-02-26T05:55:49Z" as JSON)
        XCTAssertEqual(date, Date(timeIntervalSinceReferenceDate: 541317349))
    }
    
    #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
    @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
    func testDecodeDateISO8601FractionalSeconds() throws {
        var decoder = JSON.Decoder()
        decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds
        do { // fractional seconds
            let date = try decoder.decode(Date.self, from: "2018-02-26T05:55:49.605Z" as JSON)
            XCTAssertEqual(date, Date(timeIntervalSinceReferenceDate: 541317349.605))
        }
        do { // no fractional seconds
            let date = try decoder.decode(Date.self, from: "2018-02-26T05:55:49Z" as JSON)
            XCTAssertEqual(date, Date(timeIntervalSinceReferenceDate: 541317349))
        }
    }
    #endif
    
    func testDecodeDateFormatted() throws {
        var decoder = JSON.Decoder()
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .long
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        decoder.dateDecodingStrategy = .formatted(formatter)
        let date = try decoder.decode(Date.self, from: "February 25, 2018 at 10:08:00 PM PST" as JSON)
        XCTAssertEqual(date, Date(timeIntervalSinceReferenceDate: 541318080))
    }
    
    func testDecodeDateCustom() throws {
        var decoder = JSON.Decoder()
        decoder.dateDecodingStrategy = .custom({ (decoder) -> Date in
            let container = try decoder.singleValueContainer()
            return Date(timeIntervalSinceReferenceDate: try container.decode(Double.self) + 1000)
        })
        let date = try decoder.decode(Date.self, from: 541317080)
        XCTAssertEqual(date, Date(timeIntervalSinceReferenceDate: 541318080))
    }
    
    // MARK: - DataDecodingStrategy
    
    func testDecodeDataDefaultStrategy() throws {
        let input = "hello".data(using: .utf8)!
        let decoder = JSON.Decoder()
        // don't assume the default format since that's up to Data, just encode it first
        let json = try JSON.Encoder().encodeAsJSON(input)
        let data = try decoder.decode(Data.self, from: json)
        XCTAssertEqual(data, input)
    }
    
    func testDecodeDataBase64() throws {
        var decoder = JSON.Decoder()
        decoder.dataDecodingStrategy = .base64
        let data = try decoder.decode(Data.self, from: "aGVsbG8=" as JSON)
        XCTAssertEqual(data, "hello".data(using: .utf8)!)
    }
    
    func testDecodeDataCustom() throws {
        var decoder = JSON.Decoder()
        decoder.dataDecodingStrategy = .custom({ (decoder) -> Data in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            guard let data = Data(base64Encoded: String(str.reversed())) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Could not decode Data.")
            }
            return data
        })
        let data = try decoder.decode(Data.self, from: "=8GbsVGa" as JSON)
        XCTAssertEqual(data, "hello".data(using: .utf8)!)
    }
    
    // MARK: - Other custom decoding
    
    func testDecodeURL() {
        XCTAssertNoThrow(try {
            let data = try JSON.Decoder().decode(URL.self, from: "\"http://example.com\"")
            XCTAssertEqual(data, URL(string: "http://example.com")!)
            }())
        XCTAssertThrowsError(try JSON.Decoder().decode(URL.self, from: "\"foo bar\"")) { (error) in
            switch error {
            case DecodingError.dataCorrupted(let context):
                XCTAssertEqual(context.debugDescription, "Invalid URL string.")
            case let error:
                XCTFail("Expected DecodingError.dataCorrupted, found \(error)")
            }
        }
    }
    
    func testDecodeURLEncodedFromFoundation() {
        // Double-check that encoding URLs using JSONEncoder can be decoded with JSON.Decoder.
        func test(_ url: URL, line: UInt = #line) {
            XCTAssertNoThrow(try {
                let data = try JSONEncoder().encode(["url": url])
                let decoded = try JSON.Decoder().decode(Dictionary<String, URL>.self, from: data)["url"]!
                XCTAssertEqual(decoded, url.absoluteURL, line: line)
                }(), line: line)
        }
        test(URL(string: "http://example.com")!)
        test(URL(string: "foo", relativeTo: URL(string: "http://example.com")!)!)
        test(URL(string: "https://example.com/bar%20baz?q=a+b")!)
        
        // https://bugs.swift.org/browse/SR-11780
        // Decoding empty URLs throws an error. This happens with JSONDecoder as well as JSON.Decoder.
        // Let's validate here that both behave this way.
        func testThrowsError(_ block: () throws -> Void, line: UInt = #line) {
            XCTAssertThrowsError(try block(), line: line) { (error) in
                switch error {
                case DecodingError.dataCorrupted(let context):
                    XCTAssertEqual(context.debugDescription, "Invalid URL string.")
                case let error:
                    XCTFail("Expected DecodingError.dataCorrupted, found \(error)")
                }
            }
        }
        testThrowsError({
            let data = try JSONEncoder().encode(["url": NSURL(string: "")! as URL])
            _ = try JSONDecoder().decode(Dictionary<String, URL>.self, from: data)["url"]!
        })
        testThrowsError({
            let data = try JSONEncoder().encode(["url": NSURL(string: "")! as URL])
            _ = try JSON.Decoder().decode(Dictionary<String, URL>.self, from: data)["url"]!
        })
    }
}

private extension Date {
    /// Returns a `Date` where the underlying time interval has been rounded to the nearest millisecond.
    var millisecondRounded: Date {
        return Date(timeIntervalSinceReferenceDate: (self.timeIntervalSinceReferenceDate * 1000).rounded() / 1000)
    }
}

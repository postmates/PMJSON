//
//  SwiftEncoderTests.swift
//  PMJSONTests
//
//  Created by Kevin Ballard on 2/18/18.
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

private struct Person: Encodable, Equatable {
    enum Color: String, Encodable {
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

private struct Wrapper<Value: Encodable>: Encodable {
    let value: Value
}

final class SwiftEncoderTests: XCTestCase {
    let encoder = JSON.Encoder()
    
    private func assertEncodedJSON<T: Encodable>(for value: T, equals expected: JSON, file: StaticString = #file, line: UInt = #line) throws {
        do { // encodeAsJSON
            let json = try encoder.encodeAsJSON(value)
            XCTAssertEqual(json, expected, "encodeAsJSON", file: file, line: line)
        }
        do { // encodeAsString
            let jsonStr = try encoder.encodeAsString(value)
            let json = try JSON.decode(jsonStr)
            XCTAssertEqual(json, expected, "encodeAsString", file: file, line: line)
        }
        do { // encodeAsData
            let jsonData = try encoder.encodeAsData(value)
            let json = try JSON.decode(jsonData)
            XCTAssertEqual(json, expected, "encodeAsData", file: file, line: line)
        }
    }
    
    func testBasicEncode() throws {
        let person = Person(name: "Anne", age: 24, isAlive: true, favoriteColors: [.red, .green, .blue], fruitRatings: ["apple": 3, "pear": 4, "banana": 5], birthstone: "opal")
        try assertEncodedJSON(for: person, equals: [
            "name": "Anne",
            "age": 24,
            "isAlive": true,
            "favoriteColors": ["red", "green", "blue"],
            "fruitRatings": ["apple": 3, "pear": 4, "banana": 5],
            "birthstone": "opal"
            ])
    }
    
    func testEncodeOptional() throws {
        let person = Person(name: "Anne", age: 24, isAlive: true, favoriteColors: [.red, .green, .blue], fruitRatings: ["apple": 3, "pear": 4, "banana": 5], birthstone: nil)
        try assertEncodedJSON(for: person, equals: [
            "name": "Anne",
            "age": 24,
            "isAlive": true,
            "favoriteColors": ["red", "green", "blue"],
            "fruitRatings": ["apple": 3, "pear": 4, "banana": 5]
            ])
    }
    
    func testEncodePrimitve() throws {
        try assertEncodedJSON(for: 42, equals: 42)
    }
    
    func testEncodeNull() throws {
        struct Object: Encodable {
            enum CodingKeys: String, CodingKey {
                case value
            }
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeNil(forKey: .value)
            }
        }
        
        try assertEncodedJSON(for: Object(), equals: ["value": nil])
    }
    
    func testEncodeJSONValue() throws {
        let wrapper = Wrapper<JSON>(value: [
            "foo": "bar",
            "xs": [1,2,3,4,5]
            ])
        let json = try encoder.encodeAsJSON(wrapper)
        XCTAssertEqual(json, ["value": wrapper.value])
    }
    
    func testEncodeDecimal() throws {
        let wrapper = Wrapper<Decimal>(value: 12.34)
        try assertEncodedJSON(for: wrapper, equals: ["value": .decimal(12.34)])
    }
    
    // MARK: -
    
    func testEncodeAsString() throws {
        let wrapper = Wrapper<String>(value: "foo")
        let json = try encoder.encodeAsString(wrapper)
        XCTAssertEqual(json, "{\"value\":\"foo\"}")
    }
    
    func testEncodeAsStringWithOptions() throws {
        let wrapper = Wrapper<String>(value: "foo")
        let json = try encoder.encodeAsString(wrapper, options: [.pretty])
        XCTAssertEqual(json, "{\n  \"value\": \"foo\"\n}")
    }
    
    func testEncodePrimitiveAsString() throws {
        let json = try encoder.encodeAsString(42)
        XCTAssertEqual(json, "42")
    }
    
    func testEncodeAsData() throws {
        let wrapper = Wrapper<String>(value: "foo")
        let json = try encoder.encodeAsData(wrapper)
        XCTAssertEqual(json, "{\"value\":\"foo\"}".data(using: .utf8)!)
    }
    
    func testEncodeAsDataWithOptions() throws {
        let wrapper = Wrapper<String>(value: "foo")
        let json = try encoder.encodeAsData(wrapper, options: [.pretty])
        XCTAssertEqual(json, "{\n  \"value\": \"foo\"\n}".data(using: .utf8)!)
    }
    
    // MARK: -
    
    func testObjectMultipleContainersSameKeyEncoder() throws {
        struct Object: Encodable {
            enum CodingKeys: String, CodingKey {
                case name
                case age
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode("Anne", forKey: .name)
                try container.encode(24, forKey: .age)
                try Child().encode(to: encoder)
            }
            
            struct Child: Encodable {
                enum CodingKeys: String, CodingKey {
                    case color
                    case fruit
                }
                
                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode("red", forKey: .color)
                    try container.encode("banana", forKey: .fruit)
                }
            }
        }
        try assertEncodedJSON(for: Object(), equals: [
            "name": "Anne",
            "age": 24,
            "color": "red",
            "fruit": "banana"
            ])
    }
    
    func testObjectMultipleContainersSameKeyConcurrentlyEncoder() throws {
        struct Object: Encodable {
            enum CodingKeys1: String, CodingKey {
                case name
                case age
            }
            enum CodingKeys2: String, CodingKey {
                case color
                case fruit
            }
            
            func encode(to encoder: Encoder) throws {
                var container1 = encoder.container(keyedBy: CodingKeys1.self)
                try container1.encode("Anne", forKey: .name)
                var container2 = encoder.container(keyedBy: CodingKeys2.self)
                try container2.encode("red", forKey: .color)
                try container1.encode(24, forKey: .age)
                try container2.encode("banana", forKey: .fruit)
            }
        }
        try assertEncodedJSON(for: Object(), equals: [
            "name": "Anne",
            "age": 24,
            "color": "red",
            "fruit": "banana"
            ])
    }
    
    // MARK: - Nested encoders
    
    func testObjectNestedKeyedEncoder() throws {
        struct Object: Encodable {
            enum CodingKeys: String, CodingKey {
                case name
                case nested
            }
            enum NestedCodingKeys: String, CodingKey {
                case color
                case age
            }
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode("Anne", forKey: .name)
                var nested = container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .nested)
                try nested.encode("red", forKey: .color)
                try nested.encode(24, forKey: .age)
            }
        }
        try assertEncodedJSON(for: Object(), equals: [
            "name": "Anne",
            "nested": [
                "color": "red",
                "age": 24
            ]
            ])
    }
    
    func testObjectNestedUnkeyedEncoder() throws {
        struct Object: Encodable {
            enum CodingKeys: String, CodingKey {
                case name
                case nested
            }
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode("Anne", forKey: .name)
                var nested = container.nestedUnkeyedContainer(forKey: .nested)
                try nested.encode("foo")
                try nested.encode(42)
            }
        }
        try assertEncodedJSON(for: Object(), equals: [
            "name": "Anne",
            "nested": ["foo", 42]
            ])
    }
    
    func testObjectNestedKeyedEncoderOverwritten() throws {
        struct Object: Encodable {
            enum CodingKeys: String, CodingKey {
                case name
                case nested
            }
            enum NestedCodingKeys: String, CodingKey {
                case color
                case age
            }
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode("Anne", forKey: .name)
                var nested = container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .nested)
                try container.encode("foo", forKey: .nested) // this overwrites the nested container
                try nested.encode("red", forKey: .color) // these two lines should have no effect
                try nested.encode(24, forKey: .age)
            }
        }
        try assertEncodedJSON(for: Object(), equals: [
            "name": "Anne",
            "nested": "foo"
            ])
    }
    
    func testArrayNestedKeyedEncoder() throws {
        struct Object: Encodable {
            enum NestedCodingKeys: String, CodingKey {
                case color
                case age
            }
            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                try container.encode("Anne")
                var nested = container.nestedContainer(keyedBy: NestedCodingKeys.self)
                try nested.encode("red", forKey: .color)
                try nested.encode(24, forKey: .age)
            }
        }
        try assertEncodedJSON(for: Object(), equals: ["Anne", ["color": "red", "age": 24]])
    }
    
    func testArrayNestedUnkeyedEncoder() throws {
        struct Object: Encodable {
            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                try container.encode("Anne")
                var nested = container.nestedUnkeyedContainer()
                try nested.encode("red")
                try nested.encode(24)
            }
        }
        try assertEncodedJSON(for: Object(), equals: ["Anne", ["red", 24]])
    }
    
    // MARK: - Super encoders
    
    func testObjectSuperSingleValueEncoder() throws {
        class Parent: Encodable {
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode("foo")
            }
        }
        class Child: Parent {
            enum CodingKeys: String, CodingKey {
                case name
            }
            override func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode("Anne", forKey: .name)
                try super.encode(to: container.superEncoder())
            }
        }
        try assertEncodedJSON(for: Child(), equals: [
            "name": "Anne",
            "super": "foo",
            ])
    }
    
    func testObjectKeyedSuperSingleValueEncoder() throws {
        class Parent: Encodable {
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode("foo")
            }
        }
        class Child: Parent {
            enum CodingKeys: String, CodingKey {
                case name
                case otherSuper
            }
            override func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode("Anne", forKey: .name)
                try super.encode(to: container.superEncoder(forKey: .otherSuper))
            }
        }
        try assertEncodedJSON(for: Child(), equals: [
            "name": "Anne",
            "otherSuper": "foo"
            ])
    }
    
    func testObjectSuperKeyedEncoder() throws {
        class Parent: Encodable {
            enum CodingKeys: String, CodingKey {
                case name
            }
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode("Anne", forKey: .name)
            }
        }
        class Child: Parent {
            enum ChildCodingKeys: String, CodingKey {
                case age
            }
            override func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: ChildCodingKeys.self)
                try container.encode(24, forKey: .age)
                try super.encode(to: container.superEncoder())
            }
        }
        try assertEncodedJSON(for: Child(), equals: [
            "age": 24,
            "super": [
                "name": "Anne"
            ]
            ])
    }
    
    func testObjectSuperUnkeyedEncoder() throws {
        class Parent: Encodable {
            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                try container.encode("foo")
                try container.encode(42)
            }
        }
        class Child: Parent {
            enum CodingKeys: String, CodingKey {
                case age
            }
            override func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(24, forKey: .age)
                try super.encode(to: container.superEncoder())
            }
        }
        try assertEncodedJSON(for: Child(), equals: [
            "age": 24,
            "super": ["foo", 42]
            ])
    }
    
    func testObjectDeferredSuperEncoder() throws {
        class Parent: Encodable {
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode("foo")
            }
        }
        class Child: Parent {
            enum CodingKeys: String, CodingKey {
                case name
            }
            override func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                let superEncoder = container.superEncoder()
                try container.encode("Anne", forKey: .name)
                try super.encode(to: superEncoder)
            }
        }
        try assertEncodedJSON(for: Child(), equals: [
            "name": "Anne",
            "super": "foo",
            ])
    }
    
    func testObjectDeferredSuperOverwrittenEncoder() throws {
        class Parent: Encodable {
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode("foo")
            }
        }
        class Child: Parent {
            enum CodingKeys: String, CodingKey {
                case name
                case `super`
            }
            override func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                let superEncoder = container.superEncoder() // this line reserves "super"
                try container.encode("Anne", forKey: .name)
                try container.encode("bar", forKey: .super) // this line overwrites "super"
                try super.encode(to: superEncoder) // this line should have no effect on the result
            }
        }
        try assertEncodedJSON(for: Child(), equals: [
            "name": "Anne",
            "super": "bar",
            ])
    }
    
    func testArraySuperSingleValueEncoder() throws {
        class Parent: Encodable {
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode("foo")
            }
        }
        class Child: Parent {
            override func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                try container.encode("Anne")
                try super.encode(to: container.superEncoder())
            }
        }
        try assertEncodedJSON(for: Child(), equals: ["Anne", "foo"])
    }
    
    func testArraySuperObjectEncoder() throws {
        class Parent: Encodable {
            enum CodingKeys: String, CodingKey {
                case name
            }
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode("Anne", forKey: .name)
            }
        }
        class Child: Parent {
            override func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                try container.encode(24)
                try super.encode(to: container.superEncoder())
                try container.encode(42)
            }
        }
        try assertEncodedJSON(for: Child(), equals: [24, ["name": "Anne"], 42])
    }
    
    // MARK: - KeyEncodingStrategy
    
    func testConvertToSnakeCase() throws {
        var encoder = JSON.Encoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        func assertEqual(_ key: String, _ expected: String, file: StaticString = #file, line: UInt = #line) throws {
            let dict: [String: Bool] = [key: true]
            let json = try encoder.encodeAsJSON(dict)
            XCTAssertEqual(json, [expected: true], file: file, line: line)
        }
        
        try assertEqual("", "")
        try assertEqual("hello", "hello")
        try assertEqual("HELLO", "hello")
        try assertEqual("123", "123")
        try assertEqual("fooBar", "foo_bar")
        try assertEqual("oneTwoThree", "one_two_three")
        try assertEqual("URLForConfig", "url_for_config")
        try assertEqual("_oneTwoThree_", "_one_two_three_")
        try assertEqual("one_two_three", "one_two_three")
        try assertEqual("23Skidoo", "23_skidoo")
        try assertEqual("ABC123", "abc123")
        try assertEqual("ABC123def", "abc123_def")
        try assertEqual("A1sauce", "a1_sauce")
        try assertEqual("A1Sauce", "a1_sauce")
        try assertEqual("A1B2C3", "a1b2c3")
        try assertEqual("foo12Bar", "foo12_bar")
        try assertEqual("endsWithSingleX", "ends_with_single_x")
        try assertEqual("fooU\u{308}ber", "foo_u\u{308}ber")
    }
    
    func testEncodingConvertToSnakeCase() throws {
        struct Person: Encodable {
            let name: String
            let isAlive: Bool
            let favoriteColors: [Color]
            let fruitRankings: [String: String]
        }
        struct Color: Encodable {
            let name: String
            let isVibrant: Bool
        }
        
        var encoder = JSON.Encoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let json = try encoder.encodeAsJSON(Person(name: "Anne", isAlive: true, favoriteColors: [Color(name: "red", isVibrant: true), Color(name: "blue", isVibrant: false)], fruitRankings: ["apple": "good", "notAFruit": "bad"]))
        XCTAssertEqual(json, [
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
            ])
    }
    
    func testEncodingObjectConvertToSnakeCase() throws {
        var encoder = JSON.Encoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        // use default applyKeyEncodingStrategyToJSONObject
        do { // JSON
            let json = try encoder.encodeAsJSON([[
                "foo": "bar",
                "camelCase": true
                ]] as JSON)
            XCTAssertEqual(json, [[
                "foo": "bar",
                "camelCase": true
                ]])
        }
        do { // JSONObject
            let json = try encoder.encodeAsJSON([[
                "foo": "bar",
                "camelCase": true
                ] as JSONObject])
            XCTAssertEqual(json, [[
                "foo": "bar",
                "camelCase": true
                ]])
        }
        encoder.applyKeyEncodingStrategyToJSONObject = true
        do { // JSON
            let json = try encoder.encodeAsJSON([[
                "foo": "bar",
                "camelCase": false
                ]] as JSON)
            XCTAssertEqual(json, [[
                "foo": "bar",
                "camel_case": false
                ]])
        }
        do { // JSONObject
            let json = try encoder.encodeAsJSON([[
                "foo": "bar",
                "camelCase": false
                ] as JSONObject])
            XCTAssertEqual(json, [[
                "foo": "bar",
                "camel_case": false
                ]])
        }
    }
    
    func testEncodingCustom() throws {
        struct Person: Encodable {
            let name: String
            let isAlive: Bool
            let favoriteColors: [Color]
            let fruitRankings: [String: String]
        }
        struct Color: Encodable {
            let name: String
            let isVibrant: Bool
        }
        struct MyKey: CodingKey {
            let stringValue: String
            var intValue: Int? { return nil }
            init(stringValue: String) {
                self.stringValue = stringValue
            }
            init?(intValue: Int) {
                return nil
            }
        }
        var encoder = JSON.Encoder()
        encoder.keyEncodingStrategy = .custom({ (codingPath, key) -> CodingKey in
            switch key.stringValue {
            case "name":
                if codingPath.first?.stringValue == "favoriteColors" {
                    return MyKey(stringValue: "shade")
                } else {
                    return MyKey(stringValue: "firstName")
                }
            case let s:
                return MyKey(stringValue: "\(s)!")
            }
        })
        let json = try encoder.encodeAsJSON(Person(name: "Anne", isAlive: true, favoriteColors: [Color(name: "red", isVibrant: true), Color(name: "blue", isVibrant: false)], fruitRankings: ["apple": "good", "notAFruit": "bad"]))
        XCTAssertEqual(json, [
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
    }
    
    func testEncodingObjectCustom() throws {
        struct MyKey: CodingKey {
            let stringValue: String
            var intValue: Int? { return nil }
            init(stringValue: String) {
                self.stringValue = stringValue
            }
            init?(intValue: Int) {
                return nil
            }
        }
        var encoder = JSON.Encoder()
        encoder.keyEncodingStrategy = .custom({ (codingPath, key) -> CodingKey in
            return MyKey(stringValue: key.stringValue + "!")
        })
        // use default applyKeyEncodingStrategyToJSONObject
        do { // JSON
            let json = try encoder.encodeAsJSON([[
                "foo": "bar",
                "camelCase": true
                ]] as JSON)
            XCTAssertEqual(json, [[
                "foo": "bar",
                "camelCase": true
                ]])
        }
        do { // JSONObject
            let json = try encoder.encodeAsJSON([[
                "foo": "bar",
                "camelCase": true
                ] as JSONObject])
            XCTAssertEqual(json, [[
                "foo": "bar",
                "camelCase": true
                ]])
        }
        encoder.applyKeyEncodingStrategyToJSONObject = true
        do { // JSON
            let json = try encoder.encodeAsJSON([[
                "foo": "bar",
                "camelCase": false
                ]] as JSON)
            XCTAssertEqual(json, [[
                "foo!": "bar",
                "camelCase!": false
                ]])
        }
        do { // JSONObject
            let json = try encoder.encodeAsJSON([[
                "foo": "bar",
                "camelCase": false
                ] as JSONObject])
            XCTAssertEqual(json, [[
                "foo!": "bar",
                "camelCase!": false
                ]])
        }
    }
    
    // MARK: - DateDecodingStrategy
    
    // round dates to the nearest millisecond to avoid floating point precision issues when
    // round-tripping through JSON
    
    func testEncodeDateDefaultStrategy() throws {
        let now = Date().millisecondRounded
        let encoder = JSON.Encoder()
        // don't assume the default format since that's up to Date, just decode it after
        let json = try encoder.encodeAsJSON(now)
        let date = try JSON.Decoder().decode(Date.self, from: json)
        XCTAssertEqual(date, now)
    }
    
    func testEncodeDateSecondsSince1970() throws {
        let now = Date().millisecondRounded
        var encoder = JSON.Encoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let json = try encoder.encodeAsJSON(now)
        XCTAssertEqual(json, JSON(now.timeIntervalSince1970))
    }
    
    func testEncodeDateMillisecondsSince1970() throws {
        let now = Date().millisecondRounded
        var encoder = JSON.Encoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let json = try encoder.encodeAsJSON(now)
        XCTAssertEqual(json, JSON(now.timeIntervalSince1970 * 1000))
    }
    
    @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
    func testEncodeDateISO8601() throws {
        var encoder = JSON.Encoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encodeAsJSON(Date(timeIntervalSinceReferenceDate: 541317349))
        XCTAssertEqual(json, "2018-02-26T05:55:49Z")
    }
    
    #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
    @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
    func testEncodeDateISO8601FractionalSeconds() throws {
        var encoder = JSON.Encoder()
        encoder.dateEncodingStrategy = .iso8601WithFractionalSeconds
        let json = try encoder.encodeAsJSON(Date(timeIntervalSinceReferenceDate: 541317349.605))
        XCTAssertEqual(json, "2018-02-26T05:55:49.605Z")
    }
    #endif
    
    func testEncodeDateFormatted() throws {
        var encoder = JSON.Encoder()
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .long
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        encoder.dateEncodingStrategy = .formatted(formatter)
        let json = try encoder.encodeAsJSON(Date(timeIntervalSinceReferenceDate: 541318080))
        XCTAssertEqual(json, "February 25, 2018 at 10:08:00 PM PST")
    }
    
    func testEncodedDateCustom() throws {
        var encoder = JSON.Encoder()
        encoder.dateEncodingStrategy = .custom({ (date, encoder) in
            var container = encoder.singleValueContainer()
            try container.encode(date.timeIntervalSinceReferenceDate - 1000)
        })
        let json = try encoder.encodeAsJSON(Date(timeIntervalSinceReferenceDate: 541318080))
        XCTAssertEqual(json, 541317080)
    }
    
    func testEncodedDateCustomNoEncode() throws {
        var encoder = JSON.Encoder()
        encoder.dateEncodingStrategy = .custom({ (date, encoder) in
            // do nothing
        })
        let json = try encoder.encodeAsJSON(Date())
        XCTAssertEqual(json, [:])
    }
}

private extension Date {
    /// Returns a `Date` where the underlying time interval has been rounded to the nearest millisecond.
    var millisecondRounded: Date {
        return Date(timeIntervalSinceReferenceDate: (self.timeIntervalSinceReferenceDate * 1000).rounded() / 1000)
    }
}

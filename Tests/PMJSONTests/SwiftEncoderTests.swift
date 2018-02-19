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
    
    func testBasicEncode() throws {
        let person = Person(name: "Anne", age: 24, isAlive: true, favoriteColors: [.red, .green, .blue], fruitRatings: ["apple": 3, "pear": 4, "banana": 5], birthstone: "opal")
        let json = try encoder.encodeAsJSON(person)
        XCTAssertEqual(json, [
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
        let json = try encoder.encodeAsJSON(person)
        XCTAssertEqual(json, [
            "name": "Anne",
            "age": 24,
            "isAlive": true,
            "favoriteColors": ["red", "green", "blue"],
            "fruitRatings": ["apple": 3, "pear": 4, "banana": 5]
            ])
    }
    
    func testEncodePrimitve() throws {
        let json = try encoder.encodeAsJSON(42)
        XCTAssertEqual(json, 42)
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
        
        let json = try encoder.encodeAsJSON(Object())
        XCTAssertEqual(json, ["value": nil])
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
        let json = try encoder.encodeAsJSON(wrapper)
        XCTAssertEqual(json, ["value": .decimal(12.34)])
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
        
        let json = try encoder.encodeAsJSON(Object())
        XCTAssertEqual(json, [
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
        
        let json = try encoder.encodeAsJSON(Object())
        XCTAssertEqual(json, [
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
        let json = try encoder.encodeAsJSON(Object())
        XCTAssertEqual(json, [
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
        let json = try encoder.encodeAsJSON(Object())
        XCTAssertEqual(json, [
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
        let json = try encoder.encodeAsJSON(Object())
        XCTAssertEqual(json, [
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
        let json = try encoder.encodeAsJSON(Object())
        XCTAssertEqual(json, ["Anne", ["color": "red", "age": 24]])
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
        let json = try encoder.encodeAsJSON(Object())
        XCTAssertEqual(json, ["Anne", ["red", 24]])
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
        let json = try encoder.encodeAsJSON(Child())
        XCTAssertEqual(json, [
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
        let json = try encoder.encodeAsJSON(Child())
        XCTAssertEqual(json, [
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
        let json = try encoder.encodeAsJSON(Child())
        XCTAssertEqual(json, [
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
        let json = try encoder.encodeAsJSON(Child())
        XCTAssertEqual(json, [
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
        let json = try encoder.encodeAsJSON(Child())
        XCTAssertEqual(json, [
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
        let json = try encoder.encodeAsJSON(Child())
        XCTAssertEqual(json, [
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
        let json = try encoder.encodeAsJSON(Child())
        XCTAssertEqual(json, ["Anne", "foo"])
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
        let json = try encoder.encodeAsJSON(Child())
        XCTAssertEqual(json, [24, ["name": "Anne"], 42])
    }
}

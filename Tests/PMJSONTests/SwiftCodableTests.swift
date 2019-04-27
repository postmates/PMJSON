//
//  SwiftCodableTests.swift
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

final class SwiftEncodableTests: XCTestCase {
    let encoder = JSONEncoder()
    
    func testNull() throws {
        let data = try encoder.encode(ValueWrapper(nil))
        let json = try JSON.decode(data)
        XCTAssertEqual(json, ["value": nil])
    }
    
    func testBool() throws {
        let data = try encoder.encode(ValueWrapper(true))
        let json = try JSON.decode(data)
        XCTAssertEqual(json, ["value": true])
    }
    
    func testString() throws {
        let data = try encoder.encode(ValueWrapper("foo"))
        let json = try JSON.decode(data)
        XCTAssertEqual(json, ["value": "foo"])
    }
    
    func testInt64() throws {
        let data = try encoder.encode(ValueWrapper(.int64(1234)))
        let json = try JSON.decode(data)
        XCTAssertEqual(json, ["value": 1234])
    }
    
    func testDouble() throws {
        let data = try encoder.encode(ValueWrapper(.double(12.5)))
        let json = try JSON.decode(data)
        XCTAssertEqual(json, ["value": 12.5])
    }
    
    func testDecimal() throws {
        let data = try encoder.encode(ValueWrapper(.decimal(10)))
        let json = try JSON.decode(data)
        XCTAssertEqual(json, ["value": 10])
    }
    
    func testObject() throws {
        let data = try encoder.encode(["foo": "bar"] as JSON)
        let json = try JSON.decode(data)
        XCTAssertEqual(json, ["foo": "bar"])
    }
    
    func testArray() throws {
        let data = try encoder.encode(["foo", "bar"] as JSON)
        let json = try JSON.decode(data)
        XCTAssertEqual(json, ["foo", "bar"])
    }
}

final class SwiftDecodableTests: XCTestCase {
    let decoder = JSONDecoder()
    
    func testNull() throws {
        let data = JSON.encodeAsData(["value": nil])
        let wrapper = try decoder.decode(ValueWrapper.self, from: data)
        XCTAssertEqual(wrapper.value, nil)
    }
    
    func testBool() throws {
        let data = JSON.encodeAsData(["value": true])
        let wrapper = try decoder.decode(ValueWrapper.self, from: data)
        XCTAssertEqual(wrapper.value, true)
    }
    
    func testString() throws {
        let data = JSON.encodeAsData(["value": "foo"])
        let wrapper = try decoder.decode(ValueWrapper.self, from: data)
        XCTAssertEqual(wrapper.value, "foo")
    }
    
    func testInt64() throws {
        let data = JSON.encodeAsData(["value": .int64(1234)])
        let wrapper = try decoder.decode(ValueWrapper.self, from: data)
        XCTAssertEqual(wrapper.value, .int64(1234))
    }
    
    func testDouble() throws {
        let data = JSON.encodeAsData(["value": .double(12.5)])
        let wrapper = try decoder.decode(ValueWrapper.self, from: data)
        XCTAssertEqual(wrapper.value, .double(12.5))
    }
    
    func testHugeDouble() throws {
        let data = JSON.encodeAsData(["value": .double(12e50)])
        let wrapper = try decoder.decode(ValueWrapper.self, from: data)
        XCTAssertEqual(wrapper.value, .double(12e50))
    }
    
    // Can't force JSONDecoder to decode as decimal so we won't try
    
    func testObject() throws {
        let data = JSON.encodeAsData(["value": ["foo": "bar"]])
        let wrapper = try decoder.decode(ValueWrapper.self, from: data)
        XCTAssertEqual(wrapper.value, ["foo": "bar"])
    }
    
    func testArray() throws {
        let data = JSON.encodeAsData(["value": ["foo", "bar"]])
        let wrapper = try decoder.decode(ValueWrapper.self, from: data)
        XCTAssertEqual(wrapper.value, ["foo", "bar"])
    }
}

final class SwiftMiscellaneousCodableTests: XCTestCase {
    private enum TestKey: CodingKey {
        case int(Int)
        case string(String)
        
        init?(intValue: Int) {
            self = .int(intValue)
        }
        
        init?(stringValue: String) {
            self = .string(stringValue)
        }
        
        var intValue: Int? {
            switch self {
            case .int(let x): return x
            case .string: return nil
            }
        }
        
        var stringValue: String {
            switch self {
            case .int(let x): return String(x)
            case .string(let s): return s
            }
        }
    }
    
    func testErrorWithEmptyPrefixedCodingPath() {
        let error = JSONError.missingOrInvalidType(path: "x", expected: .required(.number), actual: nil)
        XCTAssertEqual(error.withPrefixedCodingPath([]).path, "x")
    }
    
    func testErrorWithSingleStringPrefixedCodingPath() {
        let error = JSONError.outOfRangeInt64(path: "x", value: 32760, expected: Int8.self)
        XCTAssertEqual(error.withPrefixedCodingPath([TestKey.string("foo")]).path, "foo.x")
    }
    
    func testErrorWithMultipleStringPrefixedCodingPath() {
        let error = JSONError.outOfRangeDouble(path: "[1]", value: 32760, expected: Int8.self)
        XCTAssertEqual(error.withPrefixedCodingPath([TestKey.string("foo"), TestKey.string("bar")]).path, "foo.bar[1]")
    }
    
    func testErrorWithSingleIntPrefixedCodingPath() {
        let error = JSONError.outOfRangeDecimal(path: "x", value: 32760, expected: Int8.self)
        XCTAssertEqual(error.withPrefixedCodingPath([TestKey.int(42)]).path, "[42].x")
    }
    
    func testErrorWithMultipleIntPrefixedCodingPath() {
        let error = JSONError.missingOrInvalidType(path: "x", expected: .required(.number), actual: nil)
        XCTAssertEqual(error.withPrefixedCodingPath([TestKey.int(2), TestKey.int(42)]).path, "[2][42].x")
    }
    
    func testErrorWithMixedPrefixedCodignPath() {
        let error = JSONError.missingOrInvalidType(path: "x", expected: .required(.number), actual: nil)
        XCTAssertEqual(error.withPrefixedCodingPath([TestKey.string("foo"), TestKey.int(42), TestKey.string("bar")]).path, "foo[42].bar.x")
    }
    
    func testErrorWithNilPathPrefixedCodingPath() {
        let error = JSONError.missingOrInvalidType(path: nil, expected: .required(.number), actual: nil)
        XCTAssertEqual(error.withPrefixedCodingPath([TestKey.string("foo"), TestKey.string("bar")]).path, "foo.bar")
    }
}

/// Wrapper to make JSONEncoder/JSONDecoder happy about encoding values.
private struct ValueWrapper: Codable {
    let value: JSON
    
    init(_ value: JSON) {
        self.value = value
    }
}

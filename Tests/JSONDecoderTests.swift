//
//  JSONDecoderTests.swift
//  JSONTests
//
//  Created by Kevin Ballard on 10/8/15.
//  Copyright © 2016 Postmates.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import XCTest
import PMJSON

let bigJson: Data = {
    var s = "[\n"
    for _ in 0..<1000 {
        s += "{ \"a\": true, \"b\": null, \"c\":3.1415, \"d\": \"Hello world\", \"e\": [1,2,3]},"
    }
    s += "{}]"
    return s.data(using: String.Encoding.utf8)!
}()

private func readFixture(_ name: String, withExtension ext: String?) throws -> Data {
    struct NoSuchFixture: Error {}
    guard let url = Bundle(for: JSONDecoderTests.self).url(forResource: name, withExtension: ext) else {
        throw NoSuchFixture()
    }
    return try Data(contentsOf: url)
}

class JSONDecoderTests: XCTestCase {
    func testBasic() {
        assertMatchesJSON(try JSON.decode("42"), 42)
        assertMatchesJSON(try JSON.decode("\"hello\""), "hello")
        assertMatchesJSON(try JSON.decode("null"), nil)
        assertMatchesJSON(try JSON.decode("[true, false]"), [true, false])
        assertMatchesJSON(try JSON.decode("[1, 2, 3]"), [1, 2, 3])
        assertMatchesJSON(try JSON.decode("{\"one\": 1, \"two\": 2, \"three\": 3}"), ["one": 1, "two": 2, "three": 3])
    }
    
    func testDouble() {
        XCTAssertEqual(try JSON.decode("-5.4272823085455e-05"), -5.4272823085455e-05)
        XCTAssertEqual(try JSON.decode("-5.4272823085455e+05"), -5.4272823085455e+05)
    }
    
    func testStringEscapes() {
        assertMatchesJSON(try JSON.decode("\" \\\\\\\"\\/\\b\\f\\n\\r\\t \""), " \\\"/\u{8}\u{C}\n\r\t ")
        assertMatchesJSON(try JSON.decode("\" \\u200D\\u00A9\\uFFFD \""), " \u{200D}©\u{FFFD} ")
    }
    
    func testSurrogatePair() {
        assertMatchesJSON(try JSON.decode("\"emoji fun: 💩\\uD83D\\uDCA9\""), "emoji fun: 💩💩")
    }
    
    func testReencode() throws {
        // sample.json contains a lot of edge cases, so we'll make sure we can re-encode it and re-decode it and get the same thing
        let data = try readFixture("sample", withExtension: "json")
        let json = try JSON.decode(data)
        let encoded = JSON.encodeAsData(json)
        let json2 = try JSON.decode(encoded)
        if !json.approximatelyEqual(json2) { // encoding/decoding again doesn't necessarily match the exact numeric precision of the original
            // NB: Don't use XCTAssertEquals because this JSON is too large to be printed to the console
            XCTFail("Re-encoded JSON doesn't match original")
        }
    }
    
    func testConversions() {
        XCTAssertEqual(JSON(true), JSON.bool(true))
        XCTAssertEqual(JSON(42 as Int64), JSON.int64(42))
        XCTAssertEqual(JSON(42 as Double), JSON.double(42))
        XCTAssertEqual(JSON(42 as Int), JSON.int64(42))
        XCTAssertEqual(JSON("foo"), JSON.string("foo"))
        XCTAssertEqual(JSON(["foo": true]), ["foo": true])
        XCTAssertEqual(JSON([JSON.bool(true)] as JSONArray), [true]) // JSONArray
        XCTAssertEqual(JSON([true].lazy.map(JSON.bool)), [true]) // Sequence of JSON
        XCTAssertEqual(JSON([["foo": true], ["bar": 42]].lazy.map(JSONObject.init)), [["foo": true], ["bar": 42]]) // Sequence of JSONObject
        XCTAssertEqual(JSON([[1,2,3],[4,5,6]].lazy.map(JSONArray.init)), [[1,2,3],[4,5,6]]) // Sequence of JSONArray
    }
    
    func testConvenienceAccessors() {
        let dict: JSON = [
            "xs": [["x": 1], ["x": 2], ["x": 3]],
            "ys": [["y": 1], ["y": nil], ["y": 3], [:]],
            "zs": nil,
            "s": "Hello",
            "array": [
                [["x": 1], ["x": 2], ["x": 3]],
                [["y": 1], ["y": nil], ["y": 3], [:]],
                [["x": [1,2]], ["x": []], ["x": [3]], ["x": [4,5,6]]],
                nil,
                "Hello"
            ],
            "concat": [["x": [1]], ["x": [2,3]], ["x": []], ["x": [4,5,6]]]
        ]
        
        struct DummyError: Error {}
        
        // object-style accessors
        XCTAssertEqual([1,2,3], try dict.mapArray("xs", { try $0.getInt("x") }))
        XCTAssertThrowsError(try dict.mapArray("ys", { try $0.getInt("y") }))
        XCTAssertThrowsError(try dict.mapArray("s", { _ in 1 }))
        XCTAssertThrowsError(try dict.mapArray("invalid", { _ in 1 }))
        XCTAssertThrowsError(try dict.mapArray("xs", { _ in throw DummyError() })) { error in
            XCTAssert(error is DummyError, "expected DummyError, found \(error)")
        }
        XCTAssertEqual([1,2,3], try dict.object!.mapArray("xs", { try $0.getInt("x") }))
        XCTAssertThrowsError(try dict.object!.mapArray("ys", { try $0.getInt("y") }))
        XCTAssertThrowsError(try dict.object!.mapArray("s", { _ in 1 }))
        XCTAssertThrowsError(try dict.object!.mapArray("invalid", { _ in 1 }))
        XCTAssertThrowsError(try dict.object!.mapArray("xs", { _ in throw DummyError() })) { error in
            XCTAssert(error is DummyError, "expected DummyError, found \(error)")
        }
        
        XCTAssertEqual([1,2,3], try dict.mapArrayOrNil("xs", { try $0.getInt("x") }) ?? [-1])
        XCTAssertThrowsError(try dict.mapArrayOrNil("ys", { try $0.getInt("y") }) ?? [-1])
        XCTAssertNil(try dict.mapArrayOrNil("zs", { try $0.getInt("z") }))
        XCTAssertNil(try dict.mapArrayOrNil("invalid", { try $0.getInt("z") }))
        XCTAssertThrowsError(try dict.mapArrayOrNil("s", { _ in 1 })!)
        XCTAssertThrowsError(try dict.mapArrayOrNil("xs", { _ in throw DummyError() })) { error in
            XCTAssert(error is DummyError, "expected DummyError, found \(error)")
        }
        XCTAssertEqual([1,2,3], try dict.object!.mapArrayOrNil("xs", { try $0.getInt("x") }) ?? [-1])
        XCTAssertThrowsError(try dict.object!.mapArrayOrNil("ys", { try $0.getInt("y") }) ?? [-1])
        XCTAssertNil(try dict.object!.mapArrayOrNil("zs", { try $0.getInt("z") }))
        XCTAssertNil(try dict.object!.mapArrayOrNil("invalid", { try $0.getInt("z") }))
        XCTAssertThrowsError(try dict.object!.mapArrayOrNil("s", { _ in 1 })!)
        XCTAssertThrowsError(try dict.object!.mapArrayOrNil("xs", { _ in throw DummyError() })) { error in
            XCTAssert(error is DummyError, "expected DummyError, found \(error)")
        }
        
        XCTAssertEqual([1,3], try dict.flatMapArray("ys", { try $0.getIntOrNil("y") }))
        XCTAssertEqual([1,2,3,4,5,6], try dict.flatMapArray("concat", { try $0.mapArray("x", { try $0.getInt() }) }))
        XCTAssertThrowsError(try dict.flatMapArray("zs", { _ in [1] }))
        XCTAssertThrowsError(try dict.flatMapArray("s", { _ in [1] }))
        XCTAssertThrowsError(try dict.flatMapArray("invalid", { _ in [1] }))
        XCTAssertThrowsError(try dict.flatMapArray("xs", { _ -> [Int] in throw DummyError() })) { error in
            XCTAssert(error is DummyError, "expected DummyError, found \(error)")
        }
        XCTAssertEqual([1,3], try dict.object!.flatMapArray("ys", { try $0.getIntOrNil("y") }))
        XCTAssertEqual([1,2,3,4,5,6], try dict.object!.flatMapArray("concat", { try $0.mapArray("x", { try $0.getInt() }) }))
        XCTAssertThrowsError(try dict.object!.flatMapArray("zs", { _ in [1] }))
        XCTAssertThrowsError(try dict.object!.flatMapArray("s", { _ in [1] }))
        XCTAssertThrowsError(try dict.object!.flatMapArray("invalid", { _ in [1] }))
        XCTAssertThrowsError(try dict.object!.flatMapArray("xs", { _ -> [Int] in throw DummyError() })) { error in
            XCTAssert(error is DummyError, "expected DummyError, found \(error)")
        }
        
        XCTAssertEqual([1,3], try dict.flatMapArrayOrNil("ys", { try $0.getIntOrNil("y") }) ?? [])
        XCTAssertEqual([1,2,3,4,5,6], try dict.flatMapArrayOrNil("concat", { try $0.mapArray("x", { try $0.getInt() }) }) ?? [])
        XCTAssertNil(try dict.flatMapArrayOrNil("zs", { _ in [1] }))
        XCTAssertThrowsError(try dict.flatMapArrayOrNil("s", { _ in [1] }))
        XCTAssertNil(try dict.flatMapArrayOrNil("invalid", { _ in [1] }))
        XCTAssertThrowsError(try dict.flatMapArrayOrNil("xs", { _ -> [Int] in throw DummyError() })) { error in
            XCTAssert(error is DummyError, "expected DummyError, found \(error)")
        }
        XCTAssertEqual([1,3], try dict.object!.flatMapArrayOrNil("ys", { try $0.getIntOrNil("y") }) ?? [])
        XCTAssertEqual([1,2,3,4,5,6], try dict.object!.flatMapArrayOrNil("concat", { try $0.mapArray("x", { try $0.getInt() }) }) ?? [])
        XCTAssertNil(try dict.object!.flatMapArrayOrNil("zs", { _ in [1] }))
        XCTAssertThrowsError(try dict.object!.flatMapArrayOrNil("s", { _ in [1] }))
        XCTAssertNil(try dict.object!.flatMapArrayOrNil("invalid", { _ in [1] }))
        XCTAssertThrowsError(try dict.object!.flatMapArrayOrNil("xs", { _ -> [Int] in throw DummyError() })) { error in
            XCTAssert(error is DummyError, "expected DummyError, found \(error)")
        }
        
        XCTAssertThrowsError(try dict["array"]!.mapArray("xs", { _ in 1 }))
        XCTAssertThrowsError(try dict["array"]!.mapArrayOrNil("xs", { _ in 1 }))
        XCTAssertThrowsError(try dict["array"]!.flatMapArray("xs", { _ -> Int? in 1 }))
        XCTAssertThrowsError(try dict["array"]!.flatMapArray("xs", { _ in [1] }))
        XCTAssertThrowsError(try dict["array"]!.flatMapArrayOrNil("xs", { _ -> Int? in 1 }))
        XCTAssertThrowsError(try dict["array"]!.flatMapArrayOrNil("xs", { _ in [1] }))
        
        // array-style accessors
        let array = dict["array"]!
        XCTAssertEqual([1,2,3], try array.mapArray(0, { try $0.getInt("x") }))
        XCTAssertThrowsError(try array.mapArray(1, { try $0.getInt("y") }))
        XCTAssertEqual([2,0,1,3], try array.mapArray(2, { try $0.getArray("x").count }))
        XCTAssertThrowsError(try array.mapArray(3, { _ in 1 })) // null
        XCTAssertThrowsError(try array.mapArray(4, { _ in 1 })) // string
        XCTAssertThrowsError(try array.mapArray(5, { _ in 1 })) // out of bounds
        XCTAssertThrowsError(try array.mapArray(0, { _ in throw DummyError() })) { error in
            XCTAssert(error is DummyError, "expected DummyError, found \(error)")
        }
        
        XCTAssertEqual([1,2,3], try array.mapArrayOrNil(0, { try $0.getInt("x") }) ?? [])
        XCTAssertThrowsError(try array.mapArrayOrNil(1, { try $0.getInt("y") }))
        XCTAssertEqual([2,0,1,3], try array.mapArrayOrNil(2, { try $0.getArray("x").count }) ?? [])
        XCTAssertNil(try array.mapArrayOrNil(3, { _ in 1 })) // null
        XCTAssertThrowsError(try array.mapArrayOrNil(4, { _ in 1 })) // string
        XCTAssertNil(try array.mapArrayOrNil(5, { _ in 1 })) // out of bounds
        XCTAssertThrowsError(try array.mapArrayOrNil(0, { _ in throw DummyError() })) { error in
            XCTAssert(error is DummyError, "expected DummyError, found \(error)")
        }
        
        XCTAssertEqual([1,3], try array.flatMapArray(1, { try $0.getIntOrNil("y") }))
        XCTAssertEqual([1,2,3,4,5,6], try array.flatMapArray(2, { try $0.mapArray("x", { try $0.getInt() }) }))
        XCTAssertThrowsError(try array.flatMapArray(3, { _ in [1] })) // null
        XCTAssertThrowsError(try array.flatMapArray(4, { _ in [1] })) // string
        XCTAssertThrowsError(try array.flatMapArray(5, { _ in [1] })) // out of bounds
        XCTAssertThrowsError(try array.flatMapArray(0, { _ -> [Int] in throw DummyError() })) { error in
            XCTAssert(error is DummyError, "expected DummyError, found \(error)")
        }
        
        XCTAssertEqual([1,3], try array.flatMapArrayOrNil(1, { try $0.getIntOrNil("y") }) ?? [])
        XCTAssertEqual([1,2,3,4,5,6], try array.flatMapArrayOrNil(2, { try $0.mapArray("x", { try $0.getInt() }) }) ?? [])
        XCTAssertNil(try array.flatMapArrayOrNil(3, { _ in [1] })) // null
        XCTAssertThrowsError(try array.flatMapArrayOrNil(4, { _ in [1] })) // string
        XCTAssertNil(try array.flatMapArrayOrNil(5, { _ in [1] })) // out of bounds
        XCTAssertThrowsError(try array.flatMapArrayOrNil(0, { _ -> [Int] in throw DummyError() })) { error in
            XCTAssert(error is DummyError, "expected DummyError, found \(error)")
        }
        
        XCTAssertThrowsError(try dict.mapArray(0, { _ in 1 }))
        XCTAssertThrowsError(try dict.mapArrayOrNil(0, { _ in 1 }))
        XCTAssertThrowsError(try dict.flatMapArray(0, { _ in 1 }))
        XCTAssertThrowsError(try dict.flatMapArrayOrNil(0, { _ in 1 }))
    }
    
    func testConvenienceAccessorAssignments() {
        var json: JSON = "test"
        
        XCTAssertNil(json.bool)
        json.bool = true
        XCTAssertEqual(json, true)
        json.bool = nil
        XCTAssertEqual(json, JSON.null)
        
        XCTAssertNil(json.string)
        json.string = "foo"
        XCTAssertEqual(json, "foo")
        json.string = nil
        XCTAssertEqual(json, JSON.null)
        
        XCTAssertNil(json.int64)
        json.int64 = 42
        XCTAssertEqual(json, 42)
        json.int64 = nil
        XCTAssertEqual(json, JSON.null)
        
        XCTAssertNil(json.int)
        json.int = 42
        XCTAssertEqual(json, 42)
        json.int = nil
        XCTAssertEqual(json, JSON.null)
        
        XCTAssertNil(json.double)
        json.double = 42
        XCTAssertEqual(json, 42)
        json.double = nil
        XCTAssertEqual(json, JSON.null)
        
        XCTAssertNil(json.object)
        json.object = ["foo": "bar"]
        XCTAssertEqual(json, ["foo": "bar"])
        json.object = nil
        XCTAssertEqual(json, JSON.null)
        
        XCTAssertNil(json.array)
        json.array = [1,2,3]
        XCTAssertEqual(json, [1,2,3])
        json.array = nil
        XCTAssertEqual(json, JSON.null)
        
        json = ["foo": "bar"]
        json.object?["baz"] = "qux"
        XCTAssertEqual(json, ["foo": "bar", "baz": "qux"])
        
        json = ["value": ["array": [1,2]]]
        json.object?["value"]?.object?["array"]?.array?.append(3)
        XCTAssertEqual(json, ["value": ["array": [1,2,3]]])
    }
    
    #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS)
    func testJSONErrorNSErrorDescription() throws {
        let jserror: JSONError?
        do {
            let json: JSON = ["foo": 1]
            _ = try json.getString("foo")
            jserror = nil
        } catch let error as JSONError {
            jserror = error
        }
        guard let error = jserror else {
            XCTFail("Expected error, found nothing")
            return
        }
        XCTAssertEqual(String(describing: error), error.localizedDescription)
    }
    #endif
    
    func testDepthLimit() {
        func assertThrowsDepthError(_ string: String, limit: Int, file: StaticString = #file, line: UInt = #line) {
            XCTAssertThrowsError(try JSON.decode(string, options: [.depthLimit(limit)]), file: file, line: line) { (error) in
                switch error {
                case JSONDecoderError.exceededDepthLimit: break
                default: XCTFail("Expected JSONDecoderError.exceededDepthLimit, got \(error)", file: file, line: line)
                }
            }
        }
        
        assertThrowsDepthError("[[[[[1]]]]]", limit: 3)
        assertMatchesJSON(try JSON.decode("[[[[[1]]]]]", options: [.depthLimit(10)]), [[[[[1]]]]])
        assertThrowsDepthError("{\"a\":{\"a\":{\"a\":{\"a\":{\"a\":1}}}}}", limit: 3)
        assertMatchesJSON(try JSON.decode("{\"a\":{\"a\":{\"a\":{\"a\":{\"a\":1}}}}}", options: [.depthLimit(10)]), ["a":["a":["a":["a":["a":1]]]]])
        
        // Depth limit of 0 means just values, no arrays/dictionaries at all
        assertMatchesJSON(try JSON.decode("null", options: [.depthLimit(0)]), nil)
        assertMatchesJSON(try JSON.decode("3", options: [.depthLimit(0)]), 3)
        assertThrowsDepthError("[]", limit: 0)
        assertThrowsDepthError("{}", limit: 0)
        
        // Depth limit of 1 means one level of array/dictionary
        assertMatchesJSON(try JSON.decode("[1]", options: [.depthLimit(1)]), [1])
        assertMatchesJSON(try JSON.decode("{\"a\":1}", options: [.depthLimit(1)]), ["a":1])
        assertThrowsDepthError("[[1]]", limit: 1)
        assertThrowsDepthError("{\"a\":{}}", limit: 1)
        assertThrowsDepthError("[{}]", limit: 1)
        assertThrowsDepthError("{\"a\":[]}", limit: 1)
    }
    
    func testBOMDetection() {
        // UTF-32BE with BOM
        assertMatchesJSON(try JSON.decode("\u{FEFF}42".data(using: .utf32BigEndian)!), 42)
        // UTF-32LE with BOM
        assertMatchesJSON(try JSON.decode("\u{FEFF}42".data(using: .utf32LittleEndian)!), 42)
        // UTF-16BE with BOM
        assertMatchesJSON(try JSON.decode("\u{FEFF}42".data(using: .utf16BigEndian)!), 42)
        // UTF-16LE with BOM
        assertMatchesJSON(try JSON.decode("\u{FEFF}42".data(using: .utf16LittleEndian)!), 42)
        // UTF8 with BOM
        assertMatchesJSON(try JSON.decode("\u{FEFF}42".data(using: .utf8)!), 42)
    }
    
    func testUnicodeHeuristicDetection() {
        // UTF-32BE
        assertMatchesJSON(try JSON.decode("42".data(using: .utf32BigEndian)!), 42)
        // UTF-32LE
        assertMatchesJSON(try JSON.decode("42".data(using: .utf32LittleEndian)!), 42)
        // UTF-16BE
        assertMatchesJSON(try JSON.decode("42".data(using: .utf16BigEndian)!), 42)
        // UTF-16LE
        assertMatchesJSON(try JSON.decode("42".data(using: .utf16LittleEndian)!), 42)
        // UTF8
        assertMatchesJSON(try JSON.decode("42".data(using: .utf8)!), 42)
    }
}

/// Tests both `JSONDecoder`'s streaming mode and `JSONStreamDecoder`.
class JSONStreamDecoderTests: XCTestCase {
    func testDecoderStreamingMode() {
        func decodeStream(_ input: String) throws -> [JSON] {
            let parser = JSONParser(input.unicodeScalars, options: [.streaming])
            var decoder = JSONDecoder(parser)
            return try decoder.decodeStream()
        }
        func assertMatchesEvents(_ input: String, _ expected: [JSON], file: StaticString = #file, line: UInt = #line) {
            do {
                let events = try decodeStream(input)
                for (i, (event, value)) in zip(events, expected).enumerated() {
                    if !matchesJSON(event, value) {
                        XCTFail("event \(i+1) (\(event)) does not equal \(value)", file: file, line: line)
                    }
                    if events.count > expected.count {
                        XCTFail("unexpected event \(expected.count+1)", file: file, line: line)
                    }
                    if events.count < expected.count {
                        XCTFail("expected event \(events.count+1) (\(expected[events.count])), found nil", file: file, line: line)
                    }
                }
            } catch {
                XCTFail("assertMatchesEvents - error thrown: \(error)", file: file, line: line)
            }
        }
        
        assertMatchesEvents("", [])
        assertMatchesEvents("  ", [])
        assertMatchesEvents("true", [true])
        assertMatchesEvents("true false", [true, false])
        assertMatchesEvents("{\"a\": 1}{\"a\": 2}3", [["a": 1], ["a": 2], 3])
        
        
        XCTAssertThrowsError(try decodeStream("true q")) { (error) in
            switch error {
            case let error as JSONParserError:
                XCTAssertEqual(error, JSONParserError(code: .invalidSyntax, line: 0, column: 6))
            default:
                XCTFail("expected JSONParserError, found \(error)")
            }
        }
    }
    
    func testStreamingDecoder() {
        func assertMatchesValues(_ input: String, _ expected: [JSONStreamValue], file: StaticString = #file, line: UInt = #line) {
            for (i, (value, expected)) in zip(JSON.decodeStream(input), expected).enumerated() {
                switch (value, expected) {
                case let (.json(value), .json(expected)):
                    if !matchesJSON(value, expected) {
                        XCTFail("value \(i+1) - (\(value)) does not equal \(expected)", file: file, line: line)
                    }
                case let (.error(error), .error(expected)):
                    if error != expected {
                        XCTFail("error \(i+1) - (\(error)) does not equal \(expected)", file: file, line: line)
                    }
                case let (.json(value), .error(expected)):
                    XCTFail("value \(i+1) - expected error \(expected), found value \(value)", file: file, line: line)
                case let (.error(error), .json(expected)):
                    XCTFail("value \(i+1) - expected value \(expected), found error \(error)", file: file, line: line)
                }
            }
            // Also check the behavior of values()
            do {
                let expectedValues = try expected.map({ try $0.unwrap() })
                do {
                    let values = try JSON.decodeStream(input).values()
                    XCTAssertEqual(values, expectedValues, file: file, line: line)
                } catch {
                    XCTFail("unexpected error found decoding JSON stream - \(error)", file: file, line: line)
                }
            } catch let expectedError as JSONParserError {
                XCTAssertThrowsError(try JSON.decodeStream(input).values()) { (error) in
                    switch error {
                    case let error as JSONParserError:
                        XCTAssertEqual(error, expectedError, file: file, line: line)
                    default:
                        XCTFail("expected \(expectedError), found \(error)", file: file, line: line)
                    }
                }
            } catch {
                XCTFail(file: file, line: line) // unreachable
            }
        }
        func assertMatchesEvents(_ input: String, _ expected: [JSON], file: StaticString = #file, line: UInt = #line) {
            assertMatchesValues(input, expected.map(JSONStreamValue.json), file: file, line: line)
        }
        
        assertMatchesEvents("", [])
        assertMatchesEvents("  ", [])
        assertMatchesEvents("true", [true])
        assertMatchesEvents("true false", [true, false])
        assertMatchesEvents("{\"a\": 1}{\"a\": 2}3", [["a": 1], ["a": 2], 3])
        
        assertMatchesValues("true q", [.json(true), .error(JSONParserError(code: .invalidSyntax, line: 0, column: 6))])
        // After a parser error, nothing more is parsed
        assertMatchesValues("true q true", [.json(true), .error(JSONParserError(code: .invalidSyntax, line: 0, column: 6))])
    }
}

class JSONBenchmarks: XCTestCase {
    func testCompareCocoa() {
        do {
            let json = try JSON.decode(bigJson)
            let jsonObj = json.ns as! NSObject
            let cocoa = try JSONSerialization.jsonObject(with: bigJson) as! NSObject
            XCTAssertEqual(jsonObj, cocoa)
            let cocoa2 = try JSONSerialization.jsonObject(with: JSON.encodeAsData(json)) as! NSObject
            XCTAssertEqual(jsonObj, cocoa2)
        } catch {
            XCTFail(String(describing: error))
        }
    }
    
    func testDecodePerformance() {
        measure { [bigJson] in
            for _ in 0..<10 {
                do {
                    _ = try JSON.decode(bigJson)
                } catch {
                    XCTFail("error parsing json: \(error)")
                }
            }
        }
    }
    
    func testDecodePerformanceCocoa() {
        measure { [bigJson] in
            for _ in 0..<10 {
                do {
                    _ = try JSONSerialization.jsonObject(with: bigJson, options: [])
                } catch {
                    XCTFail("error parsing json: \(error)")
                }
            }
        }
    }
    
    func testEncodePerformance() {
        do {
            let json = try JSON.decode(bigJson)
            measure {
                for _ in 0..<10 {
                    _ = JSON.encodeAsData(json)
                }
            }
        } catch {
            XCTFail("error parsing json: \(error)")
        }
    }
    
    func testEncodeCocoaPerformance() {
        do {
            let json = try JSON.decode(bigJson).ns
            measure {
                for _ in 0..<10 {
                    do {
                        _ = try JSONSerialization.data(withJSONObject: json)
                    } catch {
                        XCTFail("error encoding json: \(error)")
                    }
                }
            }
        } catch {
            XCTFail("error parsing json: \(error)")
        }
    }
    
    func testEncodePrettyPerformance() {
        do {
            let json = try JSON.decode(bigJson)
            measure {
                for _ in 0..<10 {
                    _ = JSON.encodeAsData(json, options: [.pretty])
                }
            }
        } catch {
            XCTFail("error parsing json: \(error)")
        }
    }
    
    func testEncodePrettyCocoaPerformance() {
        do {
            let json = try JSON.decode(bigJson).ns
            measure {
                for _ in 0..<10 {
                    do {
                        _ = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
                    } catch {
                        XCTFail("error encoding json: \(error)")
                    }
                }
            }
        } catch {
            XCTFail("error parsing json: \(error)")
        }
    }
    
    func testDecodeSampleJSONPerformance() throws {
        let data = try readFixture("sample", withExtension: "json")
        measure {
            for _ in 0..<10 {
                do {
                    _ = try JSON.decode(data)
                } catch {
                    return XCTFail("error parsing json: \(error)")
                }
            }
        }
    }
    
    func testDecodeSampleJSONCocoaPerformance() throws {
        let data = try readFixture("sample", withExtension: "json")
        measure {
            for _ in 0..<10 {
                do {
                    _ = try JSONSerialization.jsonObject(with: data)
                } catch {
                    return XCTFail("error parsing json: \(error)")
                }
            }
        }
    }
}

func assertMatchesJSON(_ a: @autoclosure () throws -> JSON, _ b: @autoclosure () -> JSON, file: StaticString = #file, line: UInt = #line) {
    do {
        let a = try a(), b = b()
        if !matchesJSON(a, b) {
            XCTFail("expected \(b), found \(a)", file: file, line: line)
        }
    } catch {
        XCTFail(String(describing: error), file: file, line: line)
    }
}

/// Similar to JSON's equality test but does not convert between integral and double values.
private func matchesJSON(_ a: JSON, _ b: JSON) -> Bool {
    switch (a, b) {
    case (.array(let a), .array(let b)):
        return a.count == b.count && !zip(a, b).contains(where: {!matchesJSON($0, $1)})
    case (.object(let a), .object(let b)):
        guard a.count == b.count else { return false }
        for (key, value) in a {
            guard let bValue = b[key], matchesJSON(value, bValue) else {
                return false
            }
        }
        return true
    case (.string(let a), .string(let b)):
        return a == b
    case (.int64(let a), .int64(let b)):
        return a == b
    case (.double(let a), .double(let b)):
        return a == b
    case (.null, .null):
        return true
    case (.bool(let a), .bool(let b)):
        return a == b
    default:
        return false
    }
}

extension JSON {
    /// Performs an equality test, but accepts nearly-equal `Double` values.
    func approximatelyEqual(_ other: JSON) -> Bool {
        switch (self, other) {
        case (.double(let a), .double(let b)):
            // we're going to cheat and just convert them to Floats and compare that way.
            // We just care about equal up to a given precision, and so dropping down to Float precision should give us that.
            return Float(a) == Float(b)
        case (.array(let a), .array(let b)):
            return a.count == b.count && !zip(a, b).lazy.contains(where: { !$0.approximatelyEqual($1) })
        case (.object(let a), .object(let b)):
            return a.count == b.count && !a.contains(where: { (k,v) in b[k].map(
                { !$0.approximatelyEqual(v) }) ?? true })
        default:
            return self == other
        }
    }
}

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
import Foundation

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
    #if SWIFT_PACKAGE
        // We don't have a resource bundle, so let's just look relative to our source file.
        let url = URL(fileURLWithPath: #file, isDirectory: false).deletingLastPathComponent().appendingPathComponent(ext.map({ "\(name).\($0)" }) ?? name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NoSuchFixture()
        }
    #else
        guard let url = Bundle(for: JSONDecoderTests.self).url(forResource: name, withExtension: ext) else {
            throw NoSuchFixture()
        }
    #endif
    return try Data(contentsOf: url)
}

public final class JSONDecoderTests: XCTestCase {
    public static let allLinuxTests: [(String, (JSONDecoderTests) -> () throws -> Void)] = {
        var tests: [(String, (JSONDecoderTests) -> () throws -> Void)] = [
            ("testBasic", testBasic),
            ("testDouble", testDouble),
            ("testStringEscapes", testStringEscapes),
            ("testSurrogatePair", testSurrogatePair),
            ("testReencode", testReencode),
            ("testConverions", testConversions),
            ("testDepthLimit", testBOMDetection),
            ("testUnicodeHeuristicDetection", testUnicodeHeuristicDetection)
        ]
        #if swift(>=3.1)
            tests.append(contentsOf: [
                ("testDecimalParsing", testDecimalParsing),
                ("testJSONErrorNSErrorDescription", testJSONErrorNSErrorDescription),
                ])
        #endif
        return tests
    }()
    
    func testBasic() {
        assertMatchesJSON(try JSON.decode("42"), 42)
        assertMatchesJSON(try JSON.decode("\"hello\""), "hello")
        assertMatchesJSON(try JSON.decode("null"), nil)
        assertMatchesJSON(try JSON.decode("[true, false]"), [true, false])
        assertMatchesJSON(try JSON.decode("[1, 2, 3]"), [1, 2, 3])
        assertMatchesJSON(try JSON.decode("{\"one\": 1, \"two\": 2, \"three\": 3}"), ["one": 1, "two": 2, "three": 3])
        assertMatchesJSON(try JSON.decode("[1.23, 4e7]"), [1.23, 4e7])
        #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS) || swift(>=3.1)
            assertMatchesJSON(try JSON.decode("[1.23, 4e7]", options: [.useDecimals]), [JSON(1.23 as Decimal), JSON(4e7 as Decimal)])
        #endif
    }
    
    func testDouble() {
        XCTAssertEqual(try JSON.decode("-5.4272823085455e-05"), -5.4272823085455e-05)
        XCTAssertEqual(try JSON.decode("-5.4272823085455e+05"), -5.4272823085455e+05)
        #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS) || swift(>=3.1)
            XCTAssertEqual(try JSON.decode("-5.4272823085455e+05", options: [.useDecimals]), JSON(Decimal(string: "-5.4272823085455e+05")!))
        #endif
    }
    
    func testStringEscapes() {
        assertMatchesJSON(try JSON.decode("\" \\\\\\\"\\/\\b\\f\\n\\r\\t \""), " \\\"/\u{8}\u{C}\n\r\t ")
        assertMatchesJSON(try JSON.decode("\" \\u200D\\u00A9\\uFFFD \""), " \u{200D}©\u{FFFD} ")
    }
    
    func testSurrogatePair() {
        assertMatchesJSON(try JSON.decode("\"emoji fun: 💩\\uD83D\\uDCA9\""), "emoji fun: 💩💩")
    }
    
    #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS) || swift(>=3.1)
    func testDecimalParsing() throws {
        let data = try readFixture("sample", withExtension: "json")
        // Decode the data and make sure it contains no .double values
        let json = try JSON.decode(data, options: [.useDecimals])
        let value = json.walk { value in
            return value.isDouble ? value : .none
        }
        XCTAssertNil(value)
    }
    #endif
    
    func testReencode() throws {
        // sample.json contains a lot of edge cases, so we'll make sure we can re-encode it and re-decode it and get the same thing
        let data = try readFixture("sample", withExtension: "json")
        do {
            let json = try JSON.decode(data)
            let encoded = JSON.encodeAsString(json)
            let json2 = try JSON.decode(encoded)
            if !json.approximatelyEqual(json2) { // encoding/decoding again doesn't necessarily match the exact numeric precision of the original
                // NB: Don't use XCTAssertEquals because this JSON is too large to be printed to the console
                XCTFail("Re-encoded JSON doesn't match original")
            }
        }
        #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS) || swift(>=3.1)
            do {
                // test again with decimals
                let json = try JSON.decode(data, options: [.useDecimals])
                let encoded = JSON.encodeAsString(json)
                let json2 = try JSON.decode(encoded, options: [.useDecimals])
                if json != json2 { // This preserves all precision, but may still convert between int64 and decimal so we can't use matchesJSON
                    // NB: Don't use XCTAssertEquals because this JSON is too large to be printed to the console
                    try json.debugMatches(json2, ==)
                    XCTFail("Re-encoded JSON doesn't match original")
                }
            }
        #endif
    }
    
    func testConversions() {
        XCTAssertEqual(JSON(true), JSON.bool(true))
        XCTAssertEqual(JSON(42 as Int64), JSON.int64(42))
        XCTAssertEqual(JSON(42 as Double), JSON.double(42))
        XCTAssertEqual(JSON(42 as Int), JSON.int64(42))
        #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS) || swift(>=3.1)
            XCTAssertEqual(JSON(42 as Decimal), JSON.decimal(42))
        #endif
        XCTAssertEqual(JSON("foo"), JSON.string("foo"))
        XCTAssertEqual(JSON(["foo": true]), ["foo": true])
        XCTAssertEqual(JSON([JSON.bool(true)] as JSONArray), [true]) // JSONArray
        XCTAssertEqual(JSON([true].lazy.map(JSON.bool)), [true]) // Sequence of JSON
        XCTAssertEqual(JSON([["foo": true], ["bar": 42]].lazy.map(JSONObject.init)), [["foo": true], ["bar": 42]]) // Sequence of JSONObject
        XCTAssertEqual(JSON([[1,2,3],[4,5,6]].lazy.map(JSONArray.init)), [[1,2,3],[4,5,6]]) // Sequence of JSONArray
    }
    
    #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS) || swift(>=3.1)
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
public class JSONStreamDecoderTests: XCTestCase {
    public static let allLinuxTests = [
        ("testDecoderStreamingMode", testDecoderStreamingMode),
        ("testStreamingDecoder", testStreamingDecoder)
    ]
    
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

public class JSONBenchmarks: XCTestCase {
    public static let allLinuxTests: [(String, (JSONBenchmarks) -> () throws -> Void)] = [
        ("testDecodePerformance", testDecodePerformance),
        ("testDecodeDecimalPerformance", testDecodeDecimalPerformance),
        ("testDecodePerformanceCocoa", testDecodePerformanceCocoa),
        ("testEncodePerformance", testEncodePerformance),
        ("testEncodePrettyPerformance", testEncodePrettyPerformance),
        ("testDecodeSampleJSONPerformance", testDecodeSampleJSONPerformance),
        ("testDecodeSampleJSONDecimalPerformance", testDecodeSampleJSONDecimalPerformance),
        ("testDecodeSampleJSONCocoaPerformance", testDecodeSampleJSONCocoaPerformance)
    ]
    
    #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS)
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
    #endif
    
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
    
    func testDecodeDecimalPerformance() {
        measure { [bigJson] in
            for _ in 0..<10 {
                do {
                    _ = try JSON.decode(bigJson, options: [.useDecimals])
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
    
    #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS)
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
    #endif
    
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
    
    #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS)
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
    #endif
    
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
    
    func testDecodeSampleJSONDecimalPerformance() throws {
        let data = try readFixture("sample", withExtension: "json")
        measure {
            for _ in 0..<10 {
                do {
                    _ = try JSON.decode(data, options: [.useDecimals])
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

/// Similar to JSON's equality test but does not convert between numeric values.
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
    case (.decimal(let a), .decimal(let b)):
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
    
    /// Invokes the given block on every JSON value within `self`.
    /// For objects and arrays, the block is run with the object/array first, and then
    /// with its contents afterward.
    func walk<T>(using f: (JSON) throws -> T?) rethrows -> T? {
        if let result = try f(self) {
            return result
        }
        switch self {
        case .object(let obj):
            for value in obj.values {
                if let result = try value.walk(using: f) {
                    return result
                }
            }
        case .array(let ary):
            for elt in ary {
                if let result = try elt.walk(using: f) {
                    return result
                }
            }
        default:
            break
        }
        return nil
    }
    
    /// Walks two JSON values in sync, performing the given equality test on
    /// all leaf values and throwing an error when a mismatch is found.
    /// The equality test is not performed on objects or arrays.
    func debugMatches(_ other: JSON, _ compare: (JSON, JSON) -> Bool) throws {
        enum Error: LocalizedError {
            case objectCountMismatch
            case objectKeyMismatch
            case arrayCountMismatch
            case typeMismatch
            case equalityFailure(JSON, JSON)
            
            var errorDescription: String? {
                switch self {
                case .objectCountMismatch: return "object count mismatch"
                case .objectKeyMismatch: return "object key mismatch"
                case .arrayCountMismatch: return "array count mismatch"
                case .typeMismatch: return "value type mismatch"
                case let .equalityFailure(a, b): return "\(String(reflecting: a)) is not equal to \(String(reflecting: b))"
                }
            }
        }
        switch (self, other) {
        case (.object(let a), .object(let b)):
            guard a.count == b.count else { throw Error.objectCountMismatch }
            for (k, v) in a {
                guard let v2 = b[k] else { throw Error.objectKeyMismatch }
                try v.debugMatches(v2, compare)
            }
        case (.object, _), (_, .object):
            throw Error.typeMismatch
        case (.array(let a), .array(let b)):
            guard a.count == b.count else { throw Error.arrayCountMismatch }
            for (v, v2) in zip(a,b) {
                try v.debugMatches(v2, compare)
            }
        case (.array, _), (_, .array):
            throw Error.typeMismatch
        default:
            if !compare(self, other) {
                throw Error.equalityFailure(self, other)
            }
        }
    }
}

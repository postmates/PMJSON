//
//  JSONEncoderTests.swift
//  PMJSON
//
//  Created by Kevin Ballard on 11/1/16.
//  Copyright © 2016 Postmates.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import PMJSON
import XCTest

import struct Foundation.Decimal

/// - Note: The encoder is primarily tested with round-trip tests in `JSONDecoderTests`.
public final class JSONEncoderTests: XCTestCase {
    public static let allLinuxTests = [
        ("testDecimalEncoding", testDecimalEncoding),
        ("testEncodeAsData", testEncodeAsData)
    ]
    
    func testDecimalEncoding() {
        XCTAssertEqual(JSON.encodeAsString(.decimal(42.714)), "42.714")
        XCTAssertEqual(JSON.encodeAsString([1, JSON(Decimal(string: "1.234567890123456789")!)]), "[1,1.234567890123456789]")
    }
    
    func testEncodeAsData() {
        // Because we hve the fancy buffering in encodeAsData, let's make sure we get the correct
        // results for a few different inputs
        func helper(_ input: JSON, file: StaticString = #file, line: UInt = #line) {
            let str = JSON.encodeAsString(input)
            let data = JSON.encodeAsData(input)
            XCTAssertEqual(str.data(using: .utf8)!, data, file: file, line: line)
        }
        
        // Whole thing is below max chunk size
        helper(["foo": "bar"])
        // Include a single chunk larger than the max chunk size
        helper(["long string": .string(String(repeating: "A", count: 33 * 1024))])
        // Whole JSON string is multiple chunks
        helper(["array": .array(JSONArray(repeating: "hello", count: 32 * 1024))])
    }
}

public final class JSONEncoderBenchmarks: XCTestCase {
    public static let allLinuxTests = [
        ("testEncodePerformance", testEncodePerformance),
        ("testEncodeAsDataPerformance", testEncodeAsDataPerformance),
        ("testEncodeAsStringConvertedToDataPerformance", testEncodeAsStringConvertedToDataPerformance),
        ("testEncodePrettyPerformance", testEncodePrettyPerformance),
        ("testEncodePrettyAsDataPerformance", testEncodePrettyAsDataPerformance)
    ]
    
    func testEncodePerformance() throws {
        let json = try JSON.decode(bigJson)
        measure {
            for _ in 0..<10 {
                _ = JSON.encodeAsString(json)
            }
        }
    }
    
    func testEncodeAsDataPerformance() throws {
        let json = try JSON.decode(bigJson)
        measure {
            for _ in 0..<10 {
                _ = JSON.encodeAsData(json)
            }
        }
    }
    
    func testEncodeAsStringConvertedToDataPerformance() throws {
        let json = try JSON.decode(bigJson)
        measure {
            for _ in 0..<10 {
                _ = JSON.encodeAsString(json).data(using: .utf8)
            }
        }

    }
    
    #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS)
    func testEncodeCocoaPerformance() throws {
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
    }
    #endif
    
    func testEncodePrettyPerformance() throws {
        let json = try JSON.decode(bigJson)
        measure {
            for _ in 0..<10 {
                _ = JSON.encodeAsString(json, options: [.pretty])
            }
        }
    }
    
    func testEncodePrettyAsDataPerformance() throws {
        let json = try JSON.decode(bigJson)
        measure {
            for _ in 0..<10 {
                _ = JSON.encodeAsData(json, options: [.pretty])
            }
        }
    }
    
    #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS)
    func testEncodePrettyCocoaPerformance() throws {
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
    }
    #endif
}

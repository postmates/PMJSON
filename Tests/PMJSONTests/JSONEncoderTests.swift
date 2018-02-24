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
        ("testDecimalEncoding", testDecimalEncoding)
    ]
    
    func testDecimalEncoding() {
        XCTAssertEqual(JSON.encodeAsString(.decimal(42.714)), "42.714")
        XCTAssertEqual(JSON.encodeAsString([1, JSON(Decimal(string: "1.234567890123456789")!)]), "[1,1.234567890123456789]")
    }
}

public final class JSONEncoderBenchmarks: XCTestCase {
    public static let allLinuxTests = [
        ("testEncodePerformance", testEncodePerformance),
        ("testEncodeAsDataPerformance", testEncodeAsDataPerformance),
        ("testEncodePrettyPerformance", testEncodePrettyPerformance),
        ("testEncodePrettyAsDataPerformance", testEncodePrettyAsDataPerformance)
    ]
    
    func testEncodePerformance() {
        do {
            let json = try JSON.decode(bigJson)
            measure {
                for _ in 0..<10 {
                    _ = JSON.encodeAsString(json)
                }
            }
        } catch {
            XCTFail("error parsing json: \(error)")
        }
    }
    
    func testEncodeAsDataPerformance() {
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
                    _ = JSON.encodeAsString(json, options: [.pretty])
                }
            }
        } catch {
            XCTFail("error parsing json: \(error)")
        }
    }
    
    func testEncodePrettyAsDataPerformance() {
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
}

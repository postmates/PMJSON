//
//  JSONEncoderTests.swift
//  PMJSON
//
//  Created by Kevin Ballard on 11/1/16.
//  Copyright © 2016 Postmates. All rights reserved.
//

import PMJSON
import XCTest

#if os(iOS) || os(OSX) || os(watchOS) || os(tvOS) || swift(>=3.1)
    import struct Foundation.Decimal
#endif

/// - Note: The encoder is primarily tested with round-trip tests in `JSONDecoderTests`.
public final class JSONEncoderTests: XCTestCase {
    #if swift(>=3.1)
    public static let allLinuxTests = [
        ("testDecimalEncoding", testDecimalEncoding)
    ]
    #else
    public static let allLinuxTests: [(String, (JSONEncoderTests) -> () -> Void)] = []
    #endif
    
    #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS) || swift(>=3.1)
    func testDecimalEncoding() {
        XCTAssertEqual(JSON.encodeAsString(.decimal(42.714)), "42.714")
        XCTAssertEqual(JSON.encodeAsString([1, JSON(Decimal(string: "1.234567890123456789")!)]), "[1,1.234567890123456789]")
    }
    #endif
}

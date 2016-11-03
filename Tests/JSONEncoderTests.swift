//
//  JSONEncoderTests.swift
//  PMJSON
//
//  Created by Kevin Ballard on 11/1/16.
//  Copyright © 2016 Postmates. All rights reserved.
//

import PMJSON
import XCTest

#if os(iOS) || os(OSX) || os(watchOS) || os(tvOS)
    import struct Foundation.Decimal
#endif

/// - Note: The encoder is primarily tested with round-trip tests in `JSONDecoderTests`.
final class JSONEncoderTests: XCTestCase {
    #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS)
    func testDecimalEncoding() {
        XCTAssertEqual(JSON.encodeAsString(.decimal(42.714)), "42.714")
        XCTAssertEqual(JSON.encodeAsString([1, JSON(Decimal(string: "1.234567890123456789")!)]), "[1,1.234567890123456789]")
    }
    #endif
}

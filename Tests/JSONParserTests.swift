//
//  JSONParserTests.swift
//  PMJSON
//
//  Created by Kevin Ballard on 10/19/16.
//  Copyright © 2016 Postmates. All rights reserved.
//

import XCTest
import PMJSON

class JSONParserTests: XCTestCase {
    func testParserErrorDescription() {
        XCTAssertEqual(String(describing: JSONParserError(code: .unexpectedEOF, line: 5, column: 12)), "JSONParserError(unexpectedEOF, line: 5, column: 12)")
    }
    
    func testTrailingCharacters() {
        // Non-streaming parsers ignore trailing whitespace.
        assertParserEvents("true  ", [.booleanValue(true)])
        
        // Non-streaming parsers emit an error if there are trailing non-whitespace characters.
        assertParserEvents("true false", [.booleanValue(true), .error(JSONParserError(code: .trailingCharacters, line: 0, column: 6))])
    }
    
    func testEmptyInput() {
        // Non-streaming parsers emit an error if there is no input.
        assertParserEvents("", [JSONEvent.error(JSONParserError(code: .unexpectedEOF, line: 0, column: 1))])
        assertParserEvents("  ", [JSONEvent.error(JSONParserError(code: .unexpectedEOF, line: 0, column: 3))])
    }
    
    func testStreaming() {
        func makeStreamingParser(_ input: String) -> JSONParser<String.UnicodeScalarView> {
            return JSONParser(input.unicodeScalars, options: [.streaming])
        }
        assertParserEvents("", streaming: true, [])
        assertParserEvents("  ", streaming: true, [])
        assertParserEvents("[1][2]", streaming: true, [.arrayStart, .int64Value(1), .arrayEnd, .arrayStart, .int64Value(2), .arrayEnd])
        assertParserEvents("[1] [2]", streaming: true, [.arrayStart, .int64Value(1), .arrayEnd, .arrayStart, .int64Value(2), .arrayEnd])
        assertParserEvents("[1]\n[2]", streaming: true, [.arrayStart, .int64Value(1), .arrayEnd, .arrayStart, .int64Value(2), .arrayEnd])
        assertParserEvents("1 2", streaming: true, [.int64Value(1), .int64Value(2)])
        assertParserEvents("{\"a\": 1}{\"a\": 2}", streaming: true, [.objectStart, .stringValue("a"), .int64Value(1), .objectEnd, .objectStart, .stringValue("a"), .int64Value(2), .objectEnd])
        
        assertParserEvents("[1]q", streaming: true, [.arrayStart, .int64Value(1), .arrayEnd, .error(JSONParserError(code: .invalidSyntax, line: 0, column: 4))])
    }
    
    func testErrorPatternMatching() {
        // Make sure ~= works on JSONParserError.Code like it does on Foundation errors.
        
        do {
            throw JSONParserError(code: .unexpectedEOF, line: 5, column: 12)
        } catch JSONParserError.unexpectedEOF {
            // success
        } catch {
            XCTFail()
        }
    }
}

private func assertParserEvents(_ input: String, streaming: Bool = false, _ events: [JSONEvent], file: StaticString = #file, line: UInt = #line) {
    let parser = JSONParser(input.unicodeScalars, options: JSONParserOptions(streaming: streaming))
    var iter = parser.makeIterator()
    for (i, expected) in events.enumerated() {
        guard let event = iter.next() else {
            XCTFail("expected event at position \(i+1), found nil", file: file, line: line)
            return
        }
        if event != expected {
            XCTFail("parser event \(i+1) (\(event)) is not equal to \(expected)", file: file, line: line)
        }
    }
    if let event = iter.next() {
        XCTFail("unexpected parser event \(event)", file: file, line: line)
    }
}

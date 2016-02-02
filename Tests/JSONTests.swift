//
//  JSONTests.swift
//  JSONTests
//
//  Created by Kevin Ballard on 10/8/15.
//
//

import XCTest
import PMJSON

class JSONTests: XCTestCase {
    func assertEqual<T: Equatable>(@autoclosure a: () throws -> T, @autoclosure _ b: () -> T, file: String = __FILE__, line: UInt = __LINE__) {
        do {
            let a = try a()
            XCTAssertEqual(a, b(), file: file, line: line)
        } catch {
            XCTFail(String(error), file: file, line: line)
        }
    }
    
    func assertMatchesJSON(@autoclosure a: () throws -> JSON, @autoclosure _ b: () -> JSON, file: String = __FILE__, line: UInt = __LINE__) {
        do {
            let a = try a(), b = b()
            if !matchesJSON(a, b) {
                XCTFail("expected \(a), found \(b)", file: file, line: line)
            }
        } catch {
            XCTFail(String(error), file: file, line: line)
        }
    }
    
    func testBasic() {
        assertMatchesJSON(try JSON.decode("42"), 42)
        assertMatchesJSON(try JSON.decode("\"hello\""), "hello")
        assertMatchesJSON(try JSON.decode("null"), nil)
        assertMatchesJSON(try JSON.decode("[true, false]"), [true, false])
        assertMatchesJSON(try JSON.decode("[1, 2, 3]"), [1, 2, 3])
        assertMatchesJSON(try JSON.decode("{\"one\": 1, \"two\": 2, \"three\": 3}"), ["one": 1, "two": 2, "three": 3])
    }
    
    func testDouble() {
        assertEqual(try JSON.decode("-5.4272823085455e-05"), -5.4272823085455e-05)
        assertEqual(try JSON.decode("-5.4272823085455e+05"), -5.4272823085455e+05)
    }
    
    func testParserErrorDescription() {
        XCTAssertEqual(String(JSONParserError(code: .UnexpectedEOF, line: 5, column: 12)), "JSONParserError(UnexpectedEOF, line: 5, column: 12)")
    }
    
    lazy var bigJson: NSData = {
        var s = "[\n"
        for _ in 0..<1000 {
            s += "{ \"a\": true, \"b\": null, \"c\":3.1415, \"d\": \"Hello world\", \"e\": [1,2,3]},"
        }
        s += "{}]"
        return s.dataUsingEncoding(NSUTF8StringEncoding)!
    }()
    
    func testCompareCocoa() {
        do {
            let json = try JSON.decode(bigJson)
            let jsonObj = json.plist as! NSObject
            let cocoa = try NSJSONSerialization.JSONObjectWithData(bigJson, options: []) as! NSObject
            XCTAssertEqual(jsonObj, cocoa)
            let cocoa2 = try NSJSONSerialization.JSONObjectWithData(JSON.encodeAsData(json), options: []) as! NSObject
            XCTAssertEqual(jsonObj, cocoa2)
        } catch {
            XCTFail(String(error))
        }
    }
    
    func testDecodePerformance() {
        measureBlock { [bigJson] in
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
        measureBlock { [bigJson] in
            for _ in 0..<10 {
                do {
                    _ = try NSJSONSerialization.JSONObjectWithData(bigJson, options: [])
                } catch {
                    XCTFail("error parsing json: \(error)")
                }
            }
        }
    }
    
    func testEncodePerformance() {
        do {
            let json = try JSON.decode(bigJson)
            measureBlock {
                for _ in 0..<10 {
                    _ = JSON.encodeAsData(json, pretty: false)
                }
            }
        } catch {
            XCTFail("error parsing json: \(error)")
        }
    }
    
    func testEncodeCocoaPerformance() {
        do {
            let json = try JSON.decode(bigJson).plist
            measureBlock {
                for _ in 0..<10 {
                    do {
                        _ = try NSJSONSerialization.dataWithJSONObject(json, options: [])
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
            measureBlock {
                for _ in 0..<10 {
                    _ = JSON.encodeAsData(json, pretty: true)
                }
            }
        } catch {
            XCTFail("error parsing json: \(error)")
        }
    }
    
    func testEncodePrettyCocoaPerformance() {
        do {
            let json = try JSON.decode(bigJson).plist
            measureBlock {
                for _ in 0..<10 {
                    do {
                        _ = try NSJSONSerialization.dataWithJSONObject(json, options: [.PrettyPrinted])
                    } catch {
                        XCTFail("error encoding json: \(error)")
                    }
                }
            }
        } catch {
            XCTFail("error parsing json: \(error)")
        }
    }
}

private func matchesJSON(a: JSON, _ b: JSON) -> Bool {
    switch (a, b) {
    case (.Array(let a), .Array(let b)):
        return a.count == b.count && !zip(a, b).contains({!matchesJSON($0, $1)})
    case (.Object(let a), .Object(let b)):
        var seen = Set<String>()
        for (key, value) in a {
            seen.insert(key)
            guard let bValue = b[key] where matchesJSON(value, bValue) else {
                return false
            }
        }
        return seen.isSupersetOf(b.keys)
    case (.String(let a), .String(let b)):
        return a == b
    case (.Int64(let a), .Int64(let b)):
        return a == b
    case (.Double(let a), .Double(let b)):
        return a == b
    case (.Null, .Null):
        return true
    case (.Bool(let a), .Bool(let b)):
        return a == b
    default:
        return false
    }
}

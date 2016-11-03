//
//  JSONAccessorTests.swift
//  PMJSON
//
//  Created by Kevin Ballard on 11/3/16.
//  Copyright © 2016 Postmates. All rights reserved.
//

import XCTest
import PMJSON

class JSONAccessorTests: XCTestCase {
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
                "Hello",
                [2,4,6]
            ],
            "concat": [["x": [1]], ["x": [2,3]], ["x": []], ["x": [4,5,6]]],
            "integers": [5,4,3]
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
        
        do {
            var elts: [Int] = [], indices: [Int] = []
            try dict.forEachArray("integers") { (elt, idx) in
                elts.append(try elt.getInt())
                indices.append(idx)
            }
            XCTAssertEqual(elts, [5,4,3])
            XCTAssertEqual(indices, [0,1,2])
            
            (elts, indices) = ([], [])
            try dict.object!.forEachArray("integers") { (elt, idx) in
                elts.append(try elt.getInt())
                indices.append(idx)
            }
            XCTAssertEqual(elts, [5,4,3])
            XCTAssertEqual(indices, [0,1,2])
            
            (elts, indices) = ([], [])
            XCTAssertTrue(try dict.forEachArrayOrNil("integers", { (elt, idx) in
                elts.append(try elt.getInt())
                indices.append(idx)
            }))
            XCTAssertEqual(elts, [5,4,3])
            XCTAssertEqual(indices, [0,1,2])
            
            XCTAssertFalse(try dict.forEachArrayOrNil("invalid", { _ in
                XCTFail("this shouldn't be invoked")
            }))
            
            (elts, indices) = ([], [])
            XCTAssertTrue(try dict.object!.forEachArrayOrNil("integers", { (elt, idx) in
                elts.append(try elt.getInt())
                indices.append(idx)
            }))
            XCTAssertEqual(elts, [5,4,3])
            XCTAssertEqual(indices, [0,1,2])
            
            XCTAssertFalse(try dict.object!.forEachArrayOrNil("invalid", { _ in
                XCTFail("this shouldn't be invoked")
            }))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        
        XCTAssertThrowsError(try dict["array"]!.mapArray("xs", { _ in 1 }))
        XCTAssertThrowsError(try dict["array"]!.mapArrayOrNil("xs", { _ in 1 }))
        XCTAssertThrowsError(try dict["array"]!.flatMapArray("xs", { _ -> Int? in 1 }))
        XCTAssertThrowsError(try dict["array"]!.flatMapArray("xs", { _ in [1] }))
        XCTAssertThrowsError(try dict["array"]!.flatMapArrayOrNil("xs", { _ -> Int? in 1 }))
        XCTAssertThrowsError(try dict["array"]!.flatMapArrayOrNil("xs", { _ in [1] }))
        XCTAssertThrowsError(try dict["array"]!.forEachArray("xs", { _ in () }))
        XCTAssertThrowsError(try dict["array"]!.forEachArrayOrNil("xs", { _ in () }))
        
        // array-style accessors
        let array = dict["array"]!
        XCTAssertEqual([1,2,3], try array.mapArray(0, { try $0.getInt("x") }))
        XCTAssertThrowsError(try array.mapArray(1, { try $0.getInt("y") }))
        XCTAssertEqual([2,0,1,3], try array.mapArray(2, { try $0.getArray("x").count }))
        XCTAssertThrowsError(try array.mapArray(3, { _ in 1 })) // null
        XCTAssertThrowsError(try array.mapArray(4, { _ in 1 })) // string
        XCTAssertThrowsError(try array.mapArray(100, { _ in 1 })) // out of bounds
        XCTAssertThrowsError(try array.mapArray(0, { _ in throw DummyError() })) { error in
            XCTAssert(error is DummyError, "expected DummyError, found \(error)")
        }
        
        XCTAssertEqual([1,2,3], try array.mapArrayOrNil(0, { try $0.getInt("x") }) ?? [])
        XCTAssertThrowsError(try array.mapArrayOrNil(1, { try $0.getInt("y") }))
        XCTAssertEqual([2,0,1,3], try array.mapArrayOrNil(2, { try $0.getArray("x").count }) ?? [])
        XCTAssertNil(try array.mapArrayOrNil(3, { _ in 1 })) // null
        XCTAssertThrowsError(try array.mapArrayOrNil(4, { _ in 1 })) // string
        XCTAssertNil(try array.mapArrayOrNil(100, { _ in 1 })) // out of bounds
        XCTAssertThrowsError(try array.mapArrayOrNil(0, { _ in throw DummyError() })) { error in
            XCTAssert(error is DummyError, "expected DummyError, found \(error)")
        }
        
        XCTAssertEqual([1,3], try array.flatMapArray(1, { try $0.getIntOrNil("y") }))
        XCTAssertEqual([1,2,3,4,5,6], try array.flatMapArray(2, { try $0.mapArray("x", { try $0.getInt() }) }))
        XCTAssertThrowsError(try array.flatMapArray(3, { _ in [1] })) // null
        XCTAssertThrowsError(try array.flatMapArray(4, { _ in [1] })) // string
        XCTAssertThrowsError(try array.flatMapArray(100, { _ in [1] })) // out of bounds
        XCTAssertThrowsError(try array.flatMapArray(0, { _ -> [Int] in throw DummyError() })) { error in
            XCTAssert(error is DummyError, "expected DummyError, found \(error)")
        }
        
        XCTAssertEqual([1,3], try array.flatMapArrayOrNil(1, { try $0.getIntOrNil("y") }) ?? [])
        XCTAssertEqual([1,2,3,4,5,6], try array.flatMapArrayOrNil(2, { try $0.mapArray("x", { try $0.getInt() }) }) ?? [])
        XCTAssertNil(try array.flatMapArrayOrNil(3, { _ in [1] })) // null
        XCTAssertThrowsError(try array.flatMapArrayOrNil(4, { _ in [1] })) // string
        XCTAssertNil(try array.flatMapArrayOrNil(100, { _ in [1] })) // out of bounds
        XCTAssertThrowsError(try array.flatMapArrayOrNil(0, { _ -> [Int] in throw DummyError() })) { error in
            XCTAssert(error is DummyError, "expected DummyError, found \(error)")
        }
        
        XCTAssertThrowsError(try dict.mapArray(0, { _ in 1 }))
        XCTAssertThrowsError(try dict.mapArrayOrNil(0, { _ in 1 }))
        XCTAssertThrowsError(try dict.flatMapArray(0, { _ in 1 }))
        XCTAssertThrowsError(try dict.flatMapArrayOrNil(0, { _ in 1 }))
        
        do {
            var elts: [Int] = [], indices: [Int] = []
            try array.forEachArray(5) { (elt, idx) in
                elts.append(try elt.getInt())
                indices.append(idx)
            }
            XCTAssertEqual(elts, [2, 4, 6])
            XCTAssertEqual(indices, [0,1,2])
            
            XCTAssertThrowsError(try array.forEachArray(3, { _ in // null
                XCTFail("this shouldn't be invoked")
            }))
            XCTAssertThrowsError(try array.forEachArray(4, { _ in // string
                XCTFail("this shouldn't be invoked")
            }))
            XCTAssertThrowsError(try array.forEachArray(100, { _ in // out of bounds
                XCTFail("this shouldn't be invoked")
            }))
            
            (elts, indices) = ([], [])
            XCTAssertTrue(try array.forEachArrayOrNil(5, { (elt, idx) in
                elts.append(try elt.getInt())
                indices.append(idx)
            }))
            XCTAssertEqual(elts, [2, 4, 6])
            XCTAssertEqual(indices, [0,1,2])
            
            XCTAssertFalse(try array.forEachArrayOrNil(3, { _ in // null
                XCTFail("this shouldn't be invoked")
            }))
            XCTAssertThrowsError(try array.forEachArrayOrNil(4, { _ in // string
                XCTFail("this shouldn't be invoked")
            }))
            XCTAssertFalse(try array.forEachArrayOrNil(100, { _ in // out of bounds
                XCTFail("this shouldn't be invoked")
            }))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
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
        
        #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS)
            XCTAssertNil(json.decimal)
            json.decimal = 42
            XCTAssertEqual(json, 42)
            json.decimal = nil
            XCTAssertEqual(json, JSON.null)
        #endif
        
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
    
    func testMixedTypeEquality() {
        XCTAssertEqual(JSON.int64(42), JSON.double(42))
        XCTAssertNotEqual(JSON.int64(42), JSON.double(42.1))
        XCTAssertEqual(JSON.int64(42), JSON.decimal(42))
        XCTAssertEqual(JSON.int64(Int64.max), JSON.decimal(Decimal(string: "9223372036854775807")!)) // Decimal(Int64.max) produces the wrong value
        XCTAssertEqual(JSON.int64(7393662029337442), JSON.decimal(Decimal(string: "7393662029337442")!))
        XCTAssertNotEqual(JSON.int64(42), JSON.decimal(42.1))
        XCTAssertEqual(JSON.double(42), JSON.decimal(42))
        XCTAssertEqual(JSON.double(42.1), JSON.decimal(42.1))
        XCTAssertEqual(JSON.double(1e100), JSON.decimal(Decimal(string: "1e100")!)) // Decimal(_: Double) can produce incorrect values
    }
}

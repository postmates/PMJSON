//
//  JSONSwiftCheck.swift
//  PMJSON
//
//  Created by Kevin Ballard on 11/10/15.
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
import SwiftCheck

class JSONSwiftCheck: XCTestCase {
    func testProperties() {
        property("JSON can round-trip through Foundation and still remain equal") <- forAll { (json: JSON) in
            do {
                let object = json.ns
                let json2 = try JSON(ns: object)
                return json.approximatelyEqual(json2)
            } catch {
                return TestResult.failed("Test case threw an exception: \(error)").counterexample(String(json))
            }
        }
        
        property("JSON can always decode the compact JSON output of NSJSONSerialization") <- {
            let g = JSON.arbitrary.suchThat({ $0.isObject || $0.isArray })
            return forAll(g) { json in
                do {
                    let object = json.ns
                    let data = try NSJSONSerialization.dataWithJSONObject(object, options: [])
                    let decoded = try JSON.decode(data)
                    return decoded.approximatelyEqual(json)
                } catch {
                    return TestResult.failed("Test case threw an exception: \(error)").counterexample(String(json))
                }
            }
        }
        
        property("JSON can always decode the pretty-printed JSON output of NSJSONSerialization") <- {
            let g = JSON.arbitrary.suchThat({ $0.isObject || $0.isArray })
            return forAll(g) { json in
                do {
                    let object = json.ns
                    guard NSJSONSerialization.isValidJSONObject(object) else {
                        return TestResult.failed("JSON object is not valid for NSJSONSerialization").counterexample(String(json))
                    }
                    let data = try NSJSONSerialization.dataWithJSONObject(object, options: .PrettyPrinted)
                    do {
                        let decoded = try JSON.decode(data)
                        return decoded.approximatelyEqual(json)
                    } catch {
                        return TestResult.failed("Test case threw an exception: \(error)").counterexample(String(data: data, encoding: NSUTF8StringEncoding) ?? "(decode failure)").counterexample(String(json))
                    }
                } catch {
                    return TestResult.failed("Test case threw an exception: \(error)").counterexample(String(json))
                }
            }
        }
        
        property("JSON can always decode the output of JSON.encodeAsString(pretty: false)") <- {
            let g = JSON.arbitrary
            return forAll(g) { json in
                do {
                    let s = JSON.encodeAsString(json, pretty: false)
                    let json2 = try JSON.decode(s)
                    return json2.approximatelyEqual(json)
                } catch {
                    return TestResult.failed("Test case threw an exception: \(error)").counterexample(String(json))
                }
            }
        }
        
        property("JSON can always decode the output of JSON.encodeAsString(pretty: true)") <- {
            let g = JSON.arbitrary
            return forAll(g) { json in
                do {
                    let s = JSON.encodeAsString(json, pretty: true)
                    let json2 = try JSON.decode(s)
                    return json2.approximatelyEqual(json)
                } catch {
                    return TestResult.failed("Test case threw an exception: \(error)").counterexample(String(json))
                }
            }
        }
        
        property("NSJSONSerialization can always decode the output of JSON.encodeAsData(pretty: false)") <- {
            let g = JSON.arbitrary
            return forAll(g) { json in
                do {
                    let data = JSON.encodeAsData(json, pretty: false)
                    let cocoa = try NSJSONSerialization.JSONObjectWithData(data, options: [.AllowFragments])
                    let json2 = try JSON(ns: cocoa)
                    return json2.approximatelyEqual(json)
                } catch {
                    return TestResult.failed("Test case threw an exception: \(error)").counterexample(String(json))
                }
            }
        }
        
        property("NSJSONSerialization can always decode the output of JSON.encodeAsData(pretty: true)") <- {
            let g = JSON.arbitrary
            return forAll(g) { json in
                do {
                    let data = JSON.encodeAsData(json, pretty: true)
                    let cocoa = try NSJSONSerialization.JSONObjectWithData(data, options: [.AllowFragments])
                    let json2 = try JSON(ns: cocoa)
                    return json2.approximatelyEqual(json)
                } catch {
                    return TestResult.failed("Test case threw an exception: \(error)").counterexample(String(json))
                }
            }
        }
        
        property("JSON's Streamable, description, and debugDescription should be based on the JSON-encoded string") <- {
            let g = JSON.arbitrary
            return forAll(g) { json in
                // Streamable and description are the JSON-encoded string directly.
                // debugDescription is the JSON-encoded string wrapped in "JSON()".
                let encoded = JSON.encodeAsString(json, pretty: false)
                var streamOutput = ""
                json.writeTo(&streamOutput)
                guard streamOutput == encoded else {
                    return TestResult.failed("Streamable output does not match encoded JSON string").counterexample(String(json))
                }
                guard json.description == encoded else {
                    return TestResult.failed("description does not match encoded JSON string").counterexample(String(json))
                }
                guard json.debugDescription == "JSON(\(encoded))" else {
                    return TestResult.failed("debugDescription does not match expected output").counterexample(String(json))
                }
                return TestResult.succeeded
            }
        }
        
        property("JSONObject's Streamable, description, and debugDescription should be based on the JSON-encoded string") <- {
            let g = JSONObject.arbitrary
            return forAll(g) { jsonObj in
                // Streamable and description are the JSON-encoded string directly.
                // debugDescription is the JSON-encoded string wrapped in "JSONObject()".
                let encoded = JSON.encodeAsString(JSON(jsonObj), pretty: false)
                var streamOutput = ""
                jsonObj.writeTo(&streamOutput)
                guard streamOutput == encoded else {
                    return TestResult.failed("Streamable output does not match encoded JSON string").counterexample(String(jsonObj))
                }
                guard jsonObj.description == encoded else {
                    return TestResult.failed("description does not match encoded JSON string").counterexample(String(jsonObj))
                }
                guard jsonObj.debugDescription == "JSONObject(\(encoded))" else {
                    return TestResult.failed("debugDescription does not match expected output").counterexample(String(jsonObj))
                }
                return TestResult.succeeded
            }
        }
    }
}

extension JSON {
    /// Performs an equality test, but accepts nearly-equal `Double` values.
    func approximatelyEqual(other: JSON) -> Swift.Bool {
        switch (self, other) {
        case (.Double(let a), .Double(let b)):
            // we're going to cheat and just convert them to Floats and compare that way.
            // We just care about equal up to a given precision, and so dropping down to Float precision should give us that.
            return Float(a) == Float(b)
        case (.Array(let a), .Array(let b)):
            return a.count == b.count && !zip(a, b).lazy.contains({ !$0.approximatelyEqual($1) })
        case (.Object(let a), .Object(let b)):
            return a.count == b.count && !a.contains({ (k,v) in b[k].map({ !$0.approximatelyEqual(v) }) ?? true })
        default:
            return self == other
        }
    }
}

extension JSON: Arbitrary {
    public static var arbitrary: Gen<JSON> {
        return Gen.oneOf([
            Gen.pure(JSON.Null),
            JSON.Bool <^> Swift.Bool.arbitrary,
            JSON.String <^> Swift.String.arbitrary,
            JSON.Int64 <^> Swift.Int64.arbitrary,
            JSON.Double <^> Swift.Double.arbitrary,
            Gen.sized({ n in (JSON.Object <^> JSONObject.arbitrary).resize(n/2) }),
            Gen.sized({ n in (JSON.Array <^> JSONArray.arbitrary).resize(n/2) })
            ])
    }
    
    // NB: the following is unusable because it produces a truly massive list of shrink candidates for any
    // non-trivial JSON structure. Don't use it. Code is provided just for curiosity's sake.
//    public static func shrink(json: JSON) -> [JSON] {
//        switch json {
//        case .Null: return []
//        case .Bool(let b): return Swift.Bool.shrink(b).map(JSON.Bool)
//        case .String(let s): return Swift.String.shrink(s).map(JSON.String)
//        case .Int64(let i): return Swift.Int64.shrink(i).map(JSON.Int64)
//        case .Double(let d): return Swift.Double.shrink(d).map(JSON.Double)
//        case .Object(let obj): return Swift.Dictionary.shrink(obj.dictionary).map({ JSON.Object(JSONObject($0)) })
//        case .Array(let ary): return Swift.ContiguousArray.shrink(ary).map(JSON.Array)
//        }
//    }
}

extension JSONObject: Arbitrary {
    public static var arbitrary: Gen<JSONObject> {
        return Gen.sized({ n in ({ JSONObject($0) } <^> Dictionary<Swift.String,JSON>.arbitrary).resize(n/2) })
    }
}

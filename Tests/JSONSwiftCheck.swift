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
        property("JSON can round-trip through Foundation and still remain equal", arguments: CheckerArguments(replay: (StdGen(1737952920,8460), 1))) <- forAll { (json: JSON) in
            do {
                let object = json.ns
                let json2 = try JSON(ns: object)
                return json.approximatelyEqual(json2)
            } catch {
                return TestResult.failed("Test case threw an exception: \(error)").counterexample(String(describing: json))
            }
        }
        
        property("JSON can always decode the compact JSON output of JSONSerialization") <- {
            let g = JSON.arbitrary.suchThat({ $0.isObject || $0.isArray })
            return forAll(g) { json in
                do {
                    let object = json.ns
                    let data = try JSONSerialization.data(withJSONObject: object)
                    let decoded = try JSON.decode(data)
                    return decoded.approximatelyEqual(json)
                } catch {
                    return TestResult.failed("Test case threw an exception: \(error)").counterexample(String(describing: json))
                }
            }
        }
        
        property("JSON can always decode the pretty-printed JSON output of JSONSerialization") <- {
            let g = JSON.arbitrary.suchThat({ $0.isObject || $0.isArray })
            return forAll(g) { json in
                do {
                    let object = json.ns
                    guard JSONSerialization.isValidJSONObject(object) else {
                        return TestResult.failed("JSON object is not valid for JSONSerialization").counterexample(String(describing: json))
                    }
                    let data = try JSONSerialization.data(withJSONObject: object, options: .prettyPrinted)
                    do {
                        let decoded = try JSON.decode(data)
                        return decoded.approximatelyEqual(json)
                    } catch {
                        return TestResult.failed("Test case threw an exception: \(error)").counterexample(String(data: data, encoding: String.Encoding.utf8) ?? "(decode failure)").counterexample(String(describing: json))
                    }
                } catch {
                    return TestResult.failed("Test case threw an exception: \(error)").counterexample(String(describing: json))
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
                    return TestResult.failed("Test case threw an exception: \(error)").counterexample(String(describing: json))
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
                    return TestResult.failed("Test case threw an exception: \(error)").counterexample(String(describing: json))
                }
            }
        }
        
        property("JSONSerialization can always decode the output of JSON.encodeAsData(pretty: false)") <- {
            let g = JSON.arbitrary
            return forAll(g) { json in
                do {
                    let data = JSON.encodeAsData(json, pretty: false)
                    let cocoa = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
                    let json2 = try JSON(ns: cocoa)
                    return json2.approximatelyEqual(json)
                } catch {
                    return TestResult.failed("Test case threw an exception: \(error)").counterexample(String(describing: json))
                }
            }
        }
        
        property("JSONSerialization can always decode the output of JSON.encodeAsData(pretty: true)") <- {
            let g = JSON.arbitrary
            return forAll(g) { json in
                do {
                    let data = JSON.encodeAsData(json, pretty: true)
                    let cocoa = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
                    let json2 = try JSON(ns: cocoa)
                    return json2.approximatelyEqual(json)
                } catch {
                    return TestResult.failed("Test case threw an exception: \(error)").counterexample(String(describing: json))
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
                json.write(to: &streamOutput)
                guard streamOutput == encoded else {
                    return TestResult.failed("Streamable output does not match encoded JSON string").counterexample(String(describing: json))
                }
                guard json.description == encoded else {
                    return TestResult.failed("description does not match encoded JSON string").counterexample(String(describing: json))
                }
                guard json.debugDescription == "JSON(\(encoded))" else {
                    return TestResult.failed("debugDescription does not match expected output").counterexample(String(describing: json))
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
                jsonObj.write(to: &streamOutput)
                guard streamOutput == encoded else {
                    return TestResult.failed("Streamable output does not match encoded JSON string").counterexample(String(describing: jsonObj))
                }
                guard jsonObj.description == encoded else {
                    return TestResult.failed("description does not match encoded JSON string").counterexample(String(describing: jsonObj))
                }
                guard jsonObj.debugDescription == "JSONObject(\(encoded))" else {
                    return TestResult.failed("debugDescription does not match expected output").counterexample(String(describing: jsonObj))
                }
                return TestResult.succeeded
            }
        }
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
            return a.count == b.count && !a.contains(where: { (k,v) in b[k].map({ !$0.approximatelyEqual(v) }) ?? true })
        default:
            return self == other
        }
    }
}

extension JSON: Arbitrary {
    public static var arbitrary: Gen<JSON> {
        return Gen.oneOf([
            Gen.pure(JSON.null),
            Bool.arbitrary.map(JSON.bool),
            String.arbitrary.map(JSON.string),
            Int64.arbitrary.map(JSON.int64),
            Double.arbitrary.map(JSON.double),
            Gen.sized({ n in (JSONObject.arbitrary.map(JSON.object)).resize(n/2) }),
            Gen.sized({ n in (JSONArray.arbitrary.map(JSON.array)).resize(n/2) })
            ])
    }
    
    // NB: the following is unusable because it produces a truly massive list of shrink candidates for any
    // non-trivial JSON structure. Don't use it. Code is provided just for curiosity's sake.
//    public static func shrink(json: JSON) -> [JSON] {
//        switch json {
//        case .null: return []
//        case .bool(let b): return Bool.shrink(b).map(JSON.Bool)
//        case .string(let s): return String.shrink(s).map(JSON.String)
//        case .int64(let i): return Int64.shrink(i).map(JSON.Int64)
//        case .double(let d): return Double.shrink(d).map(JSON.Double)
//        case .object(let obj): return Dictionary.shrink(obj.dictionary).map({ JSON.Object(JSONObject($0)) })
//        case .array(let ary): return ContiguousArray.shrink(ary).map(JSON.Array)
//        }
//    }
}

extension JSONObject: Arbitrary {
    public static var arbitrary: Gen<JSONObject> {
        return Gen.sized({ n in Dictionary<String,JSON>.arbitrary.map({ JSONObject($0) }).resize(n/2) })
    }
}

//
//  ObjectiveC.swift
//  PMJSON
//
//  Created by Kevin Ballard on 10/9/15.
//  Copyright © 2016 Postmates.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#if os(iOS) || os(OSX) || os(watchOS) || os(tvOS)
    
    import Foundation
    
    extension JSON {
        /// Decodes a `Data` as JSON.
        /// - Note: Invalid UTF8 sequences in the data are replaced with U+FFFD.
        /// - Parameter strict: If `true`, trailing commas in arrays/objects are treated as errors. Default is `false`.
        /// - Returns: A `JSON` value.
        /// - Throws: `JSONParserError` if the data does not contain valid JSON.
        public static func decode(_ data: Data, strict: Bool = false) throws -> JSON {
            return try JSON.decode(UTF8Decoder(data: data), strict: strict)
        }
        
        /// Encodes a `JSON` to a `Data`.
        /// - Parameter json: The `JSON` to encode.
        /// - Parameter pretty: If `true`, include extra whitespace for formatting. Default is `false`.
        /// - Returns: An `NSData` with the JSON representation of *json*.
        public static func encodeAsData(_ json: JSON, pretty: Bool = false) -> Data {
            struct Output: OutputStream {
                // NB: We use NSMutableData instead of Data because it's significantly faster as of Xcode 8b3
                var data = NSMutableData()
                mutating func write(_ string: String) {
                    let oldLen = data.length
                    data.increaseLength(by: string.utf8.count)
                    let ptr = UnsafeMutablePointer<UInt8>(data.mutableBytes) + oldLen
                    for (i, x) in string.utf8.enumerated() {
                        ptr[i] = x
                    }
                }
            }
            var output = Output()
            JSON.encode(json, toStream: &output, pretty: pretty)
            return output.data as Data
        }
    }
    
    extension JSON {
        /// Converts a JSON-compatible Foundation object into a `JSON` value.
        /// - Note: Deprecated in favor of `init(ns:)`.
        /// - Throws: `JSONFoundationError` if the object is not JSON-compatible.
        @available(*, deprecated, renamed: "init(ns:)")
        public init(plist: AnyObject) throws {
            try self.init(ns: plist)
        }
        
        /// Converts a JSON-compatible Foundation object into a `JSON` value.
        /// - Throws: `JSONFoundationError` if the object is not JSON-compatible.
        public init(ns object: AnyObject) throws {
            if object === kCFBooleanTrue {
                self = .bool(true)
                return
            } else if object === kCFBooleanFalse {
                self = .bool(false)
                return
            }
            switch object {
            case is NSNull:
                self = .null
            case let n as NSNumber:
                let typeChar: UnicodeScalar
                let objCType = UnsafePointer<UInt8>(n.objCType)
                if objCType[0] == 0 || objCType[1] != 0 {
                    typeChar = "?"
                } else {
                    typeChar = UnicodeScalar(objCType[0])
                }
                switch typeChar {
                case "c", "i", "s", "l", "q", "C", "I", "S", "L", "B":
                    self = .int64(n.int64Value)
                case "Q": // unsigned long long
                    let val = n.uint64Value
                    if val > UInt64(Int64.max) {
                        fallthrough
                    }
                    self = .int64(Int64(val))
                default:
                    self = .double(n.doubleValue)
                }
            case let s as String:
                self = .string(s)
            case let dict as NSDictionary:
                var obj: [String: JSON] = Dictionary(minimumCapacity: dict.count)
                for (key, value) in dict {
                    guard let key = key as? String else { throw JSONFoundationError.nonStringKey }
                    obj[key] = try JSON(ns: value)
                }
                self = .object(JSONObject(obj))
            case let array as NSArray:
                var ary: JSONArray = []
                ary.reserveCapacity(array.count)
                for elt in array {
                    ary.append(try JSON(ns: elt))
                }
                self = .array(ary)
            default:
                throw JSONFoundationError.incompatibleType
            }
        }
        
        /// Returns the JSON as a JSON-compatible Foundation object.
        /// - Note: Deprecated in favor of `ns`.
        @available(*, deprecated, renamed: "ns")
        public var plist: AnyObject {
            return ns
        }
        
        /// Returns the JSON as a JSON-compatible Foundation object.
        public var ns: AnyObject {
            switch self {
            case .null: return NSNull()
            case .bool(let b): return b as NSNumber
            case .string(let s): return s
            case .int64(let i): return NSNumber(value: i)
            case .double(let d): return d
            case .object(let obj): return obj.ns
            case .array(let ary):
                return ary.map({$0.ns})
            }
        }
        
        /// Returns the JSON as a JSON-compatible Foundation object, discarding any nulls.
        /// - Note: Deprecated in favor of `nsNoNull`.
        @available(*, deprecated, renamed: "nsNoNull")
        public var plistNoNull: AnyObject? {
            return nsNoNull
        }
        
        /// Returns the JSON as a JSON-compatible Foundation object, discarding any nulls.
        public var nsNoNull: AnyObject? {
            switch self {
            case .null: return nil
            case .bool(let b): return b as NSNumber
            case .string(let s): return s
            case .int64(let i): return NSNumber(value: i)
            case .double(let d): return d
            case .object(let obj): return obj.nsNoNull
            case .array(let ary):
                return ary.flatMap({$0.nsNoNull})
            }
        }
    }
    
    extension JSONObject {
        /// Returns the JSON as a JSON-compatible dictionary.
        /// - Note: Deprecated in favor of `ns`.
        @available(*, deprecated, renamed: "ns")
        public var plist: [NSObject: AnyObject] {
            return ns
        }
        
        /// Returns the JSON as a JSON-compatible dictionary.
        public var ns: [NSObject: AnyObject] {
            var dict: [NSObject: AnyObject] = Dictionary(minimumCapacity: count)
            for (key, value) in self {
                dict[key] = value.ns
            }
            return dict
        }
        
        /// Returns the JSON as a JSON-compatible dictionary, discarding any nulls.
        /// - Note: Deprecated in favor of `nsNoNull`.
        @available(*, deprecated, renamed: "nsNoNull")
        public var plistNoNull: [NSObject: AnyObject] {
            return nsNoNull
        }
        
        /// Returns the JSON as a JSON-compatible dictionary, discarding any nulls.
        public var nsNoNull: [NSObject: AnyObject] {
            var dict: [NSObject: AnyObject] = Dictionary(minimumCapacity: count)
            for (key, value) in self {
                if let value = value.nsNoNull {
                    dict[key] = value
                }
            }
            return dict
        }
    }
    
    /// An error that is thrown when converting from `AnyObject` to `JSON`.
    /// - Note: Deprecated in favor of `JSONFoundationError`.
    /// - SeeAlso: `JSON.init(ns:)`
    @available(*, deprecated, renamed: "JSONFoundationError")
    public typealias JSONPlistError = JSONFoundationError
    
    /// An error that is thrown when converting from `AnyObject` to `JSON`.
    /// - SeeAlso: `JSON.init(ns:)`
    public enum JSONFoundationError: ErrorProtocol {
        /// Thrown when a non-JSON-compatible type is found.
        case incompatibleType
        /// Thrown when a dictionary has a key that is not a string.
        case nonStringKey
    }
    
    public extension JSONError {
        /// Registers the `NSError` userInfo provider for `JSONError`.
        @available(iOS 9, OSX 10.11, *)
        static func registerNSErrorUserInfoProvider() {
            _ = _lazyRegister
        }
        
        @available(iOS 9, OSX 10.11, *)
        private static var _lazyRegister: () = {
            NSError.setUserInfoValueProvider(forDomain: "PMJSON.JSONError") { (error, key) in
                guard let error = error as ErrorProtocol as? JSONError else { return nil }
                switch key {
                case NSLocalizedDescriptionKey:
                    return String(error)
                default:
                    return nil
                }
            }
        }()
    }
    
    private struct UTF8Decoder: Sequence {
        init(data: Data) {
            self.data = data as NSData
        }
        
        func makeIterator() -> Iterator {
            return Iterator(data: data)
        }
        
        private let data: NSData
        
        private struct Iterator: IteratorProtocol {
            init(data: NSData) {
                // NB: We use NSData instead of using Data's iterator because it's significantly faster as of Xcode 8b3
                self.data = data
                let ptr = UnsafeBufferPointer(start: UnsafePointer<UInt8>(data.bytes), count: data.length)
                gen = ptr.makeIterator()
                utf8 = UTF8()
            }
            
            mutating func next() -> UnicodeScalar? {
                switch utf8.decode(&gen) {
                case .scalarValue(let scalar): return scalar
                case .error: return "\u{FFFD}"
                case .emptyInput: return nil
                }
            }
            
            private let data: NSData
            private var gen: UnsafeBufferPointerIterator<UInt8>
            private var utf8: UTF8
        }
    }
    
#endif // os(iOS) || os(OSX) || os(watchOS) || os(tvOS)

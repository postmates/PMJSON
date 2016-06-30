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
        /// Decodes an `NSData` as JSON.
        /// - Note: Invalid UTF8 sequences in the data are replaced with U+FFFD.
        /// - Parameter strict: If `true`, trailing commas in arrays/objects are treated as errors. Default is `false`.
        /// - Returns: A `JSON` value.
        /// - Throws: `JSONParserError` if the data does not contain valid JSON.
        public static func decode(data: NSData, strict: Swift.Bool = false) throws -> JSON {
            return try JSON.decode(UTF8Decoder(data: data), strict: strict)
        }
        
        /// Encodes a `JSON` to an `NSData`.
        /// - Parameter json: The `JSON` to encode.
        /// - Parameter pretty: If `true`, include extra whitespace for formatting. Default is `false`.
        /// - Returns: An `NSData` with the JSON representation of *json*.
        public static func encodeAsData(json: JSON, pretty: Swift.Bool = false) -> NSData {
            struct Output: OutputStreamType {
                let data = NSMutableData()
                func write(string: Swift.String) {
                    let oldLen = data.length
                    data.increaseLengthBy(string.utf8.count)
                    let ptr = UnsafeMutablePointer<UInt8>(data.mutableBytes) + oldLen
                    for (i, x) in string.utf8.enumerate() {
                        ptr[i] = x
                    }
                }
            }
            var output = Output()
            JSON.encode(json, toStream: &output, pretty: pretty)
            return output.data
        }
    }
    
    extension JSON {
        /// Converts a JSON-compatible Foundation object into a `JSON` value.
        /// - Note: Deprecated in favor of `init(ns:)`.
        /// - Throws: `JSONFoundationError` if the object is not JSON-compatible.
        @available(*, deprecated, renamed="init(ns:)")
        public init(plist: AnyObject) throws {
            try self.init(ns: plist)
        }
        
        /// Converts a JSON-compatible Foundation object into a `JSON` value.
        /// - Throws: `JSONFoundationError` if the object is not JSON-compatible.
        public init(ns object: AnyObject) throws {
            if object === kCFBooleanTrue {
                self = .Bool(true)
                return
            } else if object === kCFBooleanFalse {
                self = .Bool(false)
                return
            }
            switch object {
            case is NSNull:
                self = .Null
            case let n as NSNumber:
                let typeChar: UnicodeScalar
                let objCType = UnsafePointer<UInt8>(n.objCType)
                if objCType == nil || objCType[0] == 0 || objCType[1] != 0 {
                    typeChar = "?"
                } else {
                    typeChar = UnicodeScalar(objCType[0])
                }
                switch typeChar {
                case "c", "i", "s", "l", "q", "C", "I", "S", "L", "B":
                    self = .Int64(n.longLongValue)
                case "Q": // unsigned long long
                    let val = n.unsignedLongLongValue
                    if val > UInt64(Swift.Int64.max) {
                        fallthrough
                    }
                    self = .Int64(Swift.Int64(val))
                default:
                    self = .Double(n.doubleValue)
                }
            case let s as Swift.String:
                self = .String(s)
            case let dict as NSDictionary:
                var obj: [Swift.String: JSON] = Dictionary(minimumCapacity: dict.count)
                for (key, value) in dict {
                    guard let key = key as? Swift.String else { throw JSONFoundationError.NonStringKey }
                    obj[key] = try JSON(ns: value)
                }
                self = .Object(JSONObject(obj))
            case let array as NSArray:
                var ary: JSONArray = []
                ary.reserveCapacity(array.count)
                for elt in array {
                    ary.append(try JSON(ns: elt))
                }
                self = .Array(ary)
            default:
                throw JSONFoundationError.IncompatibleType
            }
        }
        
        /// Returns the JSON as a JSON-compatible Foundation object.
        /// - Note: Deprecated in favor of `ns`.
        @available(*, deprecated, renamed="ns")
        public var plist: AnyObject {
            return ns
        }
        
        /// Returns the JSON as a JSON-compatible Foundation object.
        public var ns: AnyObject {
            switch self {
            case .Null: return NSNull()
            case .Bool(let b): return b as NSNumber
            case .String(let s): return s
            case .Int64(let i): return NSNumber(longLong: i)
            case .Double(let d): return d
            case .Object(let obj): return obj.ns
            case .Array(let ary):
                return ary.map({$0.ns})
            }
        }
        
        /// Returns the JSON as a JSON-compatible Foundation object, discarding any nulls.
        /// - Note: Deprecated in favor of `nsNoNull`.
        @available(*, deprecated, renamed="nsNoNull")
        public var plistNoNull: AnyObject? {
            return nsNoNull
        }
        
        /// Returns the JSON as a JSON-compatible Foundation object, discarding any nulls.
        public var nsNoNull: AnyObject? {
            switch self {
            case .Null: return nil
            case .Bool(let b): return b as NSNumber
            case .String(let s): return s
            case .Int64(let i): return NSNumber(longLong: i)
            case .Double(let d): return d
            case .Object(let obj): return obj.nsNoNull
            case .Array(let ary):
                return ary.flatMap({$0.nsNoNull})
            }
        }
    }
    
    extension JSONObject {
        /// Returns the JSON as a JSON-compatible dictionary.
        /// - Note: Deprecated in favor of `ns`.
        @available(*, deprecated, renamed="ns")
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
        @available(*, deprecated, renamed="nsNoNull")
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
    @available(*, deprecated, renamed="JSONFoundationError")
    public typealias JSONPlistError = JSONFoundationError
    
    /// An error that is thrown when converting from `AnyObject` to `JSON`.
    /// - SeeAlso: `JSON.init(ns:)`
    public enum JSONFoundationError: ErrorType {
        /// Thrown when a non-JSON-compatible type is found.
        case IncompatibleType
        /// Thrown when a dictionary has a key that is not a string.
        case NonStringKey
    }
    
    public extension JSONError {
        /// Registers the `NSError` userInfo provider for `JSONError`.
        @available(iOS 9, OSX 10.11, *)
        static func registerNSErrorUserInfoProvider() {
            _ = _lazyRegister
        }
        
        @available(iOS 9, OSX 10.11, *)
        private static var _lazyRegister: () = {
            NSError.setUserInfoValueProviderForDomain("PMJSON.JSONError") { (error, key) in
                guard let error = error as ErrorType as? JSONError else { return nil }
                switch key {
                case NSLocalizedDescriptionKey:
                    return String(error)
                default:
                    return nil
                }
            }
        }()
    }
    
    private struct UTF8Decoder: SequenceType {
        init(data: NSData) {
            self.data = data
        }
        
        func generate() -> Generator {
            return Generator(data: data)
        }
        
        private let data: NSData
        
        private struct Generator: GeneratorType {
            init(data: NSData) {
                self.data = data
                let ptr = UnsafeBufferPointer(start: UnsafePointer<UInt8>(data.bytes), count: data.length)
                gen = ptr.generate()
                utf8 = UTF8()
            }
            
            mutating func next() -> UnicodeScalar? {
                switch utf8.decode(&gen) {
                case .Result(let scalar): return scalar
                case .Error: return "\u{FFFD}"
                case .EmptyInput: return nil
                }
            }
            
            private let data: NSData
            private var gen: UnsafeBufferPointerGenerator<UInt8>
            private var utf8: UTF8
        }
    }
    
#endif // os(iOS) || os(OSX) || os(watchOS) || os(tvOS)

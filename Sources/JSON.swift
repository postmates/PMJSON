//
//  JSON.swift
//  PMJSON
//
//  Created by Kevin Ballard on 10/8/15.
//  Copyright © 2016 Postmates.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#if os(iOS) || os(OSX) || os(watchOS) || os(tvOS) || swift(>=3.1)
    import struct Foundation.Decimal
#else
    /// A placeholder used for platforms that don't support `Decimal`.
    public struct DecimalPlaceholder: Equatable {
        public static func ==(lhs: DecimalPlaceholder, rhs: DecimalPlaceholder) -> Bool {
            return true
        }
    }
#endif

/// A single JSON-compatible value.
public enum JSON {
    /// The null value.
    case null
    /// A boolean.
    case bool(Bool)
    /// A string.
    case string(String)
    /// A 64-bit integer.
    case int64(Int64)
    /// A number.
    /// When decoding, any integer that doesn't fit in 64 bits and any floating-point number
    /// is decoded as a `Double`.
    case double(Double)
    #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS) || swift(>=3.1)
    /// A decimal number.
    /// When the decoding option `.useDecimals` is used, any value that would otherwise be
    /// decoded as a `Double` is decoded as a `Decimal` instead.
    case decimal(Decimal)
    #else
    /// A placeholder for decimal number support.
    /// This exists purely to work around Swift's poor support for conditionally-compiled
    /// enum variants. At such time as Linux gains `Decimal` support, this will turn
    /// into a real case. In the meantime, this case should be ignored.
    case decimal(DecimalPlaceholder)
    #endif
    /// An object.
    case object(JSONObject)
    /// An array.
    case array(JSONArray)
    
    /// Initializes `self` as a boolean with the value `bool`.
    public init(_ bool: Bool) {
        self = .bool(bool)
    }
    /// Initializes `self` as a string with the value `str`.
    public init(_ str: String) {
        self = .string(str)
    }
    /// Initializes `self` as a 64-bit integer with the value `i`.
    public init(_ i: Int64) {
        self = .int64(i)
    }
    /// Initializes `self` as a double with the value `d`.
    public init(_ d: Double) {
        self = .double(d)
    }
    #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS) || swift(>=3.1)
    public init(_ d: Decimal) {
        self = .decimal(d)
    }
    #endif
    /// Initializes `self` as an object with the value `obj`.
    public init(_ obj: JSONObject) {
        self = .object(obj)
    }
    /// Initializes `self` as an array with the value `ary`.
    public init(_ ary: JSONArray) {
        self = .array(ary)
    }
}

// Convenience conversions.
public extension JSON {
    /// Initializes `self` as a 64-bit integer with the value `i`.
    public init(_ i: Int) {
        self = .int64(Int64(i))
    }
    
    /// Initializes `self` as an array with the contents of the sequence `seq`.
    public init<S: Sequence>(_ seq: S) where S.Iterator.Element == JSON {
        self = .array(JSONArray(seq))
    }
    
    /// Initializes `self` as an array with the contents of the sequence `seq`.
    public init<S: Sequence>(_ seq: S) where S.Iterator.Element == JSONObject {
        self = .array(JSONArray(seq.lazy.map(JSON.init)))
    }
    
    /// Initializes `self` as an array with the contents of the sequence `seq`.
    public init<S: Sequence>(_ seq: S) where S.Iterator.Element == JSONArray {
        self = .array(JSONArray(seq.lazy.map(JSON.init)))
    }
}

public typealias JSONArray = ContiguousArray<JSON>

extension JSON: Equatable {
    public static func ==(lhs: JSON, rhs: JSON) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): return true
        case let (.bool(a), .bool(b)): return a == b
        case let (.string(a), .string(b)): return a == b
        case let (.int64(a), .int64(b)): return a == b
        case let (.double(a), .double(b)): return a == b
        case let (.decimal(a), .decimal(b)): return a == b
        case let (.int64(a), .double(b)): return Double(a) == b
        case let (.int64(a), .decimal(b)):
            #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS) || swift(>=3.1)
                return Decimal(workaround: a) == b
            #else
                return false
            #endif
        case let (.double(a), .decimal(b)):
            #if os(iOS) || os(OSX) || os(watchOS) || os(tvOS) || swift(>=3.1)
                return Decimal(workaround: a) == b
            #else
                return false
            #endif
        case (.double, .int64), (.decimal, .int64), (.decimal, .double): return rhs == lhs
        case let (.object(a), .object(b)): return a == b
        case let (.array(a), .array(b)): return a == b
        default: return false
        }
    }
}

extension JSON: TextOutputStreamable, CustomStringConvertible, CustomDebugStringConvertible {
    public func write<Target : TextOutputStream>(to target: inout Target) {
        JSON.encode(self, to: &target)
    }
    
    public var description: String {
        return JSON.encodeAsString(self)
    }
    
    public var debugDescription: String {
        let desc = JSON.encodeAsString(self)
        if case .decimal = self {
            // Call out decimals specially because otherwise they look like regular numbers
            return "JSON.decimal(\(desc))"
        } else {
            return "JSON(\(desc))"
        }
    }
}

extension JSON: ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByBooleanLiteral, ExpressibleByNilLiteral {
    public init(integerLiteral value: Int64) {
        self = .int64(value)
    }
    
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
    
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
    
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension JSON: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        self = .string(value)
    }
    
    public init(unicodeScalarLiteral value: String) {
        self = .string(value)
    }
}

extension JSON: ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    public init(arrayLiteral elements: JSON...) {
        self = .array(JSONArray(elements))
    }
    
    public init(dictionaryLiteral elements: (String, JSON)...) {
        self = .object(JSONObject(elements))
    }
}

extension JSON: CustomReflectable {
    public var customMirror: Mirror {
        switch self {
        case .null, .bool, .string, .int64, .double, .decimal: return Mirror(self, children: [])
        case let .object(obj):
            let children: LazyMapCollection<JSONObject, Mirror.Child> = obj.lazy.map({ ($0, $1) })
            return Mirror(self, children: children, displayStyle: .dictionary)
        case let .array(ary):
            return Mirror(self, unlabeledChildren: ary, displayStyle: .collection)
        }
    }
}

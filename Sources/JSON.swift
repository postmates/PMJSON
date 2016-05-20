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

/// A single JSON-compatible value.
public enum JSON {
    /// The null value.
    case Null
    /// A boolean.
    case Bool(Swift.Bool)
    /// A string.
    case String(Swift.String)
    /// A 64-bit integer.
    case Int64(Swift.Int64)
    /// A number.
    /// When decoding, any integer that doesn't fit in 64 bits and any floating-point number
    /// is decoded as a `Double`.
    case Double(Swift.Double)
    /// An object.
    case Object(JSONObject)
    /// An array.
    case Array(JSONArray)
    
    /// Initializes `self` as a boolean with the value `bool`.
    public init(_ bool: Swift.Bool) {
        self = .Bool(bool)
    }
    /// Initializes `self` as a string with the value `str`.
    public init(_ str: Swift.String) {
        self = .String(str)
    }
    /// Initializes `self` as a 64-bit integer with the value `i`.
    public init(_ i: Swift.Int64) {
        self = .Int64(i)
    }
    /// Initializes `self` as a double with the value `d`.
    public init(_ d: Swift.Double) {
        self = .Double(d)
    }
    /// Initializes `self` as an object with the value `obj`.
    public init(_ obj: JSONObject) {
        self = .Object(obj)
    }
    /// Initializes `self` as an array with the value `ary`.
    public init(_ ary: JSONArray) {
        self = .Array(ary)
    }
}

// Convenience conversions.
public extension JSON {
    /// Initializes `self` as a 64-bit integer with the value `i`.
    public init(_ i: Int) {
        self = .Int64(Swift.Int64(i))
    }
    
    /// Initializes `self` as an array with the contents of the sequence `seq`.
    public init<S: SequenceType where S.Generator.Element == JSON>(_ seq: S) {
        self = .Array(JSONArray(seq))
    }
    
    /// Initializes `self` as an array with the contents of the sequence `seq`.
    public init<S: SequenceType where S.Generator.Element == JSONObject>(_ seq: S) {
        self = .Array(JSONArray(seq.lazy.map(JSON.init)))
    }
    
    /// Initializes `self` as an array with the contents of the sequence `seq`.
    public init<S: SequenceType where S.Generator.Element == JSONArray>(_ seq: S) {
        self = .Array(JSONArray(seq.lazy.map(JSON.init)))
    }
}

public typealias JSONArray = ContiguousArray<JSON>

extension JSON: Equatable {}
public func ==(lhs: JSON, rhs: JSON) -> Bool {
    switch (lhs, rhs) {
    case (.Null, .Null): return true
    case (.Bool(let a), .Bool(let b)): return a == b
    case (.String(let a), .String(let b)): return a == b
    case (.Int64(let a), .Int64(let b)): return a == b
    case (.Double(let a), .Double(let b)): return a == b
    case (.Int64(let a), .Double(let b)): return Double(a) == b
    case (.Double(let a), .Int64(let b)): return a == Double(b)
    case (.Object(let a), .Object(let b)): return a == b
    case (.Array(let a), .Array(let b)): return a == b
    default: return false
    }
}

extension JSON: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: Swift.String {
        switch self {
        case .Null: return "null"
        case .Bool(let b): return Swift.String(b)
        case .String(let s): return Swift.String(reflecting: s)
        case .Int64(let i): return Swift.String(i)
        case .Double(let n): return Swift.String(n)
        case .Object(let obj): return Swift.String(obj)
        case .Array(let ary): return Swift.String(ary)
        }
    }
    
    public var debugDescription: Swift.String {
        switch self {
        case .Null: return "JSON.Null"
        case .Bool(let b): return "JSON.Bool(\(b))"
        case .String(let s): return "JSON.String(\(Swift.String(reflecting: s)))"
        case .Int64(let i): return "JSON.Int64(\(i))"
        case .Double(let n): return "JSON.Double(\(n))"
        case .Object(let obj): return "JSON.Object(\(Swift.String(reflecting: obj)))"
        case .Array(let ary): return "JSON.Array(\(Swift.String(reflecting: ary)))"
        }
    }
}

extension JSON: IntegerLiteralConvertible, FloatLiteralConvertible, BooleanLiteralConvertible, NilLiteralConvertible {
    public init(integerLiteral value: Swift.Int64) {
        self = .Int64(value)
    }
    
    public init(floatLiteral value: Swift.Double) {
        self = .Double(value)
    }
    
    public init(booleanLiteral value: Swift.Bool) {
        self = .Bool(value)
    }
    
    public init(nilLiteral: ()) {
        self = .Null
    }
}

extension JSON: StringLiteralConvertible {
    public init(stringLiteral value: Swift.String) {
        self = .String(value)
    }
    
    public init(extendedGraphemeClusterLiteral value: Swift.String) {
        self = .String(value)
    }
    
    public init(unicodeScalarLiteral value: Swift.String) {
        self = .String(value)
    }
}

extension JSON: ArrayLiteralConvertible, DictionaryLiteralConvertible {
    public init(arrayLiteral elements: JSON...) {
        self = .Array(JSONArray(elements))
    }
    
    public init(dictionaryLiteral elements: (Swift.String, JSON)...) {
        self = .Object(JSONObject(elements))
    }
}

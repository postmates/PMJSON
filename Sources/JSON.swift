//
//  JSON.swift
//  PMJSON
//
//  Created by Kevin Ballard on 10/8/15.
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
    case Array(ContiguousArray<JSON>)
}

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
        self = .Array(ContiguousArray(elements))
    }
    
    public init(dictionaryLiteral elements: (Swift.String, JSON)...) {
        self = .Object(JSONObject(elements))
    }
}

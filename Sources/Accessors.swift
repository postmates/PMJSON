//
//  Accessors.swift
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

public extension JSON {
    /// Returns `true` iff the receiver is `.Null`.
    var isNull: Swift.Bool {
        switch self {
        case .Null: return true
        default: return false
        }
    }
    
    /// Returns `true` iff the receiver is `.Bool`.
    var isBool: Swift.Bool {
        switch self {
        case .Bool: return true
        default: return false
        }
    }
    
    /// Returns `true` iff the receiver is `.String`.
    var isString: Swift.Bool {
        switch self {
        case .String: return true
        default: return false
        }
    }
    
    /// Returns `true` iff the receiver is `.Int64`.
    var isInt64: Swift.Bool {
        switch self {
        case .Int64: return true
        default: return false
        }
    }
    
    /// Returns `true` iff the receiver is `.Double`.
    var isDouble: Swift.Bool {
        switch self {
        case .Double: return true
        default: return false
        }
    }
    
    /// Returns `true` iff the receiver is `.Int64` or `.Double`.
    var isNumber: Swift.Bool {
        switch self {
        case .Int64, .Double: return true
        default: return false
        }
    }
    
    /// Returns `true` iff the receiver is `.Object`.
    var isObject: Swift.Bool {
        switch self {
        case .Object: return true
        default: return false
        }
    }
    
    /// Returns `true` iff the receiver is `.Array`.
    var isArray: Swift.Bool {
        switch self {
        case .Array: return true
        default: return false
        }
    }
}

public extension JSON {
    /// Returns the boolean value if the receiver is `.Bool`, otherwise `nil`.
    var bool: Swift.Bool? {
        switch self {
        case .Bool(let b): return b
        default: return nil
        }
    }
    
    /// Returns the string value if the receiver is `.String`, otherwise `nil`.
    var string: Swift.String? {
        switch self {
        case .String(let s): return s
        default: return nil
        }
    }
    
    /// Returns the 64-bit integral value if the receiver is `.Int64` or `.Double`, otherwise `nil`.
    /// If the receiver is `.Double`, the value is truncated. If it does not fit in 64 bits, `nil` is returned.
    var int64: Swift.Int64? {
        switch self {
        case .Int64(let i): return i
        case .Double(let d): return convertDoubleToInt64(d)
        default: return nil
        }
    }
    
    /// Returns the integral value if the receiver is `.Int64` or `.Double`, otherwise `nil`.
    /// If the receiver is `.Double`, the value is truncated. If it does not fit in an `Int`, `nil` is returned.
    /// If the receiver is `.Int64` and the value does not fit in an `.Int`, `nil` is returned.
    var int: Int? {
        guard let value = int64 else { return nil}
        let truncated = Int(truncatingBitPattern: value)
        guard Swift.Int64(truncated) == value else { return nil }
        return truncated
    }
    
    /// Returns the numeric value as a `Double` if the receiver is `.Int64` or `.Double`, otherwise `nil`.
    var double: Swift.Double? {
        switch self {
        case .Int64(let i): return Swift.Double(i)
        case .Double(let d): return d
        default: return nil
        }
    }
    
    /// Returns the object dictionary if the receiver is `.Object`, otherwise `nil`.
    var object: JSONObject? {
        switch self {
        case .Object(let obj): return obj
        default: return nil
        }
    }
    
    /// Returns the array if the receiver is `.Array`, otherwise `nil`.
    var array: JSONArray? {
        switch self {
        case .Array(let ary): return ary
        default: return nil
        }
    }
}

public extension JSON {
    /// Returns the string value if the receiver is `.String`, coerces the value to a string if
    /// the receiver is `.Bool`, `.Null`, `.Int64`, or `.Double`, or otherwise returns `nil`.
    var asString: Swift.String? {
        return try? toString()
    }
    
    /// Returns the 64-bit integral value if the receiver is `.Int64` or `.Double`, coerces the value
    /// if the receiver is `.String`, otherwise returns `nil`.
    /// If the receiver is `.Double`, the value is truncated. If it does not fit in 64 bits, `nil` is returned.
    /// If the receiver is `.String`, it must parse fully as an integral or floating-point number.
    /// If it parses as a floating-point number, it is truncated. If it does not fit in 64 bits, `nil` is returned.
    var asInt64: Swift.Int64? {
        return try? toInt64()
    }
    
    /// Returns the integral value if the receiver is `.Int64` or `.Double`, coerces the value
    /// if the receiver is `.String`, otherwise returns `nil`.
    /// If the receiver is `.Double`, the value is truncated. If it does not fit in an `Int`, `nil` is returned.
    /// If the receiver is `.String`, it must parse fully as an integral or floating-point number.
    /// If it parses as a floating-point number, it is truncated. If it does not fit in an `Int`, `nil` is returned.
    var asInt: Int? {
        return try? toInt()
    }
    
    /// Returns the double value if the receiver is `.Int64` or `.Double`, coerces the value
    /// if the receiver is `.String`, otherwise returns `nil`.
    /// If the receiver is `.String`, it must parse fully as a floating-point number.
    var asDouble: Swift.Double? {
        return try? toDouble()
    }
}

public extension JSON {
    /// If the receiver is `.Object`, returns the result of subscripting the object.
    /// Otherwise, returns `nil`.
    subscript(key: Swift.String) -> JSON? {
        return object?[key]
    }
    
    /// If the receiver is `.Array` and the index is in range of the array, returns the result of subscripting the array.
    /// Otherwise returns `nil`.
    subscript(index: Int) -> JSON? {
        guard let ary = array else { return nil }
        guard index >= ary.startIndex && index < ary.endIndex else { return nil }
        return ary[index]
    }
}

internal func convertDoubleToInt64(d: Double) -> Int64? {
    // Int64(Double(Int64.max)) asserts because it interprets it as out of bounds.
    // Int64(Double(Int64.min)) works just fine.
    if d >= Double(Int64.max) || d < Double(Int64.min) {
        return nil
    }
    return Int64(d)
}

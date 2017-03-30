//
//  DecimalNumber.swift
//  PMJSON
//
//  Created by Kevin Ballard on 2/8/16.
//  Copyright © 2016 Postmates.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#if os(iOS) || os(OSX) || os(tvOS) || os(watchOS) || swift(>=3.1)
    
    import Foundation
    
    // MARK: Basic accessors
    
    public extension JSON {
        /// Returns the numeric value as a `Decimal` if the receiver is `.int64`, `.double`, or `.decimal`, otherwise `nil`.
        ///
        /// When setting, replaces the receiver with the given decimal value, or with
        /// null if the value is `nil`.
        var decimal: Decimal? {
            get {
                switch self {
                case .int64(let i): return Decimal(workaround: i)
                case .double(let d): return Decimal(workaround: d)
                case .decimal(let d): return d
                default: return nil
                }
            }
            set {
                self = newValue.map(JSON.decimal) ?? nil
            }
        }
        
        /// Returns the receiver as a `Decimal` if possible.
        /// - Returns: A `Decimal` if the receiver is `.int64`, `.double`, or `.decimal`, or is a `.string`
        ///   that contains a valid decimal number representation, otherwise `nil`.
        /// - Note: Whitespace is not allowed in the string representation.
        var asDecimal: Decimal? {
            switch self {
            case .int64(let i): return Decimal(workaround: i)
            case .double(let d): return Decimal(workaround: d)
            case .decimal(let d): return d
            case .string(let s) where !s.isEmpty:
                // Decimal(string:locale:) uses Scanner, but it will skip whitespace and allow trailing characters,
                // neither of which are appropriate (SR-3128)
                let scanner = Scanner(string: s)
                scanner.charactersToBeSkipped = nil
                var decimal = Decimal()
                if !scanner.scanDecimal(&decimal) {
                    return nil
                }
                #if os(iOS) || os(OSX) || os(tvOS) || os(watchOS)
                    if !scanner.isAtEnd { return nil }
                #else
                    // Linux in Swift 3.1 doesn't have isAtEnd
                    // Instead we'll just rely on knowing that scanLocation is in NSString indices (i.e. UTF-16 indices)
                    if scanner.scanLocation != s.utf16.count { return nil }
                #endif
                return decimal
            default: return nil
            }
        }
        
        /// Returns the receiver as a `Decimal` if it is `.int64`, `.double`, or `.decimal`.
        /// - Returns: A `Decimal`.
        /// - Throws: `JSONError` if the receiver is not `.int64`, `.double`, or `.decimal`.
        func getDecimal() throws -> Decimal {
            switch self {
            case .int64(let i): return Decimal(workaround: i)
            case .double(let d): return Decimal(workaround: d)
            case .decimal(let d): return d
            default: throw hideThrow(JSONError.missingOrInvalidType(path: nil, expected: .required(.number), actual: .forValue(self)))
            }
        }
        
        /// Returns the receiver as a `Decimal` if it is `.int64`, `.double`, or `.decimal`.
        /// - Returns: A `Decimal`, or `nil` if the receiver is `null`.
        /// - Throws: `JSONError` if the receiver is not `.int64`, `.double`, or `.decimal`.
        func getDecimalOrNil() throws -> Decimal? {
            switch self {
            case .int64(let i): return Decimal(workaround: i)
            case .double(let d): return Decimal(workaround: d)
            case .decimal(let d): return d
            case .null: return nil
            default: throw hideThrow(JSONError.missingOrInvalidType(path: nil, expected: .required(.number), actual: .forValue(self)))
            }
        }
        
        /// Returns the receiver as a `Decimal` if possible.
        /// - Returns: A `Decimal` if the receiver is `.int64`, `.double`, or `.decimal`, or is a `.string`
        ///   that contains a valid decimal number representation.
        /// - Throws: `JSONError` if the receiver is the wrong type, or is a `.string` that does not contain
        ///   a valid decimal number representation.
        /// - Note: Whitespace is not allowed in the string representation.
        func toDecimal() throws -> Decimal {
            guard let value = asDecimal else {
                throw hideThrow(JSONError.missingOrInvalidType(path: nil, expected: .required(.number), actual: .forValue(self)))
            }
            return value
        }
        
        /// Returns the receiver as a `Decimal` if possible.
        /// - Returns: A `Decimal` if the receiver is `.int64`, `.double`, or `.decimal`, or is a `.string`
        ///   that contains a valid decimal number representation, or `nil` if the receiver is `null`.
        /// - Throws: `JSONError` if the receiver is the wrong type, or is a `.string` that does not contain
        ///   a valid decimal number representation.
        /// - Note: Whitespace is not allowed in the string representation.
        func toDecimalOrNil() throws -> Decimal? {
            if let value = asDecimal { return value }
            else if isNull { return nil }
            else { throw hideThrow(JSONError.missingOrInvalidType(path: nil, expected: .optional(.number), actual: .forValue(self))) }
        }
        
        // MARK: - Deprecated
        
        /// Returns the receiver as an `NSDecimalNumber` if possible. (Deprecated)
        /// - Note: Deprecated in favor of `asDecimal`.
        /// - Returns: An `NSDecimalNumber` if the receiver is `.int64`, `.double`, or `.decimal`, or is a `.string`
        ///   that contains a valid decimal number representation, otherwise `nil`.
        /// - Note: Whitespace is not allowed in the string representation.
        @available(*, deprecated, message: "use asDecimal instead")
        var asDecimalNumber: NSDecimalNumber? {
            return asDecimal.map(NSDecimalNumber.init(decimal:))
        }
        
        /// Returns the receiver as an `NSDecimalNumber` if it is `.int64`, `.double`, or `.decimal`. (Deprecated)
        /// - Note: Deprecated in favor of `getDecimal()`.
        /// - Returns: An `NSDecimalNumber`.
        /// - Throws: `JSONError` if the receiver is not `.int64`, `.double`, or `.decimal`.
        @available(*, deprecated, message: "use getDecimal() instead")
        func getDecimalNumber() throws -> NSDecimalNumber {
            return try NSDecimalNumber(decimal: getDecimal())
        }
        
        /// Returns the receiver as an `NSDecimalNumber` if it is `.int64`, `.double`, or `.decimal`. (Deprecated)
        /// - Note: Deprecated in favor of `getDecimalOrNil()`.
        /// - Returns: An `NSDecimalNumber`, or `nil` if the receiver is `null`.
        /// - Throws: `JSONError` if the receiver is not `.int64`, `.double`, or `.decimal`.
        @available(*, deprecated, message: "use getDecimalOrNil() instead")
        func getDecimalNumberOrNil() throws -> NSDecimalNumber? {
            return try getDecimalOrNil().map(NSDecimalNumber.init(decimal:))
        }
        
        /// Returns the receiver as an `NSDecimalNumber` if possible. (Deprecated)
        /// - Note: Deprecated in favor of `toDecimal()`.
        /// - Returns: An `NSDecimalNumber` if the receiver is `.int64`, `.double`, or `.decimal`, or is a `.string`
        ///   that contains a valid decimal number representation.
        /// - Throws: `JSONError` if the receiver is the wrong type, or is a `.string` that does not contain
        ///   a valid decimal number representation.
        /// - Note: Whitespace is not allowed in the string representation.
        @available(*, deprecated, message: "use toDecimal() instead")
        func toDecimalNumber() throws -> NSDecimalNumber {
            return try NSDecimalNumber(decimal: toDecimal())
        }
        
        /// Returns the receiver as an `NSDecimalNumber` if possible. (Deprecated)
        /// - Note: Deprecated in favor of `toDecimalOrNil()`.
        /// - Returns: An `NSDecimalNumber` if the receiver is `.int64`, `.double`, or `.decimal`, or is a `.string`
        ///   that contains a valid decimal number representation, or `nil` if the receiver is `null`.
        /// - Throws: `JSONError` if the receiver is the wrong type, or is a `.string` that does not contain
        ///   a valid decimal number representation.
        /// - Note: Whitespace is not allowed in the string representation.
        @available(*, deprecated, message: "use toDecimalOrNil() instead")
        func toDecimalNumberOrNil() throws -> NSDecimalNumber? {
            return try toDecimalOrNil().map(NSDecimalNumber.init(decimal:))
        }
    }
    
    // MARK: - Keyed accessors
    
    public extension JSON {
        /// Subscripts the receiver with `key` and returns the result as a `Decimal`.
        /// - Parameter key: The key that's used to subscript the receiver.
        /// - Returns: A `Decimal`.
        /// - Throws: `JSONError` if the key doesn't exist or the value is the wrong type, or if
        ///   the receiver is not an object.
        func getDecimal(_ key: String) throws -> Decimal {
            let dict = try getObject()
            let value = try getRequired(dict, key: key, type: .number)
            return try scoped(key) { try value.getDecimal() }
        }
        
        /// Subscripts the receiver with `key` and returns the result as a `Decimal`.
        /// - Parameter key: The key that's used to subscript the receiver.
        /// - Returns: A `Decimal`, or `nil` if the key doesn't exist or the value is `null`.
        /// - Throws: `JSONError` if the value is the wrong type, or if the receiver is
        ///   not an object.
        func getDecimalOrNil(_ key: String) throws -> Decimal? {
            let dict = try getObject()
            guard let value = dict[key] else { return nil }
            return try scoped(key) { try value.getDecimalOrNil() }
        }
        
        /// Subscripts the receiver with `key` and returns the result as a `Decimal`.
        /// - Parameter key: The key that's used to subscript the receiver.
        /// - Returns: A `Decimal`.
        /// - Throws: `JSONError` if the key doesn't exist or the value is `null`, a boolean, an object,
        ///   an array, or a string that cannot be coerced to a decimal number, or if the
        ///   receiver is not an object.
        func toDecimal(_ key: String) throws -> Decimal {
            let dict = try getObject()
            let value = try getRequired(dict, key: key, type: .number)
            return try scoped(key) { try value.toDecimal() }
        }
        
        /// Subscripts the receiver with `key` and returns the result as a `Decimal`.
        /// - Parameter key: The key that's used to subscript the receiver.
        /// - Returns: A `Decimal`, or `nil` if the key doesn't exist or the value is `null`.
        /// - Throws: `JSONError` if the value is a boolean, an object, an array, or a string that
        ///   cannot be coerced to a decimal number, or if the receiver is not an object.
        func toDecimalOrNil(_ key: String) throws -> Decimal? {
            let dict = try getObject()
            guard let value = dict[key] else { return nil }
            return try scoped(key) { try value.toDecimalOrNil() }
        }
        
        // MARK: - Deprecated
        
        /// Subscripts the receiver with `key` and returns the result as an `NSDecimalNumber`. (Deprecated)
        /// - Note: Deprecated in favor of `getDecimal()`.
        /// - Parameter key: The key that's used to subscript the receiver.
        /// - Returns: An `NSDecimalNumber`.
        /// - Throws: `JSONError` if the key doesn't exist or the value is the wrong type, or if
        ///   the receiver is not an object.
        @available(*, deprecated, message: "use getDecimal() instead")
        func getDecimalNumber(_ key: String) throws -> NSDecimalNumber {
            return try NSDecimalNumber(decimal: getDecimal(key))
        }
        
        /// Subscripts the receiver with `key` and returns the result as an `NSDecimalNumber`. (Deprecated)
        /// - Note: Deprecated in favor of `getDecimalOrNil()`.
        /// - Parameter key: The key that's used to subscript the receiver.
        /// - Returns: An `NSDecimalNumber`, or `nil` if the key doesn't exist or the value is `null`.
        /// - Throws: `JSONError` if the value is the wrong type, or if the receiver is
        ///   not an object.
        @available(*, deprecated, message: "use getDecimalOrNil() instead")
        func getDecimalNumberOrNil(_ key: String) throws -> NSDecimalNumber? {
            return try getDecimalOrNil(key).map(NSDecimalNumber.init(decimal:))
        }
        
        /// Subscripts the receiver with `key` and returns the result as an `NSDecimalNumber`. (Deprecated)
        /// - Note: Deprecated in favor of `toDecimal()`.
        /// - Parameter key: The key that's used to subscript the receiver.
        /// - Returns: An `NSDecimalNumber`.
        /// - Throws: `JSONError` if the key doesn't exist or the value is `null`, a boolean, an object,
        ///   an array, or a string that cannot be coerced to a decimal number, or if the
        ///   receiver is not an object.
        @available(*, deprecated, message: "use toDecimal() instead")
        func toDecimalNumber(_ key: String) throws -> NSDecimalNumber {
            return try NSDecimalNumber(decimal: toDecimal(key))
        }
        
        /// Subscripts the receiver with `key` and returns the result as an `NSDecimalNumber`. (Deprecated)
        /// - Note: Deprecated in favor of `toDecimalOrNil()`.
        /// - Parameter key: The key that's used to subscript the receiver.
        /// - Returns: An `NSDecimalNumber`, or `nil` if the key doesn't exist or the value is `null`.
        /// - Throws: `JSONError` if the value is a boolean, an object, an array, or a string that
        ///   cannot be coerced to a decimal number, or if the receiver is not an object.
        @available(*, deprecated, message: "use toDecimalOrNil() instead")
        func toDecimalNumberOrNil(_ key: String) throws -> NSDecimalNumber? {
            return try toDecimalOrNil(key).map(NSDecimalNumber.init(decimal:))
        }
    }
    
    // MARK: - Indexed accessors
    
    public extension JSON {
        /// Subscripts the receiver with `index` and returns the result as a `Decimal`.
        /// - Parameter index: The index that's used to subscript the receiver.
        /// - Returns: A `Decimal`.
        /// - Throws: `JSONError` if the index is out of bounds or the value is the wrong type, or if
        ///   the receiver is not an array.
        func getDecimal(_ index: Int) throws -> Decimal {
            let array = try getArray()
            let value = try getRequired(array, index: index, type: .number)
            return try scoped(index) { try value.getDecimal() }
        }
        
        /// Subscripts the receiver with `index` and returns the result as a `Decimal`.
        /// - Parameter index: The index that's used to subscript the receiver.
        /// - Returns: A `Decimal`, or `nil` if the index is out of bounds or the value is `null`.
        /// - Throws: `JSONError` if the value is the wrong type, or if the receiver is not an array.
        func getDecimalOrNil(_ index: Int) throws -> Decimal? {
            let array = try getArray()
            guard let value = array[safe: index] else { return nil }
            return try scoped(index) { try value.getDecimalOrNil() }
        }
        
        /// Subscripts the receiver with `index` and returns the result as a `Decimal`.
        /// - Parameter index: The index that's used to subscript the receiver.
        /// - Returns: A `Decimal`.
        /// - Throws: `JSONError` if the index is out of bounds or the value is `null`, a boolean,
        ///   an object, an array, or a string that cannot be coerced to a decimal number, or
        ///   if the receiver is not an array.
        func toDecimal(_ index: Int) throws -> Decimal {
            let array = try getArray()
            let value = try getRequired(array, index: index, type: .number)
            return try scoped(index) { try value.toDecimal() }
        }
        
        /// Subscripts the receiver with `index` and returns the result as a `Decimal`.
        /// - Parameter index: The index that's used to subscript the receiver.
        /// - Returns: A `Decimal`, or `nil` if the index is out of bounds or the value is `null`.
        /// - Throws: `JSONError` if the value is a boolean, an object, an array, or a string that
        ///   cannot be coerced to a decimal number, or if the receiver is not an array.
        func toDecimalOrNil(_ index: Int) throws -> Decimal? {
            let array = try getArray()
            guard let value = array[safe: index] else { return nil }
            return try scoped(index) { try value.toDecimalOrNil() }
        }
        
        // MARK: - Deprecated
        
        /// Subscripts the receiver with `index` and returns the result as an `NSDecimalNumber`. (Deprecated)
        /// - Note: Deprecated in favor of `getDecimal()`.
        /// - Parameter index: The index that's used to subscript the receiver.
        /// - Returns: An `NSDecimalNumber`.
        /// - Throws: `JSONError` if the index is out of bounds or the value is the wrong type, or if
        ///   the receiver is not an array.
        @available(*, deprecated, message: "use getDecimal() instead")
        func getDecimalNumber(_ index: Int) throws -> NSDecimalNumber {
            return try NSDecimalNumber(decimal: getDecimal(index))
        }
        
        /// Subscripts the receiver with `index` and returns the result as an `NSDecimalNumber`. (Deprecated)
        /// - Note: Deprecated in favor of `getDecimalOrNil()`.
        /// - Parameter index: The index that's used to subscript the receiver.
        /// - Returns: An `NSDecimalNumber`, or `nil` if the index is out of bounds or the value is `null`.
        /// - Throws: `JSONError` if the value is the wrong type, or if the receiver is not an array.
        @available(*, deprecated, message: "use getDecimalOrNil() instead")
        func getDecimalNumberOrNil(_ index: Int) throws -> NSDecimalNumber? {
            return try getDecimalOrNil(index).map(NSDecimalNumber.init(decimal:))
        }
        
        /// Subscripts the receiver with `index` and returns the result as an `NSDecimalNumber`. (Deprecated)
        /// - Note: Deprecated in favor of `toDecimal()`.
        /// - Parameter index: The index that's used to subscript the receiver.
        /// - Returns: An `NSDecimalNumber`.
        /// - Throws: `JSONError` if the index is out of bounds or the value is `null`, a boolean,
        ///   an object, an array, or a string that cannot be coerced to a decimal number, or
        ///   if the receiver is not an array.
        @available(*, deprecated, message: "use toDecimal() instead")
        func toDecimalNumber(_ index: Int) throws -> NSDecimalNumber {
            return try NSDecimalNumber(decimal: toDecimal(index))
        }
        
        /// Subscripts the receiver with `index` and returns the result as an `NSDecimalNumber`. (Deprecated)
        /// - Note: Deprecated in favor of `toDecimalOrNil()`.
        /// - Parameter index: The index that's used to subscript the receiver.
        /// - Returns: An `NSDecimalNumber`, or `nil` if the index is out of bounds or the value is `null`.
        /// - Throws: `JSONError` if the value is a boolean, an object, an array, or a string that
        ///   cannot be coerced to a decimal number, or if the receiver is not an array.
        @available(*, deprecated, message: "use toDecimalOrNil() instead")
        func toDecimalNumberOrNil(_ index: Int) throws -> NSDecimalNumber? {
            return try toDecimalOrNil(index).map(NSDecimalNumber.init(decimal:))
        }
    }
    
    // MARK: -
    
    public extension JSONObject {
        /// Subscripts the receiver with `key` and returns the result as a `Decimal`.
        /// - Parameter key: The key that's used to subscript the receiver.
        /// - Returns: A `Decimal`.
        /// - Throws: `JSONError` if the key doesn't exist or the value is the wrong type, or if
        ///   the receiver is not an object.
        func getDecimal(_ key: String) throws -> Decimal {
            let value = try getRequired(self, key: key, type: .number)
            return try scoped(key) { try value.getDecimal() }
        }
        
        /// Subscripts the receiver with `key` and returns the result as a `Decimal`.
        /// - Parameter key: The key that's used to subscript the receiver.
        /// - Returns: A `Decimal`, or `nil` if the key doesn't exist or the value is `null`.
        /// - Throws: `JSONError` if the value is the wrong type, or if the receiver is
        ///   not an object.
        func getDecimalOrNil(_ key: String) throws -> Decimal? {
            guard let value = self[key] else { return nil }
            return try scoped(key) { try value.getDecimalOrNil() }
        }
        
        /// Subscripts the receiver with `key` and returns the result as a `Decimal`.
        /// - Parameter key: The key that's used to subscript the receiver.
        /// - Returns: A `Decimal`.
        /// - Throws: `JSONError` if the key doesn't exist or the value is `null`, a boolean, an object,
        ///   an array, or a string that cannot be coerced to a decimal number, or if the
        ///   receiver is not an object.
        func toDecimal(_ key: String) throws -> Decimal {
            let value = try getRequired(self, key: key, type: .number)
            return try scoped(key) { try value.toDecimal() }
        }
        
        /// Subscripts the receiver with `key` and returns the result as a `Decimal`.
        /// - Parameter key: The key that's used to subscript the receiver.
        /// - Returns: A `Decimal`, or `nil` if the key doesn't exist or the value is `null`.
        /// - Throws: `JSONError` if the value is a boolean, an object, an array, or a string that
        ///   cannot be coerced to a decimal number, or if the receiver is not an object.
        func toDecimalOrNil(_ key: String) throws -> Decimal? {
            guard let value = self[key] else { return nil }
            return try scoped(key) { try value.toDecimalOrNil() }
        }
        
        // MARK: - Deprecated
        
        /// Subscripts the receiver with `key` and returns the result as an `NSDecimalNumber`. (Deprecated)
        /// - Note: Deprecated in favor of `getDecimal()`.
        /// - Parameter key: The key that's used to subscript the receiver.
        /// - Returns: An `NSDecimalNumber`.
        /// - Throws: `JSONError` if the key doesn't exist or the value is the wrong type, or if
        ///   the receiver is not an object.
        @available(*, deprecated, message: "use getDecimal() instead")
        func getDecimalNumber(_ key: String) throws -> NSDecimalNumber {
            return try NSDecimalNumber(decimal: getDecimal(key))
        }
        
        /// Subscripts the receiver with `key` and returns the result as an `NSDecimalNumber`. (Deprecated)
        /// - Note: Deprecated in favor of `getDecimalOrNil()`.
        /// - Parameter key: The key that's used to subscript the receiver.
        /// - Returns: An `NSDecimalNumber`, or `nil` if the key doesn't exist or the value is `null`.
        /// - Throws: `JSONError` if the value is the wrong type, or if the receiver is
        ///   not an object.
        @available(*, deprecated, message: "use getDecimalOrNil() instead")
        func getDecimalNumberOrNil(_ key: String) throws -> NSDecimalNumber? {
            return try getDecimalOrNil(key).map(NSDecimalNumber.init(decimal:))
        }
        
        /// Subscripts the receiver with `key` and returns the result as an `NSDecimalNumber`. (Deprecated)
        /// - Note: Deprecated in favor of `toDecimal()`.
        /// - Parameter key: The key that's used to subscript the receiver.
        /// - Returns: An `NSDecimalNumber`.
        /// - Throws: `JSONError` if the key doesn't exist or the value is `null`, a boolean, an object,
        ///   an array, or a string that cannot be coerced to a decimal number, or if the
        ///   receiver is not an object.
        @available(*, deprecated, message: "use toDecimal() instead")
        func toDecimalNumber(_ key: String) throws -> NSDecimalNumber {
            return try NSDecimalNumber(decimal: toDecimal(key))
        }
        
        /// Subscripts the receiver with `key` and returns the result as an `NSDecimalNumber`. (Deprecated)
        /// - Note: Deprecated in favor of `toDecimalOrNil()`.
        /// - Parameter key: The key that's used to subscript the receiver.
        /// - Returns: An `NSDecimalNumber`, or `nil` if the key doesn't exist or the value is `null`.
        /// - Throws: `JSONError` if the value is a boolean, an object, an array, or a string that
        ///   cannot be coerced to a decimal number, or if the receiver is not an object.
        @available(*, deprecated, message: "use toDecimalOrNil() instead")
        func toDecimalNumberOrNil(_ key: String) throws -> NSDecimalNumber? {
            return try toDecimalOrNil(key).map(NSDecimalNumber.init(decimal:))
        }
    }
    
    // MARK: - Internal Helpers
    
    internal extension Int64 {
        static let maxDecimal: Decimal = Decimal(workaround: Int64.max)
        static let minDecimal: Decimal = Decimal(workaround: Int64.min)
    }
    
    internal extension Decimal {
        // NB: As of Swift 3.0.1, Decimal(_: Int64) incorrectly passes through Double first (SR-3125)
        // and Decimal(_: Double) can produce incorrect results (SR-3130), so for now we're going to
        // always go through NSNumber.
        init(workaround value: Int64) {
            self = NSNumber(value: value).decimalValue
        }
        
        // NB: As of Swift 3.0.1, Decimal(_: Double) can produce incorrect results (SR-3130)
        init(workaround value: Double) {
            self = NSNumber(value: value).decimalValue
        }
    }
    
#endif // os(iOS) || os(OSX) || os(tvOS) || os(watchOS) || swift(>=3.1)

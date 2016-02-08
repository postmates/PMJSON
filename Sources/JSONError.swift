//
//  JSONError.swift
//  PMJSON
//
//  Created by Kevin Ballard on 11/9/15.
//

// MARK: JSONError

public enum JSONError: ErrorType, CustomStringConvertible {
    case MissingOrInvalidType(path: String?, expected: ExpectedType, actual: JSONType?)
    
    public var description: String {
        switch self {
        case let .MissingOrInvalidType(path, expected, actual): return "\(path.map({$0+": "}) ?? "")expected \(expected), found \(actual?.description ?? "missing value")"
        }
    }
    
    private func withPrefix(prefix: String) -> JSONError {
        switch self {
        case let .MissingOrInvalidType(path?, expected, actual):
            if path.hasPrefix("[") {
                return .MissingOrInvalidType(path: prefix + path, expected: expected, actual: actual)
            } else {
                return .MissingOrInvalidType(path: "\(prefix).\(path)", expected: expected, actual: actual)
            }
        case let .MissingOrInvalidType(nil, expected, actual):
            return .MissingOrInvalidType(path: prefix, expected: expected, actual: actual)
        }
    }
    
    public enum ExpectedType: CustomStringConvertible {
        case Required(JSONType)
        case Optional(JSONType)
        
        public var description: String {
            switch self {
            case .Required(let type): return type.description
            case .Optional(let type): return "\(type) or null"
            }
        }
    }
    
    public enum JSONType: String, CustomStringConvertible {
        case Null = "null"
        case Bool = "bool"
        case String = "string"
        case Number = "number"
        case Object = "object"
        case Array = "array"
        
        private static func forValue(value: JSON) -> JSONType {
            switch value {
            case .Null: return .Null
            case .Bool: return .Bool
            case .String: return .String
            case .Int64, .Double: return .Number
            case .Object: return .Object
            case .Array: return .Array
            }
        }
        
        public var description: Swift.String {
            return rawValue
        }
    }
}

// MARK: - Basic accessors
public extension JSON {
    /// Returns the bool value if the receiver is a bool.
    /// Otherwise, an error is thrown.
    /// - Throws: `JSONError`
    func getBool() throws -> Swift.Bool {
        guard let b = bool else { throw JSONError.MissingOrInvalidType(path: nil, expected: .Required(.Bool), actual: .forValue(self)) }
        return b
    }
    
    /// Returns the bool value if the receiver is a bool.
    /// Returns `nil` if the receiver is `null`.
    /// Otherwise, an error is thrown.
    /// - Throws: `JSONError`
    func getBoolOrNil() throws -> Swift.Bool? {
        if let b = bool { return b }
        else if isNull { return nil }
        else { throw JSONError.MissingOrInvalidType(path: nil, expected: .Optional(.Bool), actual: .forValue(self)) }
    }
    
    /// Returns the string value if the receiver is a string.
    /// Otherwise, an error is thrown.
    /// - Throws: `JSONError`
    func getString() throws -> Swift.String {
        guard let str = string else { throw JSONError.MissingOrInvalidType(path: nil, expected: .Required(.String), actual: .forValue(self)) }
        return str
    }
    
    /// Returns the string value if the receiver is a string.
    /// Returns `nil` if the receiver is `null`.
    /// Otherwise, an error is thrown.
    /// - Throws: `JSONError`
    func getStringOrNil() throws -> Swift.String? {
        if let str = string { return str }
        else if isNull { return nil }
        else { throw JSONError.MissingOrInvalidType(path: nil, expected: .Optional(.String), actual: .forValue(self)) }
    }
    
    /// Returns the 64-bit integral value if the receiver is a number.
    /// Otherwise, an error is thrown.
    /// - Throws: `JSONError`
    func getInt64() throws -> Swift.Int64 {
        guard let val = int64 else { throw JSONError.MissingOrInvalidType(path: nil, expected: .Required(.Number), actual: .forValue(self)) }
        return val
    }
    
    /// Returns the 64-bit integral value value if the receiver is a number.
    /// Returns `nil` if the receiver is `null`.
    /// Otherwise, an error is thrown.
    /// - Throws: `JSONError`
    func getInt64OrNil() throws -> Swift.Int64? {
        if let val = int64 { return val }
        else if isNull { return nil }
        else { throw JSONError.MissingOrInvalidType(path: nil, expected: .Optional(.Number), actual: .forValue(self)) }
    }
    
    /// Returns the double value if the receiver is a number.
    /// Otherwise, an error is thrown.
    /// - Throws: `JSONError`
    func getDouble() throws -> Swift.Double {
        guard let val = double else { throw JSONError.MissingOrInvalidType(path: nil, expected: .Required(.Number), actual: .forValue(self)) }
        return val
    }
    
    /// Returns the double value if the receiver is a number.
    /// Returns `nil` if the receiver is `null`.
    /// Otherwise, an error is thrown.
    /// - Throws: `JSONError`
    func getDoubleOrNil() throws -> Swift.Double? {
        if let val = double { return val }
        else if isNull { return nil }
        else { throw JSONError.MissingOrInvalidType(path: nil, expected: .Optional(.Number), actual: .forValue(self)) }
    }
    
    /// Returns the object value if the receiver is an object.
    /// Otherwise, an error is thrown.
    /// - Throws: `JSONError`
    func getObject() throws -> JSONObject {
        guard let dict = object else { throw JSONError.MissingOrInvalidType(path: nil, expected: .Required(.Object), actual: .forValue(self)) }
        return dict
    }
    
    /// Returns the object value if the receiver is an object.
    /// Returns `nil` if the receiver is `null`.
    /// Otherwise, an error is thrown.
    /// - Throws: `JSONError`
    func getObjectOrNil() throws -> JSONObject? {
        if let dict = object { return dict }
        else if isNull { return nil }
        else { throw JSONError.MissingOrInvalidType(path: nil, expected: .Optional(.Object), actual: .forValue(self)) }
    }
    
    /// Returns the array value if the receiver is an array.
    /// Otherwise, an error is thrown.
    /// - Throws: `JSONError`
    func getArray() throws -> JSONArray {
        guard let ary = array else { throw JSONError.MissingOrInvalidType(path: nil, expected: .Required(.Array), actual: .forValue(self)) }
        return ary
    }
    
    /// Returns the array value if the receiver is an array.
    /// Returns `nil` if the receiver is `null`.
    /// Otherwise, an error is thrown.
    /// - Throws: `JSONError`
    func getArrayOrNil() throws -> JSONArray? {
        if let ary = array { return ary }
        else if isNull { return nil }
        else { throw JSONError.MissingOrInvalidType(path: nil, expected: .Optional(.Array), actual: .forValue(self)) }
    }
}

// MARK: - Keyed accessors
public extension JSON {
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getBool(key: Swift.String) throws -> Swift.Bool {
        let dict = try getObject()
        let value = try getRequired(dict, key: key, type: .String)
        return try scoped(key) { try value.getBool() }
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getBoolOrNil(key: Swift.String) throws -> Swift.Bool? {
        let dict = try getObject()
        guard let value = dict[key] else { return nil }
        return try scoped(key) { try value.getBoolOrNil() }
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getString(key: Swift.String) throws -> Swift.String {
        let dict = try getObject()
        let value = try getRequired(dict, key: key, type: .String)
        return try scoped(key) { try value.getString() }
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getStringOrNil(key: Swift.String) throws -> Swift.String? {
        let dict = try getObject()
        guard let value = dict[key] else { return nil }
        return try scoped(key) { try value.getStringOrNil() }
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getInt64(key: Swift.String) throws -> Swift.Int64 {
        let dict = try getObject()
        let value = try getRequired(dict, key: key, type: .Number)
        return try scoped(key) { try value.getInt64() }
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getInt64OrNil(key: Swift.String) throws -> Swift.Int64? {
        let dict = try getObject()
        guard let value = dict[key] else { return nil }
        return try scoped(key) { try value.getInt64OrNil() }
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getDouble(key: Swift.String) throws -> Swift.Double {
        let dict = try getObject()
        let value = try getRequired(dict, key: key, type: .Number)
        return try scoped(key) { try value.getDouble() }
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getDoubleOrNil(key: Swift.String) throws -> Swift.Double? {
        let dict = try getObject()
        guard let value = dict[key] else { return nil }
        return try scoped(key) { try value.getDoubleOrNil() }
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value has the wrong type, an error is thrown.
    /// - Note: Use `getObject(_:_:)` when using throwing accessors on the resulting
    ///   object value to produce better errors.
    /// - Throws: `JSONError`
    /// - SeeAlso: `getObject(_:_:)`
    func getObject(key: Swift.String) throws -> JSONObject {
        return try getObject(key, { $0 })
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Note: Use `getObjectOrNil(_:_:)` when using throwing accessors on the resulting
    ///   object value to produce better errors.
    /// - Throws: `JSONError`
    /// - SeeAlso: `getObjectOrNil(_:_:)`
    func getObjectOrNil(key: Swift.String) throws -> JSONObject? {
        return try getObjectOrNil(key, { $0 })
    }
    
    /// Subscripts the receiver with `key` and passes the result to the given block.
    /// If the key doesn't exist or the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getObject<T>(key: Swift.String, @noescape _ f: JSONObject throws -> T) throws -> T {
        return try getObject().getObject(key, f)
    }
    
    /// Subscripts the receiver with `key` and passes the result to the given block.
    /// If the key doesn't exist or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getObjectOrNil<T>(key: Swift.String, @noescape _ f: JSONObject throws -> T?) throws -> T? {
        return try getObject().getObjectOrNil(key, f)
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value has the wrong type, an error is thrown.
    /// - Note: Use `getArray(_:_:)` when using throwing accessors on the resulting
    ///   array value to produce better errors.
    /// - Throws: `JSONError`
    /// - SeeAlso: `getArray(_:_:)`
    func getArray(key: Swift.String) throws -> JSONArray {
        return try getArray(key, { $0 })
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Note: Use `getArrayOrNil(_:_:)` when using throwing accessors on the resulting
    ///   array value to produce better errors.
    /// - Throws: `JSONError`
    /// - SeeAlso: `getArrayOrNil(_:_:)`
    func getArrayOrNil(key: Swift.String) throws -> JSONArray? {
        return try getArrayOrNil(key, { $0 })
    }
    
    /// Subscripts the receiver with `key` and passes the result to the given block.
    /// If the key doesn't exist or the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getArray<T>(key: Swift.String, @noescape _ f: JSONArray throws -> T) throws -> T {
        let dict = try getObject()
        let value = try getRequired(dict, key: key, type: .Array)
        return try scoped(key) { try f(value.getArray()) }
    }
    
    /// Subscripts the receiver with `key` and passes the result to the given block.
    /// If the key doesn't exist or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getArrayOrNil<T>(key: Swift.String, @noescape _ f: JSONArray throws -> T?) throws -> T? {
        let dict = try getObject()
        guard let value = dict[key] else { return nil }
        return try scoped(key) { try value.getArrayOrNil().flatMap(f) }
    }
}

// MARK: - Indexed accessors
public extension JSON {
    /// Subscripts the receiver with `index` and returns the result.
    /// If the index is out of range or the value is the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getBool(index: Int) throws -> Swift.Bool {
        let ary = try getArray()
        let value = try getRequired(ary, index: index, type: .Bool)
        return try scoped(index) { try value.getBool() }
    }
    
    /// Subscripts the receiver with `index` and returns the result.
    /// If the index is out of range or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getBoolOrNil(index: Int) throws -> Swift.Bool? {
        let ary = try getArray()
        guard let value = ary[safe: index] else { return nil }
        return try scoped(index) { try value.getBoolOrNil() }
    }
    
    /// Subscripts the receiver with `index` and returns the result.
    /// If the index is out of range or the value is the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getString(index: Int) throws -> Swift.String {
        let ary = try getArray()
        let value = try getRequired(ary, index: index, type: .String)
        return try scoped(index) { try value.getString() }
    }
    
    /// Subscripts the receiver with `index` and returns the result.
    /// If the index is out of range or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getStringOrNil(index: Int) throws -> Swift.String? {
        let ary = try getArray()
        guard let value = ary[safe: index] else { return nil }
        return try scoped(index) { try value.getStringOrNil() }
    }
    
    /// Subscripts the receiver with `index` and returns the result.
    /// If the index is out of range or the value is the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getInt64(index: Int) throws -> Swift.Int64 {
        let ary = try getArray()
        let value = try getRequired(ary, index: index, type: .Number)
        return try scoped(index) { try value.getInt64() }
    }
    
    /// Subscripts the receiver with `index` and returns the result.
    /// If the index is out of range or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getInt64OrNil(index: Int) throws -> Swift.Int64? {
        let ary = try getArray()
        guard let value = ary[safe: index] else { return nil }
        return try scoped(index) { try value.getInt64OrNil() }
    }
    
    /// Subscripts the receiver with `index` and returns the result.
    /// If the index is out of range or the value is the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getDouble(index: Int) throws -> Swift.Double {
        let ary = try getArray()
        let value = try getRequired(ary, index: index, type: .Number)
        return try scoped(index) { try value.getDouble() }
    }
    
    /// Subscripts the receiver with `index` and returns the result.
    /// If the index is out of range or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getDoubleOrNil(index: Int) throws -> Swift.Double? {
        let ary = try getArray()
        guard let value = ary[safe: index] else { return nil }
        return try scoped(index) { try value.getDoubleOrNil() }
    }
    
    /// Subscripts the receiver with `index` and returns the result.
    /// If the index is out of range or the value is the wrong type, an error is thrown.
    /// - Note: Use `getObject(_:_:)` when using throwing accessors on the resulting
    ///   object value to produce better errors.
    /// - Throws: `JSONError`
    /// - SeeAlso: `getObject(_:_:)`
    func getObject(index: Int) throws -> JSONObject {
        return try getObject(index, { $0 })
    }
    
    /// Subscripts the receiver with `index` and returns the result.
    /// If the index is out of range or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Note: Use `getObjectOrNil(_:_:)` when using throwing accessors on the resulting
    ///   object value to produce better errors.
    /// - Throws: `JSONError`
    /// - SeeAlso: `getObjectOrNil(_:_:)`
    func getObjectOrNil(index: Int) throws -> JSONObject? {
        return try getObjectOrNil(index, { $0 })
    }
    
    /// Subscripts the receiver with `index` and passes the result to the given block.
    /// If the index is out of range or the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getObject<T>(index: Int, @noescape _ f: JSONObject throws -> T) throws -> T {
        let ary = try getArray()
        let value = try getRequired(ary, index: index, type: .Object)
        return try scoped(index) { try f(value.getObject()) }
    }
    
    /// Subscripts the receiver with `index` and passes the result to the given block.
    /// If the index is out of range or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getObjectOrNil<T>(index: Int, @noescape _ f: JSONObject throws -> T?) throws -> T? {
        let ary = try getArray()
        guard let value = ary[safe: index] else { return nil }
        return try scoped(index) { try value.getObjectOrNil().flatMap(f) }
    }
    
    /// Subscripts the receiver with `index` and returns the result.
    /// If the index is out of range or the value is the wrong type, an error is thrown.
    /// - Note: Use `getArray(_:_:)` when using throwing accessors on the resulting
    ///   array value to produce better errors.
    /// - Throws: `JSONError`
    /// - SeeAlso: `getArray(_:_:)`
    func getArray(index: Int) throws -> JSONArray {
        return try getArray(index, { $0 })
    }
    
    /// Subscripts the receiver with `index` and returns the result.
    /// If the index is out of range or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Note: Use `getArrayOrNil(_:_:)` when using throwing accessors on the resulting
    ///   array value to produce better errors.
    /// - Throws: `JSONError`
    /// - SeeAlso: `getArrayOrNil(_:_:)`
    func getArrayOrNil(index: Int) throws -> JSONArray? {
        return try getArrayOrNil(index, { $0 })
    }
    
    /// Subscripts the receiver with `index` and passes the result to the given block.
    /// If the index is out of range or the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getArray<T>(index: Int, @noescape _ f: JSONArray throws -> T) throws -> T {
        let ary = try getArray()
        let value = try getRequired(ary, index: index, type: .Array)
        return try scoped(index) { try f(value.getArray()) }
    }
    
    /// Subscripts the receiver with `index` and passes the result to the given block.
    /// If the index is out of range or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getArrayOrNil<T>(index: Int, @noescape _ f: JSONArray throws -> T?) throws -> T? {
        let ary = try getArray()
        guard let value = ary[safe: index] else { return nil }
        return try scoped(index) { try value.getArrayOrNil().flatMap(f) }
    }
}

// MARK: -

public extension JSONObject {
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getBool(key: Swift.String) throws -> Swift.Bool {
        let value = try getRequired(self, key: key, type: .String)
        return try scoped(key) { try value.getBool() }
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getBoolOrNil(key: Swift.String) throws -> Swift.Bool? {
        guard let value = self[key] else { return nil }
        return try scoped(key) { try value.getBoolOrNil() }
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getString(key: Swift.String) throws -> Swift.String {
        let value = try getRequired(self, key: key, type: .String)
        return try scoped(key) { try value.getString() }
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getStringOrNil(key: Swift.String) throws -> Swift.String? {
        guard let value = self[key] else { return nil }
        return try scoped(key) { try value.getStringOrNil() }
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getInt64(key: Swift.String) throws -> Swift.Int64 {
        let value = try getRequired(self, key: key, type: .Number)
        return try scoped(key) { try value.getInt64() }
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getInt64OrNil(key: Swift.String) throws -> Swift.Int64? {
        guard let value = self[key] else { return nil }
        return try scoped(key) { try value.getInt64OrNil() }
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getDouble(key: Swift.String) throws -> Swift.Double {
        let value = try getRequired(self, key: key, type: .Number)
        return try scoped(key) { try value.getDouble() }
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getDoubleOrNil(key: Swift.String) throws -> Swift.Double? {
        guard let value = self[key] else { return nil }
        return try scoped(key) { try value.getDoubleOrNil() }
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value has the wrong type, an error is thrown.
    /// - Note: Use `getObject(_:_:)` when using throwing accessors on the resulting
    ///   object value to produce better errors.
    /// - Throws: `JSONError`
    /// - SeeAlso: `getObject(_:_:)`
    func getObject(key: Swift.String) throws -> JSONObject {
        return try getObject(key, { $0 })
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Note: Use `getObjectOrNil(_:_:)` when using throwing accessors on the resulting
    ///   object value to produce better errors.
    /// - Throws: `JSONError`
    /// - SeeAlso: `getObjectOrNil(_:_:)`
    func getObjectOrNil(key: Swift.String) throws -> JSONObject? {
        return try getObjectOrNil(key, { $0 })
    }
    
    /// Subscripts the receiver with `key` and passes the result to the given block.
    /// If the key doesn't exist or the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getObject<T>(key: Swift.String, @noescape _ f: JSONObject throws -> T) throws -> T {
        let value = try getRequired(self, key: key, type: .Object)
        return try scoped(key) { try f(value.getObject()) }
    }
    
    /// Subscripts the receiver with `key` and passes the result to the given block.
    /// If the key doesn't exist or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getObjectOrNil<T>(key: Swift.String, @noescape _ f: JSONObject throws -> T?) throws -> T? {
        guard let value = self[key] else { return nil }
        return try scoped(key) { try value.getObjectOrNil().flatMap(f) }
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value has the wrong type, an error is thrown.
    /// - Note: Use `getArray(_:_:)` when using throwing accessors on the resulting
    ///   array value to produce better errors.
    /// - Throws: `JSONError`
    /// - SeeAlso: `getArray(_:_:)`
    func getArray(key: Swift.String) throws -> JSONArray {
        return try getArray(key, { $0 })
    }
    
    /// Subscripts the receiver with `key` and returns the result.
    /// If the key doesn't exist or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Note: Use `getArrayOrNil(_:_:)` when using throwing accessors on the resulting
    ///   array value to produce better errors.
    /// - Throws: `JSONError`
    /// - SeeAlso: `getArrayOrNil(_:_:)`
    func getArrayOrNil(key: Swift.String) throws -> JSONArray? {
        return try getArrayOrNil(key, { $0 })
    }
    
    /// Subscripts the receiver with `key` and passes the result to the given block.
    /// If the key doesn't exist or the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getArray<T>(key: Swift.String, @noescape _ f: JSONArray throws -> T) throws -> T {
        let value = try getRequired(self, key: key, type: .Array)
        return try scoped(key) { try f(value.getArray()) }
    }
    
    /// Subscripts the receiver with `key` and passes the result to the given block.
    /// If the key doesn't exist or the value is `null`, returns `nil`.
    /// If the value has the wrong type, an error is thrown.
    /// - Throws: `JSONError`
    func getArrayOrNil<T>(key: Swift.String, @noescape _ f: JSONArray throws -> T?) throws -> T? {
        guard let value = self[key] else { return nil }
        return try scoped(key) { try value.getArrayOrNil().flatMap(f) }
    }
}

// MARK: - JSONArray helpers

public extension JSON {
    /// Returns an `Array` containing the results of mapping `transform` over `array`.
    /// If `transform` throws a `JSONError`, the error will be modified to include the index
    /// of the element that caused the error.
    /// - Parameter array: The `JSONArray` to map over.
    /// - Parameter transform: A block that is called once for each element of `array`.
    /// - Returns: An array with the results of mapping `transform` over `array`.
    /// - Throws: Rethrows any error thrown by `transform`.
    /// - Complexity: O(*N*).
    /// - Bug: This method must be marked as `throws` instead of `rethrows` because of Swift compiler
    ///   limitations. If you want to map an array with a non-throwing transform function, use
    ///   `SequenceType.map` instead.
    static func map<T>(array: JSONArray, @noescape _ transform: JSON throws -> T) throws -> [T] {
        return try array.enumerate().map({ i, elt in try scoped(i, f: { try transform(elt) }) })
    }
    
    /// Returns an `Array` containing the non-`nil` results of mapping `transform` over `array`.
    /// If `transform` throws a `JSONError`, the error will be modified to include the index
    /// of the element that caused the error.
    /// - Parameter array: The `JSONArray` to map over.
    /// - Parameter transform: A block that is called once for each element of `array`.
    /// - Returns: An array with the non-`nil` results of mapping `transform` over `array`.
    /// - Throws: Rethrows any error thrown by `transform`.
    /// - Complexity: O(*M* + *N*) where *M* is the length of `array` and *N* is the length of the result.
    /// - Bug: This method must be marked as `throws` instead of `rethrows` because of Swift compiler
    ///   limitations. If you want to map an array with a non-throwing transform function, use
    ///   `SequenceType.flatMap` instead.
    static func flatMap<T>(array: JSONArray, @noescape _ transform: JSON throws -> T?) throws -> [T] {
        return try array.enumerate().flatMap({ i, elt in try scoped(i, f: { try transform(elt) }) })
    }
    
    /// Returns an `Array` containing the concatenated results of mapping `transform` over `array`.
    /// If `transform` throws a `JSONError`, the error will be modified to include the index
    /// of the element that caused the error.
    /// - Parameter array: The `JSONArray` to map over.
    /// - Parameter transform: A block that is called once for each element of `array`.
    /// - Returns: An array with the concatenated results of mapping `transform` over `array`.
    /// - Throws: Rethrows any error thrown by `transform`.
    /// - Complexity: O(*M* + *N*) where *M* is the length of `array` and *N* is the length of the result.
    /// - Bug: This method must be marked as `throws` instead of `rethrows` because of Swift compiler
    ///   limitations. If you want to map an array with a non-throwing transform function, use
    ///   `SequenceType.flatMap` instead.
    static func flatMap<S: SequenceType>(array: JSONArray, _ transform: JSON throws -> S) throws -> [S.Generator.Element] {
        // FIXME: Use SequenceType.flatMap() once it becomes @noescape
        var results: [S.Generator.Element] = []
        for (i, elt) in array.enumerate() {
            try scoped(i) {
                results.appendContentsOf(try transform(elt))
            }
        }
        return results
    }
}

// MARK: -

private func getRequired(dict: JSONObject, key: String, type: JSONError.JSONType) throws -> JSON {
    guard let value = dict[key] else { throw JSONError.MissingOrInvalidType(path: key, expected: .Required(type), actual: nil) }
    return value
}

private func getRequired(ary: JSONArray, index: Int, type: JSONError.JSONType) throws -> JSON {
    guard let value = ary[safe: index] else { throw JSONError.MissingOrInvalidType(path: "[\(index)]", expected: .Required(type), actual: nil) }
    return value
}

@inline(__always)
private func scoped<T>(key: String, @noescape f: () throws -> T) throws -> T {
    do {
        return try f()
    } catch let error as JSONError {
        throw error.withPrefix(key)
    }
}

@inline(__always)
private func scoped<T>(index: Int, @noescape f: () throws -> T) throws -> T {
    do {
        return try f()
    } catch let error as JSONError {
        throw error.withPrefix("[\(index)]")
    }
}

private extension ContiguousArray {
    subscript(safe index: Int) -> Element? {
        guard index >= startIndex && index < endIndex else { return nil }
        return self[index]
    }
}

//
//  Codable.swift
//  PMJSON
//
//  Created by Kevin Ballard on 2/13/18.
//  Copyright © 2018 Kevin Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import Foundation

extension JSON {
    /// An object that decodes instances of data types that conform to `Decodable` from JSON
    /// streams.
    public struct Decoder {
        /// A dictionary you use to customize the decoding process by providing contextual information.
        public var userInfo: [CodingUserInfoKey: Any] = [:]
        
        /// Creates a new, reusable JSON decoder.
        public init() {}
        
        /// Returns a value of the type you specify, decoded from JSON.
        ///
        /// - Parameter type: The type of the object to decode.
        /// - Parameter data: The data containing JSON to decode.
        /// - Parameter options: An optional set of options to control the JSON decoder.
        /// - Returns: An instance of `type`.
        /// - Throws: `DecoderError.dataCorrupted` if the JSON fails to decode (where the
        ///   `underlyingError` on the context is a `JSONParserError`), or any of the other
        ///   `DecoderError`s if the object decode fails.
        public func decode<T: Decodable>(_ type: T.Type, from data: Data, options: JSONOptions = []) throws -> T {
            let json: JSON
            do {
                json = try JSON.decode(data, options: options)
            } catch {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "The given data was not valid JSON.", underlyingError: error))
            }
            return try decode(type, from: json)
        }
        
        /// Returns a value of the type you specify, decoded from JSON.
        ///
        /// - Parameter type: The type of the object to decode.
        /// - Parameter string: The string containing JSON to decode.
        /// - Parameter options: An optional set of options to control the JSON decoder.
        /// - Returns: An instance of `type`.
        /// - Throws: `DecoderError.dataCorrupted` if the JSON fails to decode (where the
        ///   `underlyingError` on the context is a `JSONParserError`), or any of the other
        ///   `DecoderError`s if the object decode fails.
        public func decode<T: Decodable>(_ type: T.Type, from string: String, options: JSONOptions = []) throws -> T {
            let json: JSON
            do {
                json = try JSON.decode(string, options: options)
            } catch {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "The given string was not valid JSON.", underlyingError: error))
            }
            return try decode(type, from: json)
        }
        
        /// Returns a value of the type you specify, decoded from JSON.
        ///
        /// - Parameter type: The type of the object to decode.
        /// - Parameter json: The JSON to decode.
        /// - Returns: An instance of `type`.
        /// - Throws: `DecoderError` if the object decode fails.
        public func decode<T: Decodable>(_ type: T.Type, from json: JSON) throws -> T {
            let data = DecoderData()
            data.userInfo = userInfo
            let decoder = _JSONDecoder(data: data, value: json)
            return try T(from: decoder)
        }
    }
}

private class DecoderData {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    
    func copy() -> DecoderData {
        let result = DecoderData()
        result.codingPath = codingPath
        result.userInfo = userInfo
        return result
    }
}

private struct _JSONDecoder: Decoder {
    init(data: DecoderData, value: JSON) {
        _data = data
        self.value = value
    }
    
    let _data: DecoderData
    let value: JSON
    
    // MARK: Decoder
    
    var codingPath: [CodingKey] {
        return _data.codingPath
    }
    
    var userInfo: [CodingUserInfoKey: Any] {
        return _data.userInfo
    }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        let object = try _wrapTypeMismatch({ try value.getObject() }, data: _data)
        return KeyedDecodingContainer(_JSONKeyedDecoder(data: _data, value: object))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        let array = try _wrapTypeMismatch({ try value.getArray() }, data: _data)
        return _JSONUnkeyedDecoder(data: _data, value: array)
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return self
    }
}

// MARK: -

extension _JSONDecoder: SingleValueDecodingContainer {
    private func wrapTypeMismatch<T>(_ f: @autoclosure () throws -> T) throws -> T {
        return try _wrapTypeMismatch(f, data: _data)
    }
    
    private func castNumber<T: Numeric, U: BinaryInteger>(_ value: U) throws -> T {
        return try _castNumber(value, data: _data)
    }
    
    func decodeNil() -> Bool {
        return value.isNull
    }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        return try wrapTypeMismatch(value.getBool())
    }
    
    func decode(_ type: Int.Type) throws -> Int {
        return try wrapTypeMismatch(value.getInt())
    }
    
    func decode(_ type: Int8.Type) throws -> Int8 {
        return try castNumber(wrapTypeMismatch(value.getInt()))
    }
    
    func decode(_ type: Int16.Type) throws -> Int16 {
        return try castNumber(wrapTypeMismatch(value.getInt()))
    }
    
    func decode(_ type: Int32.Type) throws -> Int32 {
        return try castNumber(wrapTypeMismatch(value.getInt()))
    }
    
    func decode(_ type: Int64.Type) throws -> Int64 {
        return try wrapTypeMismatch(value.getInt64())
    }
    
    func decode(_ type: UInt.Type) throws -> UInt {
        return try castNumber(_getUInt64(from: value, data: _data))
    }
    
    func decode(_ type: UInt8.Type) throws -> UInt8 {
        return try castNumber(wrapTypeMismatch(value.getInt()))
    }
    
    func decode(_ type: UInt16.Type) throws -> UInt16 {
        return try castNumber(wrapTypeMismatch(value.getInt()))
    }
    
    func decode(_ type: UInt32.Type) throws -> UInt32 {
        return try castNumber(wrapTypeMismatch(value.getInt64()))
    }
    
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        return try _getUInt64(from: value, data: _data)
    }
    
    func decode(_ type: Float.Type) throws -> Float {
        return try Float(wrapTypeMismatch(value.getDouble()))
    }
    
    func decode(_ type: Double.Type) throws -> Double {
        return try wrapTypeMismatch(value.getDouble())
    }
    
    func decode(_ type: String.Type) throws -> String {
        return try wrapTypeMismatch(value.getString())
    }
    
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        return try T(from: self)
    }
}

private struct _JSONKeyedDecoder<K: CodingKey>: KeyedDecodingContainerProtocol {
    init(data: DecoderData, value: JSONObject) {
        _data = data
        self.value = value
    }
    
    let _data: DecoderData
    let value: JSONObject
    
    typealias Key = K
    
    var codingPath: [CodingKey] {
        return _data.codingPath
    }
    
    var allKeys: [K] {
        return Array(value.keys.flatMap(K.init(stringValue:)))
    }
    
    func contains(_ key: K) -> Bool {
        return value[key.stringValue] != nil
    }
    
    private func wrapTypeMismatch<T>(forKey key: K, _ f: @autoclosure () throws -> T) throws -> T {
        return try _wrapTypeMismatch(key: key, f, data: _data)
    }
    
    private func castNumber<T: Numeric, U: BinaryInteger>(_ value: U) throws -> T {
        return try _castNumber(value, data: _data)
    }
    
    func decodeNil(forKey key: K) throws -> Bool {
        guard let value = value[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: _data.codingPath, debugDescription: "No value associated with key \(key) (\(String(reflecting: key.stringValue)))"))
        }
        return value.isNull
    }
    
    func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
        return try wrapTypeMismatch(forKey: key, try value.getBool(key.stringValue))
    }
    
    func decode(_ type: Int.Type, forKey key: K) throws -> Int {
        return try wrapTypeMismatch(forKey: key, value.getInt(key.stringValue))
    }
    
    func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 {
        return try castNumber(wrapTypeMismatch(forKey: key, value.getInt(key.stringValue)))
    }
    
    func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 {
        return try castNumber(wrapTypeMismatch(forKey: key, value.getInt(key.stringValue)))
    }
    
    func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 {
        return try castNumber(wrapTypeMismatch(forKey: key, value.getInt(key.stringValue)))
    }
    
    func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 {
        return try wrapTypeMismatch(forKey: key, value.getInt64(key.stringValue))
    }
    
    func decode(_ type: UInt.Type, forKey key: K) throws -> UInt {
        guard let value = value[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: _data.codingPath, debugDescription: "No value associated with key \(key) (\(String(reflecting: key.stringValue)))"))
        }
        return try castNumber(_getUInt64(from: value, data: _data))
    }
    
    func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 {
        return try castNumber(wrapTypeMismatch(forKey: key, value.getInt(key.stringValue)))
    }
    
    func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 {
        return try castNumber(wrapTypeMismatch(forKey: key, value.getInt(key.stringValue)))
    }
    
    func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 {
        return try castNumber(wrapTypeMismatch(forKey: key, value.getInt64(key.stringValue)))
    }
    
    func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 {
        guard let value = value[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: _data.codingPath, debugDescription: "No value associated with key \(key) (\(String(reflecting: key.stringValue)))"))
        }
        return try _getUInt64(from: value, data: _data)
    }
    
    func decode(_ type: Float.Type, forKey key: K) throws -> Float {
        return try Float(wrapTypeMismatch(forKey: key, value.getDouble(key.stringValue)))
    }
    
    func decode(_ type: Double.Type, forKey key: K) throws -> Double {
        return try wrapTypeMismatch(forKey: key, value.getDouble(key.stringValue))
    }
    
    func decode(_ type: String.Type, forKey key: K) throws -> String {
        return try wrapTypeMismatch(forKey: key, value.getString(key.stringValue))
    }
    
    func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T : Decodable {
        guard let value = value[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: _data.codingPath, debugDescription: "No value associated with key \(key) (\(String(reflecting: key.stringValue)))"))
        }
        _data.codingPath.append(key)
        defer { _data.codingPath.removeLast() }
        return try T(from: _JSONDecoder(data: _data, value: value))
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        let object = try wrapTypeMismatch(forKey: key, value.getObject(key.stringValue))
        let data = _data.copy()
        data.codingPath.append(key)
        return KeyedDecodingContainer(_JSONKeyedDecoder<NestedKey>(data: data, value: object))
    }
    
    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        let array = try wrapTypeMismatch(forKey: key, value.getArray(key.stringValue))
        let data = _data.copy()
        data.codingPath.append(key)
        return _JSONUnkeyedDecoder(data: data, value: array)
    }
    
    func superDecoder() throws -> Decoder {
        return try _superDecoder(forKey: JSONKey.super)
    }
    
    func superDecoder(forKey key: K) throws -> Decoder {
        return try _superDecoder(forKey: key)
    }
    
    private func _superDecoder(forKey key: CodingKey) throws -> Decoder {
        let data = _data.copy()
        data.codingPath.append(key)
        return _JSONDecoder(data: data, value: value[key.stringValue] ?? .null)
    }
}

private enum JSONKey: CodingKey {
    static let `super` = JSONKey.string("super")
    
    case int(Int)
    case string(String)
    
    var stringValue: String {
        switch self {
        case .int(let x): return String(x)
        case .string(let s): return s
        }
    }
    
    var intValue: Int? {
        switch self {
        case .int(let x): return x
        case .string: return nil
        }
    }
    
    init?(stringValue: String) {
        self = .string(stringValue)
    }
    
    init?(intValue: Int) {
        self = .int(intValue)
    }
}

private struct _JSONUnkeyedDecoder: UnkeyedDecodingContainer {
    private let _data: DecoderData
    private let value: JSONArray
    
    init(data: DecoderData, value: JSONArray) {
        _data = data
        self.value = value
    }
    
    var codingPath: [CodingKey] {
        return _data.codingPath
    }
    
    var count: Int? {
        return value.count
    }
    
    var isAtEnd: Bool {
        return currentIndex == value.count
    }
    
    private(set) var currentIndex: Int = 0
    
    private func wrapTypeMismatch<T>(_ f: @autoclosure () throws -> T) throws -> T {
        return try _wrapTypeMismatch(f, data: _data)
    }
    
    private func castNumber<T: Numeric, U: BinaryInteger>(_ value: U) throws -> T {
        return try _castNumber(value, data: _data)
    }
    
    private func assertNotAtEnd<T>(_ expectedType: T.Type) throws {
        if isAtEnd {
            throw DecodingError.valueNotFound(expectedType, DecodingError.Context(codingPath: _data.codingPath + [JSONKey.int(currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
    }
    
    mutating func decodeNil() throws -> Bool {
        try assertNotAtEnd(JSON.self)
        if value[currentIndex].isNull {
            currentIndex += 1
            return true
        } else {
            return false
        }
    }
    
    mutating func decode(_ type: Bool.Type) throws -> Bool {
        try assertNotAtEnd(type)
        let result = try wrapTypeMismatch(value[currentIndex].getBool())
        currentIndex += 1
        return result
    }
    
    mutating func decode(_ type: Int.Type) throws -> Int {
        try assertNotAtEnd(type)
        let result = try wrapTypeMismatch(value[currentIndex].getInt())
        currentIndex += 1
        return result
    }
    
    mutating func decode(_ type: Int8.Type) throws -> Int8 {
        try assertNotAtEnd(type)
        let result: Int8 = try castNumber(wrapTypeMismatch(value[currentIndex].getInt()))
        currentIndex += 1
        return result
    }
    
    mutating func decode(_ type: Int16.Type) throws -> Int16 {
        try assertNotAtEnd(type)
        let result: Int16 = try castNumber(wrapTypeMismatch(value[currentIndex].getInt()))
        currentIndex += 1
        return result
    }
    
    mutating func decode(_ type: Int32.Type) throws -> Int32 {
        try assertNotAtEnd(type)
        let result: Int32 = try castNumber(wrapTypeMismatch(value[currentIndex].getInt()))
        currentIndex += 1
        return result
    }
    
    mutating func decode(_ type: Int64.Type) throws -> Int64 {
        try assertNotAtEnd(type)
        let result = try wrapTypeMismatch(value[currentIndex].getInt64())
        currentIndex += 1
        return result
    }
    
    mutating func decode(_ type: UInt.Type) throws -> UInt {
        try assertNotAtEnd(type)
        let result: UInt = try castNumber(_getUInt64(from: value[currentIndex], data: _data))
        currentIndex += 1
        return result
    }
    
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        try assertNotAtEnd(type)
        let result: UInt8 = try castNumber(wrapTypeMismatch(value[currentIndex].getInt()))
        currentIndex += 1
        return result
    }
    
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        try assertNotAtEnd(type)
        let result: UInt16 = try castNumber(wrapTypeMismatch(value[currentIndex].getInt()))
        currentIndex += 1
        return result
    }
    
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        try assertNotAtEnd(type)
        let result: UInt32 = try castNumber(wrapTypeMismatch(value[currentIndex].getInt64()))
        currentIndex += 1
        return result
    }
    
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        try assertNotAtEnd(type)
        let result = try _getUInt64(from: value[currentIndex], data: _data)
        currentIndex += 1
        return result
    }
    
    mutating func decode(_ type: Float.Type) throws -> Float {
        try assertNotAtEnd(type)
        let result = try Float(wrapTypeMismatch(value[currentIndex].getDouble()))
        currentIndex += 1
        return result
    }
    
    mutating func decode(_ type: Double.Type) throws -> Double {
        try assertNotAtEnd(type)
        let result = try wrapTypeMismatch(value[currentIndex].getDouble())
        currentIndex += 1
        return result
    }
    
    mutating func decode(_ type: String.Type) throws -> String {
        try assertNotAtEnd(type)
        let result = try wrapTypeMismatch(value[currentIndex].getString())
        currentIndex += 1
        return result
    }
    
    mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        try assertNotAtEnd(type)
        _data.codingPath.append(JSONKey.int(currentIndex))
        defer { _data.codingPath.removeLast() }
        let result = try T(from: _JSONDecoder(data: _data, value: value[currentIndex]))
        currentIndex += 1
        return result
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try assertNotAtEnd(type)
        let object = try wrapTypeMismatch(value[currentIndex].getObject())
        let data = _data.copy()
        data.codingPath.append(JSONKey.int(currentIndex))
        currentIndex += 1
        return KeyedDecodingContainer(_JSONKeyedDecoder<NestedKey>(data: data, value: object))
    }
    
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        try assertNotAtEnd(JSONArray.self)
        let array = try wrapTypeMismatch(value[currentIndex].getArray())
        let data = _data.copy()
        data.codingPath.append(JSONKey.int(currentIndex))
        currentIndex += 1
        return _JSONUnkeyedDecoder(data: data, value: array)
    }
    
    mutating func superDecoder() throws -> Decoder {
        try assertNotAtEnd(JSON.self)
        let data = _data.copy()
        data.codingPath.append(JSONKey.int(currentIndex))
        let decoder = _JSONDecoder(data: data, value: value[currentIndex])
        currentIndex += 1
        return decoder
    }
}

// MARK: -

private func _wrapTypeMismatch<T>(key: CodingKey? = nil, _ f: () throws -> T, data: DecoderData) throws -> T {
    do {
        return try f()
    } catch let error as JSONError {
        let prefix = key.map({ "Failed to decode value for key \($0) (\(String(reflecting: $0.stringValue))) - " }) ?? ""
        switch error {
        case .missingOrInvalidType(path: _, let expected, let actual):
            if actual == nil, let key = key {
                throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: data.codingPath, debugDescription: "\(prefix)Expected to decode \(expected) but found missing value", underlyingError: error))
            } else {
                throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: data.codingPath, debugDescription: "\(prefix)Expected to decode \(expected) but found \(actual.map(String.init(describing:)) ?? "nil")", underlyingError: error))
            }
        case .outOfRangeInt64(path: _, let value, let expected):
            throw DecodingError.typeMismatch(expected, DecodingError.Context(codingPath: data.codingPath, debugDescription: "\(prefix)Expected to decode \(expected) but found out of range integer \(value)", underlyingError: error))
        case .outOfRangeDouble(path: _, let value, let expected):
            throw DecodingError.typeMismatch(expected, DecodingError.Context(codingPath: data.codingPath, debugDescription: "\(prefix)Expected to decode \(expected) but found out of range double \(value)", underlyingError: error))
        case .outOfRangeDecimal(path: _, let value, let expected):
            throw DecodingError.typeMismatch(expected, DecodingError.Context(codingPath: data.codingPath, debugDescription: "\(prefix)Expected to decode \(expected) but found out of range decimal \(value)", underlyingError: error))
        }
    } catch {
        // We shouldn't get any other error type
        let prefix = key.map({ "Failed to decode value for key \($0) (\(String(reflecting: $0.stringValue))) - " }) ?? ""
        throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: data.codingPath, debugDescription: "\(prefix)Expected to decode \(T.self) but got error \(error)", underlyingError: error))
    }
}

private func _castNumber<T: Numeric, U: BinaryInteger>(_ value: U, data: DecoderData) throws -> T {
    guard let result = T(exactly: value) else {
        throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: data.codingPath, debugDescription: "Expected to decode \(T.self) but found out of range integer \(value)"))
    }
    return result
}

private func _getUInt64(from value: JSON, data: DecoderData) throws -> UInt64 {
    switch value {
    case .int64(let value):
        return try _castNumber(value, data: data)
    case .double(let value):
        guard let result = UInt64(exactly: value) else {
            throw DecodingError.typeMismatch(UInt64.self, DecodingError.Context(codingPath: data.codingPath, debugDescription: "Expected to decode UInt64 but found out of range double \(value)"))
        }
        return result
    case .decimal(let value):
        guard let result = convertDecimalToUInt64(value) else {
            throw DecodingError.typeMismatch(UInt64.self, DecodingError.Context(codingPath: data.codingPath, debugDescription: "Expected to decode UInt64 but found out of range decimal \(value)"))
        }
        return result
    default:
        throw DecodingError.typeMismatch(UInt64.self, DecodingError.Context(codingPath: data.codingPath, debugDescription: "Expected to decode UInt64 but found \(JSONError.JSONType.forValue(value))"))
    }
}

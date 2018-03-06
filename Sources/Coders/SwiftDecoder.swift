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
        
        /// The strategy to use for decoding keys. Defaults to `.useDefaultKeys`.
        public var keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys
        
        /// If `true`, apply the `keyDecodingStrategy` to the keys on any nested decoded
        /// `JSONObject`. The default value is `false`.
        ///
        /// This defaults to `false` because the assumption is if you're decoding a `JSONObject`,
        /// you want it to decode as-is.
        ///
        /// This property also affects decoding `JSON` values that contain objects.
        ///
        /// - Note: This property does not affect the encoding of `Dictionary`.
        public var applyKeyDecodingStrategyToJSONObject = false
        
        /// The strategy to use in decoding dates. Defaults to `.deferredToDate`.
        public var dateDecodingStrategy: DateDecodingStrategy = .deferredToDate
        
        /// The strategy to use in decoding binary data. Defaults to `.base64`.
        public var dataDecodingStrategy: DataDecodingStrategy = .base64
        
        /// Creates a new, reusable JSON decoder.
        public init() {}
        
        /// Returns a value of the type you specify, decoded from JSON.
        ///
        /// - Parameter type: The type of the object to decode.
        /// - Parameter data: The data containing JSON to decode.
        /// - Parameter options: An optional set of options to control the JSON decoder.
        /// - Returns: An instance of `type`.
        /// - Throws: `DecodingError.dataCorrupted` if the JSON fails to decode (where the
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
        /// - Throws: `DecodingError.dataCorrupted` if the JSON fails to decode (where the
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
        /// - Throws: `DecodingError` if the object decode fails.
        public func decode<T: Decodable>(_ type: T.Type, from json: JSON) throws -> T {
            let data = DecoderData()
            data.userInfo = userInfo
            data.keyDecodingStrategy = keyDecodingStrategy
            data.applyKeyDecodingStrategyToJSONObject = applyKeyDecodingStrategyToJSONObject
            data.dateDecodingStrategy = dateDecodingStrategy
            data.dataDecodingStrategy = dataDecodingStrategy
            return try _JSONDecoder(data: data, value: json).decode(type)
        }
    }
}

private class DecoderData {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    var keyDecodingStrategy: JSON.Decoder.KeyDecodingStrategy = .useDefaultKeys
    var applyKeyDecodingStrategyToJSONObject = false
    var dateDecodingStrategy: JSON.Decoder.DateDecodingStrategy = .deferredToDate
    var dataDecodingStrategy: JSON.Decoder.DataDecodingStrategy = .base64
    
    func copy() -> DecoderData {
        let result = DecoderData()
        result.codingPath = codingPath
        result.userInfo = userInfo
        result.keyDecodingStrategy = keyDecodingStrategy
        result.applyKeyDecodingStrategyToJSONObject = applyKeyDecodingStrategyToJSONObject
        result.dateDecodingStrategy = dateDecodingStrategy
        result.dataDecodingStrategy = dataDecodingStrategy
        return result
    }
}

internal struct _JSONDecoder: Decoder {
    fileprivate init(data: DecoderData, value: JSON) {
        _data = data
        switch (data.keyDecodingStrategy, value) {
        case (.useDefaultKeys, _):
            self.value = .primitive(value)
        case (_, .object(let object)):
            // If we have duplicate keys, keep the first one we saw. This matches `JSONDecoder`.
            let rekeyed: JSONObject
            switch _data.keyDecodingStrategy {
            case .useDefaultKeys:
                // this shouldn't happen
                rekeyed = object
            case .convertFromSnakeCase:
                rekeyed = JSONObject(dict: Dictionary(object.dictionary.map({ (key, value) in
                    (JSON.Decoder.KeyDecodingStrategy._convertFromSnakeCase(key), value)
                }), uniquingKeysWith: { (first, _) in first }))
            case .custom(let f):
                rekeyed = JSONObject(dict: Dictionary(object.dictionary.map({ [codingPath=data.codingPath] (key, value) in
                    (f(codingPath, JSONKey.string(key)).stringValue, value)
                }), uniquingKeysWith: { (first, _) in first }))
            }
            self.value = .object(object, rekeyed: rekeyed)
        case (_, .array(let array)):
            self.value = .array(array)
        default:
            self.value = .primitive(value)
        }
    }
    
    private let _data: DecoderData
    private let value: Value
    
    private enum Value {
        /// Used for JSON primitives, or for everything if our key decoding strategy is
        /// `.useDefaultKeys`.
        case primitive(JSON)
        case object(JSONObject, rekeyed: JSONObject)
        case array(JSONArray)
        
        var asJSON: JSON {
            switch self {
            case .primitive(let json): return json
            case .object(_, let rekeyed): return .object(rekeyed)
            case .array(let array): return .array(array)
            }
        }
    }
    
    // MARK: Decoder
    
    var codingPath: [CodingKey] {
        return _data.codingPath
    }
    
    var userInfo: [CodingUserInfoKey: Any] {
        return _data.userInfo
    }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        let object: JSONObject
        switch value {
        case .primitive(let json):
            object = try _wrapTypeMismatch({ try json.getObject() }, data: _data)
        case .object(_, let rekeyed):
            // If we reach here and we're decoding a JSON or JSONObject, we already know
            // applyKeyDecodingStrategyToJSONObject is set
            object = rekeyed
        case .array:
            throw DecodingError.typeMismatch(JSONObject.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected to decode object but found array"))
        }
        return KeyedDecodingContainer(_JSONKeyedDecoder(data: _data, value: object))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        let array: JSONArray
        switch value {
        case .primitive(let json):
            array = try _wrapTypeMismatch({ try json.getArray() }, data: _data)
        case .object:
            throw DecodingError.typeMismatch(JSONObject.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected to decode array but found object"))
        case .array(let array_):
            array = array_
        }
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
        return value.asJSON.isNull
    }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        return try wrapTypeMismatch(value.asJSON.getBool())
    }
    
    func decode(_ type: Int.Type) throws -> Int {
        return try wrapTypeMismatch(value.asJSON.getInt())
    }
    
    func decode(_ type: Int8.Type) throws -> Int8 {
        return try castNumber(wrapTypeMismatch(value.asJSON.getInt()))
    }
    
    func decode(_ type: Int16.Type) throws -> Int16 {
        return try castNumber(wrapTypeMismatch(value.asJSON.getInt()))
    }
    
    func decode(_ type: Int32.Type) throws -> Int32 {
        return try castNumber(wrapTypeMismatch(value.asJSON.getInt()))
    }
    
    func decode(_ type: Int64.Type) throws -> Int64 {
        return try wrapTypeMismatch(value.asJSON.getInt64())
    }
    
    func decode(_ type: UInt.Type) throws -> UInt {
        return try castNumber(_getUInt64(from: value.asJSON, data: _data))
    }
    
    func decode(_ type: UInt8.Type) throws -> UInt8 {
        return try castNumber(wrapTypeMismatch(value.asJSON.getInt()))
    }
    
    func decode(_ type: UInt16.Type) throws -> UInt16 {
        return try castNumber(wrapTypeMismatch(value.asJSON.getInt()))
    }
    
    func decode(_ type: UInt32.Type) throws -> UInt32 {
        return try castNumber(wrapTypeMismatch(value.asJSON.getInt64()))
    }
    
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        return try _getUInt64(from: value.asJSON, data: _data)
    }
    
    func decode(_ type: Float.Type) throws -> Float {
        return try Float(wrapTypeMismatch(value.asJSON.getDouble()))
    }
    
    func decode(_ type: Double.Type) throws -> Double {
        return try wrapTypeMismatch(value.asJSON.getDouble())
    }
    
    func decode(_ type: String.Type) throws -> String {
        return try wrapTypeMismatch(value.asJSON.getString())
    }
    
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        switch type {
        case is JSON.Type:
            switch value {
            case .primitive(let json):
                return json as! T
            case .object where _data.applyKeyDecodingStrategyToJSONObject:
                break
            case .object(let object, _):
                return JSON.object(object) as! T
            case .array where _data.applyKeyDecodingStrategyToJSONObject:
                break
            case .array(let array):
                return JSON.array(array) as! T
            }
        case is JSONObject.Type:
            switch value {
            case .primitive(let json):
                return try wrapTypeMismatch(json.getObject()) as! T
            case .object where _data.applyKeyDecodingStrategyToJSONObject:
                break
            case .object(let object, _):
                return object as! T
            case .array:
                throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected JSONObject, found array"))
            }
        case is JSONArray.Type:
            // SR-7076 ContiguousArray doesn't conform to Decodable (as of Swift 4.0.3), so this
            // branch will never actually be reached, but we'll leave it here in case the Decodable
            // conformance is ever added.
            switch value {
            case .primitive(let json):
                return try wrapTypeMismatch(json.getArray()) as! T
            case .object:
                throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected JSONArray, found object"))
            case .array where _data.applyKeyDecodingStrategyToJSONObject:
                break
            case .array(let array):
                return array as! T
            }
        case is Decimal.Type:
            if case .primitive(.decimal(let d)) = value {
                return d as! T
            }
        case is Date.Type:
            switch _data.dateDecodingStrategy {
            case .deferredToDate:
                break
            case .secondsSince1970:
                let seconds = try wrapTypeMismatch(value.asJSON.getDouble())
                return Date(timeIntervalSince1970: seconds) as! T
            case .millisecondsSince1970:
                let ms = try wrapTypeMismatch(value.asJSON.getDouble())
                return Date(timeIntervalSince1970: ms / 1000) as! T
            case .iso8601:
                if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
                    let str = try wrapTypeMismatch(value.asJSON.getString())
                    guard let date = _iso8601Formatter.date(from: str) else {
                        throw DecodingError.dataCorruptedError(in: self, debugDescription: "Expected date string to be ISO8601-formatted.")
                    }
                    return date as! T
                } else {
                    fatalError("ISO8601DateFormatter is not available on this platform")
                }
            case .iso8601WithFractionalSeconds:
                #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
                    if #available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *) {
                        let str = try wrapTypeMismatch(value.asJSON.getString())
                        guard let date = _iso8601FractionalSecondsFormatter.date(from: str) ?? _iso8601Formatter.date(from: str) else {
                            throw DecodingError.dataCorruptedError(in: self, debugDescription: "Expected date string to be ISO8601-formatted.")
                        }
                        return date as! T
                    } else {
                        fatalError("ISO8601DateFormatter.Options.withFractionalSeconds is not available on this platform")
                    }
                #else
                    fatalError("ISO8601DateFormatter.Options.withFractionalSeconds is not available on this platform")
                #endif
            case .formatted(let formatter):
                let str = try wrapTypeMismatch(value.asJSON.getString())
                guard let date = formatter.date(from: str) else {
                    throw DecodingError.dataCorruptedError(in: self, debugDescription: "Date string does not match format expected by formatter.")
                }
                return date as! T
            case .custom(let decode):
                return try decode(self) as! T
            }
        case is Data.Type:
            switch _data.dataDecodingStrategy {
            case .deferredToData:
                break
            case .base64:
                let str = try wrapTypeMismatch(value.asJSON.getString())
                guard let data = Data(base64Encoded: str) else {
                    throw DecodingError.dataCorruptedError(in: self, debugDescription: "Encountered Data is not valid Base64.")
                }
                return data as! T
            case .custom(let decode):
                return try decode(self) as! T
            }
        default:
            break
        }
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
        return Array(value.keys.compactMap(K.init(stringValue:)))
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
        return try _JSONDecoder(data: _data, value: value).decode(type)
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
        let result = try _JSONDecoder(data: _data, value: value[currentIndex]).decode(type)
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

extension JSON.Decoder {
    /// The strategy to use for automatically changing the keys before decoding.
    public enum KeyDecodingStrategy {
        /// Use the keys specified by each type. This is the default strategy.
        case useDefaultKeys
        
        /// Convert from "snake_case_keys" to "camelCaseKeys" before attempting to match a key with
        /// the one specified by each type.
        ///
        /// The conversion to uppercase uses the ICU "root" locale (meaning the conversion is not
        /// affected by the current locale).
        ///
        /// Converting from snake_case to camelCase:
        /// 1. Capitalizes each word starting after `_`.
        /// 2. Removes all `_` in between words.
        /// 3. Preserves all `_` at the start and end.
        ///
        /// For example, `one_two_three` becomes `oneTwoThree` and `__foo_bar__` becomes
        /// `__fooBar__`.
        ///
        /// - Note: Using this key encoding strategy incurs a minor performance cost.
        case convertFromSnakeCase
        
        /// Provide a custom conversion from the key used in the JSON to the key specified by the
        /// decoding type. The first parameter is the full path leading up to the current key, which
        /// can provide context for the conversion, and the second parameter is the key itself,
        /// which will be replaced by the return value from the function.
        ///
        /// - Note: If the result of the conversion is a duplicate key, only one value will be
        ///   present in the container for the type to decode from.
        case custom((_ codingPath: [CodingKey], _ key: CodingKey) -> CodingKey)
        
        fileprivate static func _convertFromSnakeCase(_ key: String) -> String {
            guard !key.isEmpty else { return key }
            
            let scalars = key.unicodeScalars
            
            guard let firstIdx = scalars.index(where: { $0 != "_" }),
                let lastIdx = scalars.reversed().index(where: { $0 != "_" })?.base
                else {
                    // the string is all underscores
                    return key
            }
            
            guard var nextUnderscoreIdx = scalars[firstIdx..<lastIdx].index(of: "_") else {
                // only one word
                return key
            }
            
            var result: String = String(scalars[..<nextUnderscoreIdx])
            while let nextOtherIdx = scalars[scalars.index(after: nextUnderscoreIdx)..<lastIdx].index(where: { $0 != "_" }) {
                guard let idx = scalars[scalars.index(after: nextOtherIdx)..<lastIdx].index(of: "_") else {
                    // this must be the last word
                    result.append(Substring(scalars[nextOtherIdx..<lastIdx]).capitalized)
                    break
                }
                result.append(Substring(scalars[nextOtherIdx..<idx]).capitalized)
                nextUnderscoreIdx = idx
            }
            if lastIdx != scalars.endIndex {
                result.unicodeScalars.append(contentsOf: scalars[lastIdx...])
            }
            return result
        }
    }
    
    /// The strategy to use for decoding `Date` values.
    public enum DateDecodingStrategy {
        /// Defer to `Date` for decoding. This is the default strategy.
        case deferredToDate
        
        /// Decode the `Date` as a UNIX timestamp from a JSON number.
        case secondsSince1970
        
        /// Decode the `Date` as UNIX millisecond timestamp from a JSON number.
        case millisecondsSince1970
        
        /// Decode the `Date` as an ISO8601-formatted string (in RFC 3339 format).
        ///
        /// This matches strings like `"1985-04-12T23:20:50Z"`.
        ///
        /// - Note: This does not match strings that include fractional seconds. Use
        ///   `.iso8601WithFractionalSeconds` for that.
        @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
        case iso8601
        
        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        /// Decode the `Date` as an ISO8601-formatted string (in RFC 3339 format) with fractional
        /// seconds.
        ///
        /// This matches strings like `"1985-04-12T23:20:50.52Z"`.
        ///
        /// - Note: If the decode fails, it will try again with `.iso8601`. This means it will match
        ///   strings with or without fractional seconds.
        @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
        case iso8601WithFractionalSeconds
        #else
        // swift-corelibs-foundation doesn't support `.withFractionalSeconds`. We still declare the
        // case though or we're in trouble trying to match it.
        /// Decode the `Date` as an ISO8601-formatted string (in RFC 3339 format) with fractional
        /// seconds.
        ///
        /// This matches strings like `"1985-04-12T23:20:50.52Z"`.
        ///
        /// - Note: If the decode fails, it will try again with `.iso8601`. This means it will match
        ///   strings with or without fractional seconds.
        ///
        /// - Important: This case is not supported on non-Apple platforms.
        @available(*, unavailable, message: "This case is not supported on non-Apple platforms")
        case iso8601WithFractionalSeconds
        #endif
        
        /// Decode the `Date` as a string parsed by the given formatter.
        case formatted(DateFormatter)
        
        /// Decode the `Date` as a custom value decoded by the given closure.
        case custom((_ decoder: Decoder) throws -> Date)
    }
    
    /// The strategy to use for decoding `Data` values.
    public enum DataDecodingStrategy {
        /// Defer to `Data` for decoding.
        case deferredToData
        
        /// Decode the `Data` from a Base64-encoded string. This is the default strategy.
        case base64
        
        /// Decodes the `Data` as a custom value decoded by the given closure.
        case custom((_ decoder: Decoder) throws -> Data)
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

@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
internal var _iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
    @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
    internal var _iso8601FractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
#endif

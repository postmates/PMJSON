//
//  SwiftEncoder.swift
//  PMJSON
//
//  Created by Kevin Ballard on 2/16/18.
//  Copyright © 2018 Kevin Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import Foundation

// There are two reasonable approaches to encoding here that are compatible with the fact that
// encoders aren't strictly scoped-based (because of nested keyed encoders, and super encoders, and
// the fact that you can ask for multiple container encoders from a single Encoder).
//
// The first is to build up a parallel JSON-like enum that boxes up objetcs/arrays so they can be
// shared with the containers. This approach is relatively simple, but the downside is if we want to
// create a `JSON` we need to deep-copy the whole thing (though with a streaming encoder we can
// serialize to `String`/`Data` without the deep copy).
//
// The second approach is to have the encoder hold an enum that contains either a `JSON` primitive
// or a boxed object/array, and have it write this value into its parent when it deinits. Because
// each container holds onto its parent, we ensure we've always written any nested values before we
// try to write our own value to our parent. The upside is we don't build up a parallel JSON
// structure, so we end up with a JSON without deep-copying. The downside here is this is a fair
// amount more complicated, and there's a lot of edge cases involved that need to be handled
// correctly, including some that I don't believe can be handled correctly, such as creating a
// nested container, writing some values to it, creating a second nested container for the same key,
// writing the same nested keys to that, dropping that container, then dropping the first container.
// The values from the first container will overwrite the ones from the second, even though that's
// not the order we wrote them in.
//
// We're going to go with approach #1 because of the edge cases in #2.

private enum EncodedJSON {
    /// An unboxed JSON value.
    ///
    /// This should always contain a primitive, with the sole exception of when the encoder is asked
    /// to encode a `JSON` directly, which it will store unboxed. If we then ask for a nested
    /// container for the same key, and the previously-stored unboxed `JSON` is an object/array, we
    /// will box it at that point.
    case unboxed(JSON)
    case object(BoxedObject)
    case array(BoxedArray)
    /// A special-case for super encoders. We need to box a value but we don't know what the type of
    /// the value is yet. If the wrapped value is `nil` when we go to unbox this, we'll just assume
    /// an empty object.
    ///
    /// - Requires: This case should never contain `Box(.super(…))`.
    case `super`(Box<EncodedJSON?>)
    
    typealias BoxedObject = Box<[String: EncodedJSON]>
    typealias BoxedArray = Box<[EncodedJSON]>
    
    class Box<Value> {
        var value: Value
        
        init(_ value: Value) {
            self.value = value
        }
    }
    
    var isObject: Bool {
        switch self {
        case .unboxed(let json): return json.isObject
        case .object: return true
        case .array: return false
        case .super(let box): return box.value?.isObject ?? false
        }
    }
    
    var isArray: Bool {
        switch self {
        case .unboxed(let json): return json.isArray
        case .object: return false
        case .array: return true
        case .super(let box): return box.value?.isArray ?? false
        }
    }
    
    func unbox() -> JSON {
        switch self {
        case .unboxed(let value): return value
        case .object(let box):
            return .object(JSONObject(dict: box.value.mapValues({ $0.unbox() })))
        case .array(let box):
            return .array(JSONArray(box.value.map({ $0.unbox() })))
        case .super(let box):
            return box.value?.unbox() ?? .object(JSONObject())
        }
    }
    
    /// Extracts the boxed object from the given json.
    ///
    /// If the json contains `.unboxed(.object)`, the object is boxed first and stored back in the json.
    /// If the json contains `nil`, it's initialized to an empty object.
    static func boxObject(json: inout EncodedJSON?) -> BoxedObject? {
        switch json {
        case nil:
            let box = BoxedObject([:])
            json = .object(box)
            return box
        case .unboxed(.object(let object))?:
            let box = BoxedObject(object.dictionary.mapValues(EncodedJSON.init(boxing:)))
            json = .object(box)
            return box
        case .unboxed?:
            return nil
        case .object(let box)?:
            return box
        case .array?:
            return nil
        case .super(let box)?:
            return boxObject(json: &box.value)
        }
    }
    
    /// Extracts the boxed array from the given json.
    ///
    /// If the json contains `.unboxed(.array)`, the array is boxed first and stored back in the json.
    /// If the json contains `nil`, it's initialized to an empty array.
    static func boxArray(json: inout EncodedJSON?) -> BoxedArray? {
        switch json {
        case nil:
            let box = BoxedArray([])
            json = .array(box)
            return box
        case .unboxed(.array(let array))?:
            let box = BoxedArray(array.map(EncodedJSON.init(boxing:)))
            json = .array(box)
            return box
        case .unboxed?, .object?:
            return nil
        case .array(let box)?:
            return box
        case .super(let box)?:
            return boxArray(json: &box.value)
        }
    }
    
    init(boxing json: JSON) {
        switch json {
        case .object(let object): self = .object(Box(object.dictionary.mapValues(EncodedJSON.init(boxing:))))
        case .array(let array): self = .array(Box(array.map(EncodedJSON.init(boxing:))))
        default: self = .unboxed(json)
        }
    }
    
    func encode<Target: TextOutputStream>(with encoder: inout JSONEventEncoder, to stream: inout Target) {
        switch self {
        case .unboxed(let json):
            JSON.encode(json, with: &encoder, to: &stream)
        case .object(let box):
            encoder.encode(.objectStart, to: &stream)
            for (key, value) in box.value {
                encoder.encode(.stringValue(key), isKey: true, to: &stream)
                value.encode(with: &encoder, to: &stream)
            }
            encoder.encode(.objectEnd, to: &stream)
        case .array(let box):
            encoder.encode(.arrayStart, to: &stream)
            for value in box.value {
                value.encode(with: &encoder, to: &stream)
            }
            encoder.encode(.arrayEnd, to: &stream)
        case .super(let box):
            if let value = box.value {
                value.encode(with: &encoder, to: &stream)
            } else {
                EncodedJSON.unboxed([:]).encode(with: &encoder, to: &stream)
            }
        }
    }
}

extension JSON {
    /// An object that encodes instances of data types that conform to `Encodable` to JSON streams.
    public struct Encoder {
        /// A dictionary you use to customize the encoding process by providing contextual information.
        public var userInfo: [CodingUserInfoKey: Any] = [:]
        
        /// The strategy to use for encoding keys. Defaults to `.useDefaultKeys`.
        public var keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys
        
        /// If `true`, apply the `keyEncodingStrategy` to the keys on any nested encoded
        /// `JSONObject`. The default value is `false`.
        ///
        /// This defaults to `false` because the assumption is if you're encoding a `JSONObject`,
        /// you want it to encode as-is.
        ///
        /// This property also affects encoding `JSON` values that contain objects.
        ///
        /// - Note: This property does not affect the encoding of `Dictionary`.
        public var applyKeyEncodingStrategyToJSONObject = false
        
        /// The strategy to use in encoding dates. Defaults to `.deferredToDate`.
        public var dateEncodingStrategy: DateEncodingStrategy = .deferredToDate
        
        /// The strategy to use in encoding binary data. Defaults to `.base64`.
        public var dataEncodingStrategy: DataEncodingStrategy = .base64
        
        /// Creates a new, reusable JSON encoder.
        public init() {}
        
        /// Returns a JSON-encoded representation of the value you supply.
        ///
        /// - Parameter value: The value to encode.
        /// - Returns: Data containing the JSON encoding of the value.
        /// - Throws: Any error thrown by a value's `encode(to:)` method.
        public func encodeAsData<T: Encodable>(_ value: T, options: JSONEncoderOptions = []) throws -> Data {
            var output = _DataOutput()
            let json = try _encodeAsEncodedJSON(value)
            var encoder = JSONEventEncoder(options: options)
            json.encode(with: &encoder, to: &output)
            return output.finish()
        }
        
        /// Returns a JSON-encoded representation of the value you supply.
        ///
        /// - Parameter value: The value to encode.
        /// - Returns: A string containing the JSON encoding of the value.
        /// - Throws: Any error thrown by a value's `encode(to:)` method.
        public func encodeAsString<T: Encodable>(_ value: T, options: JSONEncoderOptions = []) throws -> String {
            var output = ""
            let json = try _encodeAsEncodedJSON(value)
            var encoder = JSONEventEncoder(options: options)
            json.encode(with: &encoder, to: &output)
            return output
        }
        
        /// Returns a JSON-encoded representation of the value you supply.
        ///
        /// - Parameter value: The value to encode.
        /// - Returns: The JSON encoding of the value.
        /// - Throws: Any error thrown by a value's `encode(to:)` method, or
        ///   `EncodingError.invalidValue` if the value doesn't encode anything.
        public func encodeAsJSON<T: Encodable>(_ value: T) throws -> JSON {
            let json = try _encodeAsEncodedJSON(value)
            return json.unbox()
        }
        
        @available(*, unavailable, renamed: "encodeAsData(_:)")
        public func encode<T: Encodable>(_ value: T) throws -> Data {
            return try encodeAsData(value)
        }
        
        private func _encodeAsEncodedJSON<T: Encodable>(_ value: T) throws -> EncodedJSON {
            let data = EncoderData()
            data.userInfo = userInfo
            data.keyEncodingStrategy = keyEncodingStrategy
            data.applyKeyEncodingStrategyToJSONObject = applyKeyEncodingStrategyToJSONObject
            data.dateEncodingStrategy = dateEncodingStrategy
            data.dataEncodingStrategy = dataEncodingStrategy
            let encoder = _JSONEncoder(data: data)
            try encoder.encode(value)
            guard let json = encoder.json else {
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Top-level \(type(of: value)) did not encode any values."))
            }
            return json
        }
    }
}

private class EncoderData {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    var keyEncodingStrategy: JSON.Encoder.KeyEncodingStrategy = .useDefaultKeys
    var applyKeyEncodingStrategyToJSONObject = false
    var dateEncodingStrategy: JSON.Encoder.DateEncodingStrategy = .deferredToDate
    var dataEncodingStrategy: JSON.Encoder.DataEncodingStrategy = .base64
    
    var shouldRekeyJSONObjects: Bool {
        switch keyEncodingStrategy {
        case .useDefaultKeys: return false
        default: return applyKeyEncodingStrategyToJSONObject
        }
    }
    
    func copy() -> EncoderData {
        let result = EncoderData()
        result.codingPath = codingPath
        result.userInfo = userInfo
        result.keyEncodingStrategy = keyEncodingStrategy
        result.applyKeyEncodingStrategyToJSONObject = applyKeyEncodingStrategyToJSONObject
        result.dateEncodingStrategy = dateEncodingStrategy
        result.dataEncodingStrategy = dataEncodingStrategy
        return result
    }
}

private class _JSONEncoder: Encoder {
    init(data: EncoderData, json: EncodedJSON? = nil) {
        _data = data
        value = json.map(Value.json)
    }
    
    init(data: EncoderData, box: EncodedJSON.Box<EncodedJSON?>) {
        _data = data
        value = .box(box)
    }
    
    private let _data: EncoderData
    private var value: Value?
    
    private enum Value {
        case json(EncodedJSON)
        case box(EncodedJSON.Box<EncodedJSON?>)
        
        var isEmpty: Bool {
            switch self {
            case .json(.super(let box)): return box.value == nil
            case .json: return false
            case .box(let box): return box.value == nil
            }
        }
    }
    
    var json: EncodedJSON? {
        get {
            switch value {
            case .json(let json)?: return json
            case .box(let box)?: return box.value
            case nil: return nil
            }
        }
        set {
            switch value {
            case nil, .json?: value = newValue.map(Value.json)
            case .box(let box)?: box.value = newValue
            }
        }
    }
    
    var codingPath: [CodingKey] {
        return _data.codingPath
    }
    
    var userInfo: [CodingUserInfoKey: Any] {
        return _data.userInfo
    }
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        let box_: EncodedJSON.BoxedObject?
        switch value {
        case .json(let json_)?:
            var json: EncodedJSON? = json_
            box_ = EncodedJSON.boxObject(json: &json)
            if box_ != nil, let json = json {
                value = .json(json)
            }
        case .box(let box)?:
            box_ = EncodedJSON.boxObject(json: &box.value)
        case nil:
            let box = EncodedJSON.BoxedObject([:])
            value = .json(.object(box))
            box_ = box
        }
        guard let box = box_ else {
            fatalError("Attempted to create a keyed encoding container when existing encoded value is not a JSON object.")
        }
        
        return KeyedEncodingContainer(_JSONKeyedEncoder<Key>(data: _data, box: box))
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        let box_: EncodedJSON.BoxedArray?
        switch value {
        case .json(let json_)?:
            var json: EncodedJSON? = json_
            box_ = EncodedJSON.boxArray(json: &json)
            if box_ != nil, let json = json {
                value = .json(json)
            }
        case .box(let box)?:
            box_ = EncodedJSON.boxArray(json: &box.value)
        case nil:
            let box = EncodedJSON.BoxedArray([])
            value = .json(.array(box))
            box_ = box
        }
        guard let box = box_ else {
            fatalError("Attempted to create an unkeyed encoding container when existing encoded value is not a JSON array.")
        }
        
        return _JSONUnkeyedEncoder(data: _data, box: box)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
}

// MARK: -

extension _JSONEncoder: SingleValueEncodingContainer {
    private func assertCanWriteValue() {
        precondition(value?.isEmpty ?? true, "Attempted to encode value through single value container when previous value already encoded.")
    }
    
    func encodeNil() throws {
        assertCanWriteValue()
        json = .unboxed(.null)
    }
    
    func encode(_ value: Bool) throws {
        assertCanWriteValue()
        json = .unboxed(.bool(value))
    }
    
    func encode(_ value: Int) throws {
        assertCanWriteValue()
        json = .unboxed(.int64(Int64(value)))
    }
    
    func encode(_ value: Int8) throws {
        assertCanWriteValue()
        json = .unboxed(.int64(Int64(value)))
    }
    
    func encode(_ value: Int16) throws {
        assertCanWriteValue()
        json = .unboxed(.int64(Int64(value)))
    }
    
    func encode(_ value: Int32) throws {
        assertCanWriteValue()
        json = .unboxed(.int64(Int64(value)))
    }
    
    func encode(_ value: Int64) throws {
        assertCanWriteValue()
        json = .unboxed(.int64(value))
    }
    
    func encode(_ value: UInt) throws {
        assertCanWriteValue()
        guard let intValue = Int64(exactly: value) else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath, debugDescription: "Encoded value is out of range for JSON integer."))
        }
        json = .unboxed(.int64(intValue))
    }
    
    func encode(_ value: UInt8) throws {
        assertCanWriteValue()
        json = .unboxed(.int64(Int64(value)))
    }
    
    func encode(_ value: UInt16) throws {
        assertCanWriteValue()
        json = .unboxed(.int64(Int64(value)))
    }
    
    func encode(_ value: UInt32) throws {
        assertCanWriteValue()
        json = .unboxed(.int64(Int64(value)))
    }
    
    func encode(_ value: UInt64) throws {
        assertCanWriteValue()
        guard let intValue = Int64(exactly: value) else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath, debugDescription: "Encoded value is out of range for JSON integer."))
        }
        json = .unboxed(.int64(intValue))
    }
    
    func encode(_ value: Float) throws {
        assertCanWriteValue()
        json = .unboxed(.double(Double(value)))
    }
    
    func encode(_ value: Double) throws {
        assertCanWriteValue()
        json = .unboxed(.double(value))
    }
    
    func encode(_ value: String) throws {
        assertCanWriteValue()
        json = .unboxed(.string(value))
    }
    
    func encode<T>(_ value: T) throws where T : Encodable {
        assertCanWriteValue()
        switch value {
        case let json as JSON:
            switch json {
            case .object(let object) where _data.shouldRekeyJSONObjects:
                try encode(object)
            case .array(let array) where _data.shouldRekeyJSONObjects:
                try encode(Array(array))
            default:
                self.json = .unboxed(json)
            }
        case let object as JSONObject where !_data.shouldRekeyJSONObjects:
            self.json = .unboxed(.object(object))
        case let decimal as Decimal:
            json = .unboxed(.decimal(decimal))
        case let date as Date:
            switch _data.dateEncodingStrategy {
            case .deferredToDate:
                try value.encode(to: self)
            case .secondsSince1970:
                try encode(date.timeIntervalSince1970)
            case .millisecondsSince1970:
                try encode(date.timeIntervalSince1970 * 1000)
            case .iso8601:
                if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
                    let str = _iso8601Formatter.string(from: date)
                    try encode(str)
                } else {
                    fatalError("ISO8601DateFormatter is not available on this platform")
                }
            case .iso8601WithFractionalSeconds:
                #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
                    if #available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *) {
                        let str = _iso8601FractionalSecondsFormatter.string(from: date)
                        try encode(str)
                    } else {
                        fatalError("ISO8601DateFormatter.Options.withFractionalSeconds is not available on this platform")
                    }
                #else
                    fatalError("ISO8601DateFormatter.Options.withFractionalSeconds is not available on this platform")
                #endif
            case .formatted(let formatter):
                let str = formatter.string(from: date)
                try encode(str)
            case .custom(let f):
                try f(date, self)
                if self.value?.isEmpty ?? true {
                    // the function didn't encode anything
                    self.json = .unboxed([:])
                }
            }
        case let data as Data:
            switch _data.dataEncodingStrategy {
            case .deferredToData:
                try value.encode(to: self)
            case .base64:
                try encode(data.base64EncodedString())
            case .custom(let f):
                try f(data, self)
                if self.value?.isEmpty ?? true {
                    // the function didn't encode anything
                    self.json = .unboxed([:])
                }
            }
        default:
            try value.encode(to: self)
        }
    }
}

private class _JSONUnkeyedEncoder: UnkeyedEncodingContainer {
    init(data: EncoderData, box: EncodedJSON.BoxedArray) {
        _data = data
        self.box = box
    }

    private let _data: EncoderData
    private let box: EncodedJSON.BoxedArray
    
    var codingPath: [CodingKey] {
        return _data.codingPath
    }
    
    var count: Int {
        return box.value.count
    }
    
    private func append(unboxed json: JSON) {
        box.value.append(.unboxed(json))
    }
    
    func encodeNil() throws {
        append(unboxed: .null)
    }
    
    func encode(_ value: Bool) throws {
        append(unboxed: .bool(value))
    }
    
    func encode(_ value: Int8) throws {
        append(unboxed: .int64(Int64(value)))
    }
    
    func encode(_ value: Int16) throws {
        append(unboxed: .int64(Int64(value)))
    }
    
    func encode(_ value: Int32) throws {
        append(unboxed: .int64(Int64(value)))
    }
    
    func encode(_ value: Int64) throws {
        append(unboxed: .int64(value))
    }
    
    func encode(_ value: Int) throws {
        append(unboxed: .int64(Int64(value)))
    }
    
    func encode(_ value: UInt8) throws {
        append(unboxed: .int64(Int64(value)))
    }
    
    func encode(_ value: UInt16) throws {
        append(unboxed: .int64(Int64(value)))
    }
    
    func encode(_ value: UInt32) throws {
        append(unboxed: .int64(Int64(value)))
    }
    
    func encode(_ value: UInt64) throws {
        guard let intValue = Int64(exactly: value) else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath + [JSONKey.int(count)], debugDescription: "Encoded value is out of range for JSON integer."))
        }
        append(unboxed: .int64(intValue))
    }
    
    func encode(_ value: UInt) throws {
        guard let intValue = Int64(exactly: value) else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath + [JSONKey.int(count)], debugDescription: "Encoded value is out of range for JSON integer."))
        }
        append(unboxed: .int64(intValue))
    }
    
    func encode(_ value: Float) throws {
        append(unboxed: .double(Double(value)))
    }
    
    func encode(_ value: Double) throws {
        append(unboxed: .double(value))
    }
    
    func encode(_ value: String) throws {
        append(unboxed: .string(value))
    }
    
    func encode<T>(_ value: T) throws where T : Encodable {
        _data.codingPath.append(JSONKey.int(count))
        defer { _data.codingPath.removeLast() }
        let encoder = _JSONEncoder(data: _data)
        try encoder.encode(value)
        guard let json = encoder.json else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath, debugDescription: "\(type(of: value)) did not encode any values."))
        }
        box.value.append(json)
    }
    
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let data = _data.copy()
        data.codingPath.append(JSONKey.int(count))
        let box = EncodedJSON.BoxedObject([:])
        self.box.value.append(.object(box))
        return KeyedEncodingContainer(_JSONKeyedEncoder<NestedKey>(data: data, box: box))
    }
    
    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let data = _data.copy()
        data.codingPath.append(JSONKey.int(count))
        let box = EncodedJSON.BoxedArray([])
        self.box.value.append(.array(box))
        return _JSONUnkeyedEncoder(data: data, box: box)
    }
    
    func superEncoder() -> Encoder {
        let data = _data.copy()
        data.codingPath.append(JSONKey.int(count))
        let box: EncodedJSON.Box<EncodedJSON?> = EncodedJSON.Box(nil)
        self.box.value.append(.super(box))
        return _JSONEncoder(data: data, box: box)
    }
}

private class _JSONKeyedEncoder<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K
    
    init(data: EncoderData, box: EncodedJSON.BoxedObject) {
        _data = data
        self.box = box
    }
    
    private let _data: EncoderData
    private let box: EncodedJSON.BoxedObject
    
    var codingPath: [CodingKey] {
        return _data.codingPath
    }
    
    private func store(unboxed json: JSON, forKey key: K) {
        box.value[_stringKey(for: key)] = .unboxed(json)
    }
    
    func encodeNil(forKey key: K) throws {
        store(unboxed: .null, forKey: key)
    }
    
    func encode(_ value: Bool, forKey key: K) throws {
        store(unboxed: .bool(value), forKey: key)
    }
    
    func encode(_ value: Int, forKey key: K) throws {
        store(unboxed: .int64(Int64(value)), forKey: key)
    }
    
    func encode(_ value: Int8, forKey key: K) throws {
        store(unboxed: .int64(Int64(value)), forKey: key)
    }
    
    func encode(_ value: Int16, forKey key: K) throws {
        store(unboxed: .int64(Int64(value)), forKey: key)
    }
    
    func encode(_ value: Int32, forKey key: K) throws {
        store(unboxed: .int64(Int64(value)), forKey: key)
    }
    
    func encode(_ value: Int64, forKey key: K) throws {
        store(unboxed: .int64(value), forKey: key)
    }
    
    func encode(_ value: UInt8, forKey key: K) throws {
        store(unboxed: .int64(Int64(value)), forKey: key)
    }
    
    func encode(_ value: UInt16, forKey key: K) throws {
        store(unboxed: .int64(Int64(value)), forKey: key)
    }
    
    func encode(_ value: UInt32, forKey key: K) throws {
        store(unboxed: .int64(Int64(value)), forKey: key)
    }
    
    func encode(_ value: UInt64, forKey key: K) throws {
        guard let intValue = Int64(exactly: value) else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath + [key], debugDescription: "Encoded value is out of range for JSON integer."))
        }
        store(unboxed: .int64(intValue), forKey: key)
    }
    
    func encode(_ value: UInt, forKey key: K) throws {
        guard let intValue = Int64(exactly: value) else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath + [key], debugDescription: "Encoded value is out of range for JSON integer."))
        }
        store(unboxed: .int64(intValue), forKey: key)
    }
    
    func encode(_ value: Float, forKey key: K) throws {
        store(unboxed: .double(Double(value)), forKey: key)
    }
    
    func encode(_ value: Double, forKey key: K) throws {
        store(unboxed: .double(value), forKey: key)
    }
    
    func encode(_ value: String, forKey key: K) throws {
        store(unboxed: .string(value), forKey: key)
    }
    
    func encode<T>(_ value: T, forKey key: K) throws where T : Encodable {
        _data.codingPath.append(key)
        defer { _data.codingPath.removeLast() }
        let encoder = _JSONEncoder(data: _data)
        try encoder.encode(value)
        guard let json = encoder.json else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: codingPath, debugDescription: "\(type(of: value)) did not encode any values."))
        }
        box.value[_stringKey(for: key)] = json
    }
    
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let data = _data.copy()
        data.codingPath.append(key)
        let box = EncodedJSON.BoxedObject([:])
        self.box.value[_stringKey(for: key)] = .object(box)
        return KeyedEncodingContainer(_JSONKeyedEncoder<NestedKey>(data: data, box: box))
    }
    
    func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        let data = _data.copy()
        data.codingPath.append(key)
        let box = EncodedJSON.BoxedArray([])
        self.box.value[_stringKey(for: key)] = .array(box)
        return _JSONUnkeyedEncoder(data: data, box: box)
    }
    
    func superEncoder() -> Encoder {
        return _superEncoder(forKey: JSONKey.super)
    }
    
    func superEncoder(forKey key: K) -> Encoder {
        return _superEncoder(forKey: key)
    }
    
    private func _superEncoder(forKey key: CodingKey) -> Encoder {
        let data = _data.copy()
        data.codingPath.append(key)
        let box: EncodedJSON.Box<EncodedJSON?> = EncodedJSON.Box(nil)
        self.box.value[_stringKey(for: key)] = .super(box)
        return _JSONEncoder(data: data, box: box)
    }
    
    private func _stringKey(for key: CodingKey) -> String {
        switch _data.keyEncodingStrategy {
        case .useDefaultKeys:
            return key.stringValue
        case .convertToSnakeCase:
            return JSON.Encoder.KeyEncodingStrategy._convertToSnakeCase(key.stringValue)
        case .custom(let f):
            return f(_data.codingPath, key).stringValue
        }
    }
}

// MARK: -

extension JSON.Encoder {
    /// The strategy to use for automatically changing the keys before encoding.
    public enum KeyEncodingStrategy {
        /// Use the keys specified by each type. This is the default strategy.
        case useDefaultKeys
        
        /// Convert from "camelCaseKeys" to "snake_case_keys" before writing the JSON payload.
        ///
        /// Capital letters are determined by testing membership in `CharacterSet.uppercaseLetters`
        /// and `CharacterSet.lowercaseLetters`. The conversion to lowercase uses the ICU "root"
        /// locale (meaning the conversion is not affected by the current locale).
        ///
        /// Converting from camelCase to snake_case:
        /// 1. Splits words at the boundary between lowercase and uppercase.
        /// 2. Treats acronyms as a single word.
        /// 3. Inserts `_` between words.
        /// 4. Lowercases the entire string.
        ///
        /// For example, `oneTwoThree` becomes `one_two_three` and `URLForConfig` becomes
        /// `url_for_config`.
        ///
        /// - Note: Using this key encoding strategy incurs a minor performance impact.
        case convertToSnakeCase
        
        /// Provide a custom conversion from the key specified by the encoded type to the key used
        /// in the encoded JSON. The first parameter is the full path leading up to the current key,
        /// which can provide context for the conversion, and the second parameter is the key
        /// itself, which will be replaced by the return value from the function.
        ///
        /// - Note: If the result of the conversion is a duplicate key, only one value will be
        ///   present in the result.
        case custom((_ codingPath: [CodingKey], _ key: CodingKey) -> CodingKey)
        
        fileprivate static func _convertToSnakeCase(_ key: String) -> String {
            guard !key.isEmpty else { return key }
            
            let scalars = key.unicodeScalars
            
            enum State {
                case lowercase
                case uppercase
            }
            var state: State
            switch scalars.first {
            case nil: return key
            case let c? where CharacterSet.uppercaseLetters.contains(c):
                state = .uppercase
            case _?:
                state = .lowercase
            }
            
            // NB: Always call lowercased() because there are some characters outside of
            // CharacterSet.uppercaseLetters that are affected by it.
            
            var result: String = ""
            var lastIdx = key.startIndex
            // NB: We walk the character indices instead of the scalar indices so that way we ignore
            // combining marks.
            var idxIter = key.indices.makeIterator()
            _ = idxIter.next() // skip the first character
            loop: repeat {
                switch state {
                case .lowercase:
                    while let idx = idxIter.next() {
                        if CharacterSet.uppercaseLetters.contains(scalars[idx]) {
                            state = .uppercase
                            result.append(key[lastIdx..<idx].lowercased())
                            lastIdx = idx
                            result.append("_")
                            continue loop
                        }
                    }
                    break loop
                case .uppercase:
                    guard let idx = idxIter.next() else { break loop }
                    if CharacterSet.lowercaseLetters.contains(scalars[idx]) {
                        state = .lowercase
                        // lastIdx is pointing at the uppercase letter so it's already correct
                        continue loop
                    }
                    var prevIdx = idx
                    while let idx = idxIter.next() {
                        if CharacterSet.lowercaseLetters.contains(scalars[idx]) {
                            state = .lowercase
                            if !CharacterSet.uppercaseLetters.contains(scalars[prevIdx]) {
                                // This catches keys like "ABC123def", where the first 'word' ends
                                // in a non-capital.
                                prevIdx = idx
                            }
                            result.append(key[lastIdx..<prevIdx].lowercased())
                            lastIdx = prevIdx
                            result.append("_")
                            continue loop
                        }
                        prevIdx = idx
                    }
                    break loop
                }
            } while true
            result.append(key[lastIdx...].lowercased())
            return result
        }
    }
    
    /// The strategy to use for encoding `Date` values.
    public enum DateEncodingStrategy {
        /// Defer to `Date` for choosing an encoding. This is the default strategy.
        case deferredToDate
        
        /// Encode the `Date` as a UNIX timestamp (as a JSON number).
        case secondsSince1970
        
        /// Encode the `Date` as UNIX millisecond timestamp (as a JSON number).
        case millisecondsSince1970
        
        /// Encode the `Date` as an ISO8601-formatted string (in RFC 3339 format).
        ///
        /// This encodes strings like `"1985-04-12T23:20:50Z"`.
        ///
        /// - Note: This does not include fractional seconds. Use `.iso8601WithFractionalSeconds`
        ///   for that.
        @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
        case iso8601
        
        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        /// Encode the `Date` as an ISO8601-formatted string (in RFC 3339 format) with fractional
        /// seconds.
        ///
        /// This encodes strings like `"1985-04-12T23:20:50.523Z"`.
        @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
        case iso8601WithFractionalSeconds
        #else
        // swift-corelibs-foundation doesn't support `.withFractionalSeconds`. We still declare the
        // case though or we're in trouble trying to match it.
        /// Encode the `Date` as an ISO8601-formatted string (in RFC 3339 format) with fractional
        /// seconds.
        ///
        /// This encodes strings like `"1985-04-12T23:20:50.523Z"`.
        ///
        /// - Important: This case is not supported on non-Apple platforms.
        @available(*, unavailable, message: "This case is not supported on non-Apple platforms")
        case iso8601WithFractionalSeconds
        #endif
        
        /// Encode the `Date` as a string formatted by the given formatter.
        case formatted(DateFormatter)
        
        /// Encode the `Date` as a custom value encoded by the given closure.
        ///
        /// If the closure fails to encode a value into the given encoder, the encoder will encode
        /// an empty object in its place.
        case custom((Date, Encoder) throws -> Void)
    }
    
    /// The strategy to use for encoding `Data` values.
    public enum DataEncodingStrategy {
        /// Defer to `Data` for choosing an encoding.
        case deferredToData
        
        /// Encode the `Data` as a Base64-encoded string. This is the default strategy.
        case base64
        
        /// Encode the `Data` as a custom value encoded by the given closure.
        ///
        /// If the closure fails to encode a value into the given encoder, the encoder will encode
        /// an empty object in its place.
        case custom((_ data: Data, _ encoder: Encoder) throws -> Void)
    }
}

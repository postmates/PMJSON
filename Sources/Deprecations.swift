//
//  Deprecations.swift
//  PMJSON
//
//  Created by Lily Ballard on 11/13/19.
//  Copyright © 2019 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

public extension JSON {
    /// Returns an `Array` containing the non-`nil` results of mapping `transform` over `array`.
    ///
    /// If `transform` throws a `JSONError`, the error will be modified to include the index
    /// of the element that caused the error.
    ///
    /// - Parameter array: The `JSONArray` to map over.
    /// - Parameter transform: A block that is called once for each element of `array`.
    /// - Returns: An array with the non-`nil` results of mapping `transform` over `array`.
    /// - Throws: Rethrows any error thrown by `transform`.
    /// - Complexity: O(*N*).
    @available(*, deprecated, renamed: "compactMap")
    static func flatMap<T>(_ array: JSONArray, _ transform: (JSON) throws -> T?) rethrows -> [T] {
        return try compactMap(array, transform)
    }
    
    /// Subscripts the receiver with `key`, converts the value to an array, and returns an `Array`
    /// containing the non-`nil` results of mapping `transform` over the value.
    ///
    /// - Note: This method is equivalent to `getArray(key, { try JSON.compactMap($0, transform) })`.
    ///
    /// - Parameter key: The key to subscript the receiver with.
    /// - Parameter transform: A block that is called once for each element of the resulting array.
    /// - Returns: An array with the non-`nil` results of mapping `transform` over the array.
    /// - Throws: `JSONError` if the receiver is not an object, `key` does not exist, or the value
    ///   is not an array. Also rethrows any error thrown by `transform`.
    /// - Complexity: O(*N*).
    @available(*, deprecated, renamed: "compactMapArray")
    func flatMapArray<T>(_ key: String, _ transform: (JSON) throws -> T?) throws -> [T] {
        return try compactMapArray(key, transform)
    }
    
    /// Subscripts the receiver with `index`, converts the value to an array, and returns an `Array`
    /// containing the non-`nil` results of mapping `transform` over the value.
    ///
    /// - Note: This method is equivalent to `getArray(index, { try JSON.compactMap($0, transform) })`.
    ///
    /// - Parameter index: The index to subscript the receiver with.
    /// - Parameter transform: A block that is called once for each element of the resulting array.
    /// - Returns: An array with the non-`nil` results of mapping `transform` over the array.
    /// - Throws: `JSONError` if the receiver is not an array, `index` is out of bounds, or the
    ///   value is not an array. Also rethrows any error thrown by `transform`.
    /// - Complexity: O(*N*).
    @available(*, deprecated, renamed: "compactMapArray")
    func flatMapArray<T>(_ index: Int, _ transform: (JSON) throws -> T?) throws -> [T] {
        return try compactMapArray(index, transform)
    }
    
    /// Subscripts the receiver with `key`, converts the value to an array, and returns an `Array`
    /// containing the non-`nil` results of mapping `transform` over the value.
    ///
    /// Returns `nil` if `key` doesn't exist or the value is `null`.
    ///
    /// - Note: This method is equivalent to `getArrayOrNil(key, { try JSON.compactMap($0, transform) })`.
    ///
    /// - Parameter key: The key to subscript the receiver with.
    /// - Parameter transform: A block that is called once for each element of the resulting array.
    /// - Returns: An array with the non-`nil` results of mapping `transform` over the array, or
    ///   `nil` if `key` does not exist or the value is `null`.
    /// - Throws: `JSONError` if the receiver is not an object or the value is not an array or
    ///   `null`. Also rethrows any error thrown by `transform`.
    /// - Complexity: O(*N*).
    @available(*, deprecated, renamed: "compactMapArrayOrNil")
    func flatMapArrayOrNil<T>(_ key: String, _ transform: (JSON) throws -> T?) throws -> [T]? {
        return try compactMapArrayOrNil(key, transform)
    }
    
    /// Subscripts the receiver with `index`, converts the value to an array, and returns an `Array`
    /// containing the non-`nil` results of mapping `transform` over the value.
    ///
    /// Returns `nil` if `index` is out of bounds or the value is `null`.
    ///
    /// - Note: This method is equivalent to `getArrayOrNil(index, { try JSON.compactMap($0, transform) })`.
    ///
    /// - Parameter index: The index to subscript the receiver with.
    /// - Parameter transform: A block that is called once for each element of the resulting array.
    /// - Returns: An array with the non-`nil` results of mapping `transform` over the array, or
    ///   `nil` if `index` is out of bounds or the value is `null`.
    /// - Throws: `JSONError` if the receiver is not an array or the value is not an array or
    ///   `null`. Also rethrows any error thrown by `transform`.
    /// - Complexity: O(*N*).
    @available(*, deprecated, renamed: "compactMapArrayOrNil")
    func flatMapArrayOrNil<T>(_ index: Int, _ transform: (JSON) throws -> T?) throws -> [T]? {
        return try compactMapArrayOrNil(index, transform)
    }
}

public extension JSONObject {
    /// Subscripts the receiver with `key`, converts the value to an array, and returns an `Array`
    /// containing the non-`nil` results of mapping `transform` over the value.
    ///
    /// - Note: This method is equivalent to `getArray(key, { try JSON.compactMap($0, transform) })`.
    ///
    /// - Parameter key: The key to subscript the receiver with.
    /// - Parameter transform: A block that is called once for each element of the resulting array.
    /// - Returns: An array with the non-`nil` results of mapping `transform` over the array.
    /// - Throws: `JSONError` if `key` does not exist or the value is not an array.
    ///   Also rethrows any error thrown by `transform`.
    /// - Complexity: O(*N*).
    @available(*, deprecated, renamed: "compactMapArray")
    func flatMapArray<T>(_ key: String, _ transform: (JSON) throws -> T?) throws -> [T] {
        return try compactMapArray(key, transform)
    }
    
    /// Subscripts the receiver with `key`, converts the value to an array, and returns an `Array`
    /// containing the non-`nil` results of mapping `transform` over the value.
    ///
    /// Returns `nil` if `key` doesn't exist or the value is `null`.
    ///
    /// - Note: This method is equivalent to `getArrayOrNil(key, { try JSON.compactMap($0, transform) })`.
    ///
    /// - Parameter key: The key to subscript the receiver with.
    /// - Parameter transform: A block that is called once for each element of the resulting array.
    /// - Returns: An array with the non-`nil` results of mapping `transform` over the array, or
    ///   `nil` if `key` does not exist or the value is `null`.
    /// - Throws: `JSONError` if `key` exists but the value is not an array or `null`.
    ///   Also rethrows any error thrown by `transform`.
    /// - Complexity: O(*N*).
    @available(*, deprecated, renamed: "compactMapArrayOrNil")
    func flatMapArrayOrNil<T>(_ key: String, _ transform: (JSON) throws -> T?) throws -> [T]? {
        return try compactMapArrayOrNil(key, transform)
    }
}

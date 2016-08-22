//
//  Decoder.swift
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

extension JSON {
    /// Decodes a string as JSON.
    /// - parameters:
    ///   - strict: If `true`, trailing commas in arrays/objects are treated as an error.
    /// - throws: `JSONParserError`
    public static func decode(_ string: String, strict: Bool = false) throws -> JSON {
        var parser = JSONParser(string.unicodeScalars)
        parser.strict = strict
        var decoder = JSONDecoder(parser)
        return try decoder.decode()
    }
    
    /// Decodes a sequence of `UnicodeScalar`s as JSON.
    /// - parameters:
    ///   - strict: If `true`, trailing commas in arrays/objects are treated as an error.
    /// - throws: `JSONParserError`
    public static func decode<Seq: Sequence>(_ scalars: Seq, strict: Bool = false) throws -> JSON where Seq.Iterator.Element == UnicodeScalar {
        var parser = JSONParser(scalars)
        parser.strict = strict
        var decoder = JSONDecoder(parser)
        return try decoder.decode()
    }
}

/// A JSON decoder.
private struct JSONDecoder<Seq: Sequence> where Seq.Iterator: JSONEventGenerator, Seq.Iterator.Element == JSONEvent {
    init(_ parser: Seq) {
        gen = parser.makeIterator()
    }
    
    mutating func decode() throws -> JSON {
        bump()
        let result = try buildValue()
        bump()
        switch token {
        case .none: break
        case .some(.error(let err)): throw err
        case .some(let token): fatalError("unexpected token: \(token)")
        }
        return result
    }
    
    private mutating func bump() {
        token = gen.next()
    }
    
    private mutating func buildValue() throws -> JSON {
        switch token {
        case .objectStart?: return try buildObject()
        case .objectEnd?: throw error(.invalidSyntax)
        case .arrayStart?: return try buildArray()
        case .arrayEnd?: throw error(.invalidSyntax)
        case .booleanValue(let b)?: return .bool(b)
        case .int64Value(let i)?: return .int64(i)
        case .doubleValue(let d)?: return .double(d)
        case .stringValue(let s)?: return .string(s)
        case .nullValue?: return .null
        case .error(let err)?: throw err
        case nil: throw error(.unexpectedEOF)
        }
    }
    
    private mutating func buildObject() throws -> JSON {
        bump()
        var dict: [String: JSON] = Dictionary(minimumCapacity: objectHighWaterMark)
        defer { objectHighWaterMark = max(objectHighWaterMark, dict.count) }
        while let token = self.token {
            let key: String
            switch token {
            case .objectEnd: return .object(JSONObject(dict))
            case .error(let err): throw err
            case .stringValue(let s): key = s
            default: throw error(.nonStringKey)
            }
            bump()
            dict[key] = try buildValue()
            bump()
        }
        throw error(.unexpectedEOF)
    }
    
    private mutating func buildArray() throws -> JSON {
        bump()
        var ary: JSONArray = []
        while let token = self.token {
            if case .arrayEnd = token {
                return .array(ary)
            }
            ary.append(try buildValue())
            bump()
        }
        throw error(.unexpectedEOF)
    }
    
    private func error(_ code: JSONParserError.Code) -> JSONParserError {
        return JSONParserError(code: code, line: gen.line, column: gen.column)
    }
    
    private var gen: Seq.Iterator
    private var token: JSONEvent?
    private var objectHighWaterMark: Int = 0
}

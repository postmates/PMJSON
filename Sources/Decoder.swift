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
    public static func decode(string: Swift.String, strict: Swift.Bool = false) throws -> JSON {
        var parser = JSONParser(string.unicodeScalars)
        parser.strict = strict
        var decoder = JSONDecoder(parser)
        return try decoder.decode()
    }
    
    /// Decodes a sequence of `UnicodeScalar`s as JSON.
    /// - parameters:
    ///   - strict: If `true`, trailing commas in arrays/objects are treated as an error.
    /// - throws: `JSONParserError`
    public static func decode<Seq: SequenceType where Seq.Generator.Element == UnicodeScalar>(scalars: Seq, strict: Swift.Bool = false) throws -> JSON {
        var parser = JSONParser(scalars)
        parser.strict = strict
        var decoder = JSONDecoder(parser)
        return try decoder.decode()
    }
}

/// A JSON decoder.
private struct JSONDecoder<Seq: SequenceType where Seq.Generator: JSONEventGenerator, Seq.Generator.Element == JSONEvent> {
    init(_ parser: Seq) {
        gen = parser.generate()
    }
    
    mutating func decode() throws -> JSON {
        bump()
        let result = try buildValue()
        bump()
        switch token {
        case .None: break
        case .Some(.Error(let err)): throw err
        case .Some(let token): fatalError("unexpected token: \(token)")
        }
        return result
    }
    
    private mutating func bump() {
        token = gen.next()
    }
    
    private mutating func buildValue() throws -> JSON {
        switch token {
        case .ObjectStart?: return try buildObject()
        case .ObjectEnd?: throw error(.InvalidSyntax)
        case .ArrayStart?: return try buildArray()
        case .ArrayEnd?: throw error(.InvalidSyntax)
        case .BooleanValue(let b)?: return .Bool(b)
        case .Int64Value(let i)?: return .Int64(i)
        case .DoubleValue(let d)?: return .Double(d)
        case .StringValue(let s)?: return .String(s)
        case .NullValue?: return .Null
        case .Error(let err)?: throw err
        case nil: throw error(.UnexpectedEOF)
        }
    }
    
    private mutating func buildObject() throws -> JSON {
        bump()
        var dict: [String: JSON] = Dictionary(minimumCapacity: objectHighWaterMark)
        defer { objectHighWaterMark = max(objectHighWaterMark, dict.count) }
        while let token = self.token {
            let key: String
            switch token {
            case .ObjectEnd: return .Object(JSONObject(dict))
            case .Error(let err): throw err
            case .StringValue(let s): key = s
            default: throw error(.NonStringKey)
            }
            bump()
            dict[key] = try buildValue()
            bump()
        }
        throw error(.UnexpectedEOF)
    }
    
    private mutating func buildArray() throws -> JSON {
        bump()
        var ary: JSONArray = []
        while let token = self.token {
            if case .ArrayEnd = token {
                return .Array(ary)
            }
            ary.append(try buildValue())
            bump()
        }
        throw error(.UnexpectedEOF)
    }
    
    private func error(code: JSONParserError.Code) -> JSONParserError {
        return JSONParserError(code: code, line: gen.line, column: gen.column)
    }
    
    private var gen: Seq.Generator
    private var token: JSONEvent?
    private var objectHighWaterMark: Int = 0
}

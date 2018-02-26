//
//  Codable.swift
//  PMJSON
//
//  Created by Kevin Ballard on 2/15/18.
//  Copyright © 2018 Kevin Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import struct Foundation.Decimal

extension JSON: Codable {
    public init(from decoder: Swift.Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Bool.self) {
            // NB: We must attempt to decode booleans before numbers because JSONDecoder will
            // convert booleans into numbers (but not vice versa).
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            if value.rounded(.down) == value,
                let intValue = try? container.decode(Int64.self) {
                self = .int64(intValue)
            } else {
                self = .double(value)
            }
        } else if let value = try? container.decode(Int64.self) {
            self = .int64(value)
        } else if let value = try? container.decode(JSONObject.self) {
            self = .object(value)
        } else if let value = try? container.decode([JSON].self) {
            self = .array(JSONArray(value))
        } else if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Decimal.self) {
            self = .decimal(value)
        } else {
            throw DecodingError.typeMismatch(JSON.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not decode value of type JSON"))
        }
    }
    
    public func encode(to encoder: Swift.Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .int64(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .decimal(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(Array(value))
        }
    }
}

extension JSONObject: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: JSON].self)
        self.init(dict)
    }
    
    public func encode(to encoder: Encoder) throws {
        try dictionary.encode(to: encoder)
    }
}

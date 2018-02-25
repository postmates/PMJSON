//
//  Encoder.swift
//  PMJSON
//
//  Created by Kevin Ballard on 2/1/16.
//  Copyright © 2016 Postmates.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

import struct Foundation.Decimal

extension JSON {
    /// Encodes a `JSON` to a `String`.
    /// - Parameter json: The `JSON` to encode.
    /// - Parameters options: Options that controls JSON encoding. Defaults to no options. See `JSONEncoderOptions` for details.
    /// - Returns: A `String` with the JSON representation of *json*.
    public static func encodeAsString(_ json: JSON, options: JSONEncoderOptions = []) -> String {
        var s = ""
        encode(json, to: &s, options: options)
        return s
    }
    
    @available(*, deprecated, message: "Use JSON.encodeAsString(_:options:) instead")
    public static func encodeAsString(_ json: JSON, pretty: Bool) -> String {
        return encodeAsString(json, options: JSONEncoderOptions(pretty: pretty))
    }
    
    /// Encodes a `JSON` to an output stream.
    /// - Parameter json: The `JSON` to encode.
    /// - Parameter stream: The output stream to write the encoded JSON to.
    /// - Parameters options: Options that controls JSON encoding. Defaults to no options. See `JSONEncoderOptions` for details.
    public static func encode<Target: TextOutputStream>(_ json: JSON, to stream: inout Target, options: JSONEncoderOptions = []) {
        var encoder = JSONEventEncoder(options: options)
        encode(json, with: &encoder, to: &stream)
    }
    
    @available(*, deprecated, message: "Use JSON.encode(_:to:options:) instead")
    public static func encode<Target: TextOutputStream>(_ json: JSON, to stream: inout Target, pretty: Bool) {
        encode(json, to: &stream, options: JSONEncoderOptions(pretty: pretty))
    }
    
    @available(*, deprecated, renamed: "encode(_:to:pretty:)")
    public static func encode<Target: TextOutputStream>(_ json: JSON, toStream stream: inout Target, pretty: Bool) {
        encode(json, to: &stream, options: JSONEncoderOptions(pretty: pretty))
    }
    
    internal static func encode<Target: TextOutputStream>(_ json: JSON, with encoder: inout JSONEventEncoder, to stream: inout Target) {
        switch json {
        case .null: encoder.encode(.nullValue, to: &stream)
        case .bool(let b): encoder.encode(.booleanValue(b), to: &stream)
        case .int64(let i): encoder.encode(.int64Value(i), to: &stream)
        case .double(let d): encoder.encode(.doubleValue(d), to: &stream)
        case .decimal(let d): encoder.encode(.decimalValue(d), to: &stream)
        case .string(let s): encoder.encode(.stringValue(s), to: &stream)
        case .object(let obj):
            encoder.encode(.objectStart, to: &stream)
            for (key, value) in obj {
                encoder.encode(.stringValue(key), isKey: true, to: &stream)
                encode(value, with: &encoder, to: &stream)
            }
            encoder.encode(.objectEnd, to: &stream)
        case .array(let ary):
            encoder.encode(.arrayStart, to: &stream)
            for value in ary {
                encode(value, with: &encoder, to: &stream)
            }
            encoder.encode(.arrayEnd, to: &stream)
        }
    }
}

public struct JSONEncoderOptions {
    /// If `true`, the output is formatted with whitespace to be easier to read.
    /// If `false`, the output omits any unnecessary whitespace.
    ///
    /// The default value is `false`.
    public var pretty: Bool = false
    
    /// Returns a new `JSONEncoderOptions` with default values.
    public init() {}
    
    /// Returns a new `JSONEncoderOptions`.
    /// - Parameter pretty: Whether the output should be formatted nicely. Defaults to `false`.
    public init(pretty: Bool = false) {
        self.pretty = pretty
    }
}

extension JSONEncoderOptions: ExpressibleByArrayLiteral {
    public enum Element {
        /// Formats the output with whitespace to be easier to read.
        /// - SeeAlso: `JSONEncoderOptions.pretty`.
        case pretty
    }
    
    public init(arrayLiteral elements: Element...) {
        for elt in elements {
            switch elt {
            case .pretty: pretty = true
            }
        }
    }
}

/// A struct that encode a series of `JSONEvent`s to an output stream.
///
/// - Warning: The `JSONEvent` sequence must describe a single JSON value. Passing an invalid
///   sequence of events to this struct will result in invalid JSON output.
///
/// - Note: This struct ignores the `.error` event.
internal struct JSONEventEncoder {
    private var firstElement = true
    private var isObjectValue = false
    /// The indent level. `nil` means pretty output is disabled.
    private var indent: Int?
    
    init(options: JSONEncoderOptions) {
        indent = options.pretty ? 0 : nil
    }
    
    // Note: The isKey parameter is a pretty big hack, but it avoids the need for this type to have
    // a dynamically-growing array just to track whether it's in an object or not.
    
    /// - Parameter event: The `JSONEvent` to encode.
    /// - Parameter isKey: `true` if this event represents a key in an object.
    /// - Parameter output: The output to write the JSON to.
    mutating func encode<Target: TextOutputStream>(_ event: JSONEvent, isKey: Bool = false, to output: inout Target) {
        // If we write two sibling values, assume we're in a collection, because otherwise we'd be
        // dealing with invalid JSON.
        
        switch event {
        case .objectEnd, .arrayEnd:
            if let indent = indent {
                self.indent = indent - 1
                if !firstElement { // empty arrays/objects should be compact
                    writeIndentedLine(to: &output)
                }
            }
        case .error:
            break
        default:
            if isObjectValue {
                if indent != nil {
                    output.write(": ")
                } else {
                    output.write(":")
                }
            } else {
                if !firstElement {
                    output.write(",")
                }
                if indent ?? 0 > 0 {
                    writeIndentedLine(to: &output)
                }
            }
        }
        isObjectValue = isKey
        firstElement = false
        switch event {
        case .objectStart:
            output.write("{")
            firstElement = true
            indent = indent.map({ $0 + 1 })
        case .objectEnd:
            output.write("}")
        case .arrayStart:
            output.write("[")
            firstElement = true
            indent = indent.map({ $0 + 1 })
        case .arrayEnd:
            output.write("]")
        case .booleanValue(let value):
            output.write(value ? "true" : "false")
        case .int64Value(let value):
            output.write(String(value))
        case .doubleValue(let value):
            output.write(String(value))
        case .decimalValue(let value):
            output.write(String(describing: value))
        case .stringValue(let value):
            encodeString(value, to: &output)
        case .nullValue:
            output.write("null")
        case .error:
            break
        }
    }
    
    private mutating func encodeString<Target: TextOutputStream>(_ value: String, to output: inout Target) {
        output.write("\"")
        let scalars = value.unicodeScalars
        var start = scalars.startIndex
        let end = scalars.endIndex
        var idx = start
        while idx < scalars.endIndex {
            let s: String
            let c = scalars[idx]
            switch c {
            case "\\": s = "\\\\"
            case "\"": s = "\\\""
            case "\n": s = "\\n"
            case "\r": s = "\\r"
            case "\t": s = "\\t"
            case "\u{8}": s = "\\b"
            case "\u{C}": s = "\\f"
            case "\0"..<"\u{10}":
                s = "\\u000\(String(c.value, radix: 16, uppercase: true))"
            case "\u{10}"..<" ":
                s = "\\u00\(String(c.value, radix: 16, uppercase: true))"
            default:
                idx = scalars.index(after: idx)
                continue
            }
            if idx != start {
                output.write(String(scalars[start..<idx]))
            }
            output.write(s)
            idx = scalars.index(after: idx)
            start = idx
        }
        if start != end {
            String(scalars[start..<end]).write(to: &output)
        }
        output.write("\"")
    }
    
    private mutating func writeIndentedLine<Target: TextOutputStream>(to output: inout Target) {
        guard let indent = indent else { return }
        switch indent % 4 {
        case 0: output.write("\n")
        case 1: output.write("\n  ")
        case 2: output.write("\n    ")
        case 3: output.write("\n      ")
        default: break
        }
        for _ in stride(from: 4, through: indent, by: 4) {
            output.write("        ")
        }
    }
}

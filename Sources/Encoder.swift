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

extension JSON {
    /// Encodes a `JSON` to a `String`.
    /// - Parameter json: The `JSON` to encode.
    /// - Parameter pretty: If `true`, include extra whitespace for formatting. Default is `false`.
    /// - Returns: A `String` with the JSON representation of *json*.
    public static func encodeAsString(json: JSON, pretty: Swift.Bool = false) -> Swift.String {
        var s = ""
        encode(json, toStream: &s, pretty: pretty)
        return s
    }
    
    /// Encodes a `JSON` to an output stream.
    /// - Parameter json: The `JSON` to encode.
    /// - Parameter stream: The output stream to write the encoded JSON to.
    /// - Parameter pretty: If `true`, include extra whitespace for formatting. Default is `false`.
    public static func encode<Target: OutputStreamType>(json: JSON, inout toStream stream: Target, pretty: Swift.Bool = false) {
        encode(json, toStream: &stream, indent: pretty ? 0 : nil)
    }
    
    private static func encode<Target: OutputStreamType>(json: JSON, inout toStream stream: Target, indent: Int?) {
        switch json {
        case .Null: encodeNull(&stream)
        case .Bool(let b): encodeBool(b, toStream: &stream)
        case .Int64(let i): encodeInt64(i, toStream: &stream)
        case .Double(let d): encodeDouble(d, toStream: &stream)
        case .String(let s): encodeString(s, toStream: &stream)
        case .Object(let obj): encodeObject(obj, toStream: &stream, indent: indent)
        case .Array(let ary): encodeArray(ary, toStream: &stream, indent: indent)
        }
    }
    
    private static func encodeNull<Target: OutputStreamType>(inout stream: Target) {
        stream.write("null")
    }
    
    private static func encodeBool<Target: OutputStreamType>(value: Swift.Bool, inout toStream stream: Target) {
        stream.write(value ? "true" : "false")
    }
    
    private static func encodeInt64<Target: OutputStreamType>(value: Swift.Int64, inout toStream stream: Target) {
        stream.write(Swift.String(value))
    }
    
    private static func encodeDouble<Target: OutputStreamType>(value: Swift.Double, inout toStream stream: Target) {
        stream.write(Swift.String(value))
    }
    
    private static func encodeString<Target: OutputStreamType>(value: Swift.String, inout toStream stream: Target) {
        stream.write("\"")
        let scalars = value.unicodeScalars
        var start = scalars.startIndex
        let end = scalars.endIndex
        var idx = start
        while idx < scalars.endIndex {
            let s: Swift.String
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
                s = "\\u000\(Swift.String(c.value, radix: 16, uppercase: true))"
            case "\u{10}"..<" ":
                s = "\\u00\(Swift.String(c.value, radix: 16, uppercase: true))"
            default:
                idx = idx.successor()
                continue
            }
            if idx != start {
                stream.write(Swift.String(scalars[start..<idx]))
            }
            stream.write(s)
            idx = idx.successor()
            start = idx
        }
        if start != end {
            Swift.String(scalars[start..<end]).writeTo(&stream)
        }
        stream.write("\"")
    }
    
    private static func encodeObject<Target: OutputStreamType>(object: JSONObject, inout toStream stream: Target, indent: Int?) {
        let indented = indent.map({$0+1})
        if let indent = indented {
            stream.write("{\n")
            writeIndent(indent, toStream: &stream)
        } else {
            stream.write("{")
        }
        var first = true
        for (key, value) in object {
            if first {
                first = false
            } else if let indent = indented {
                stream.write(",\n")
                writeIndent(indent, toStream: &stream)
            } else {
                stream.write(",")
            }
            encodeString(key, toStream: &stream)
            stream.write(indented != nil ? ": " : ":")
            encode(value, toStream: &stream, indent: indented)
        }
        if let indent = indent {
            stream.write("\n")
            writeIndent(indent, toStream: &stream)
        }
        stream.write("}")
    }
    
    private static func encodeArray<Target: OutputStreamType>(array: JSONArray, inout toStream stream: Target, indent: Int?) {
        let indented = indent.map({$0+1})
        if let indent = indented {
            stream.write("[\n")
            writeIndent(indent, toStream: &stream)
        } else {
            stream.write("[")
        }
        var first = true
        for elt in array {
            if first {
                first = false
            } else if let indent = indented {
                stream.write(",\n")
                writeIndent(indent, toStream: &stream)
            } else {
                stream.write(",")
            }
            encode(elt, toStream: &stream, indent: indented)
        }
        if let indent = indent {
            stream.write("\n")
            writeIndent(indent, toStream: &stream)
        }
        stream.write("]")
    }
    
    private static func writeIndent<Target: OutputStreamType>(indent: Int, inout toStream stream: Target) {
        for _ in 4.stride(through: indent, by: 4) {
            stream.write("        ")
        }
        switch indent % 4 {
        case 1: stream.write("  ")
        case 2: stream.write("    ")
        case 3: stream.write("      ")
        default: break
        }
    }
}

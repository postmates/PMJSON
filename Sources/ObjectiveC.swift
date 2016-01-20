//
//  ObjectiveC.swift
//  PMJSON
//
//  Created by Kevin Ballard on 10/9/15.
//

import Foundation

extension JSON {
    /// Decodes an `NSData` as JSON.
    /// - Note: Invalid UTF8 sequences in the data are replaced with U+FFFD.
    /// - Parameter strict: If `true`, trailing commas in arrays/objects are treated as errors. Default is `false`.
    /// - Returns: A `JSON` value.
    /// - Throws: `JSONParserError` if the data does not contain valid JSON.
    public static func decode(data: NSData, strict: Swift.Bool = false) throws -> JSON {
        return try JSON.decode(UTF8Decoder(data: data), strict: strict)
    }
}

extension JSON {
    /// Converts a plist-compatible Foundation object into a `JSON` value.
    /// - Throws: `JSONPlistError` if the object is not plist-compatible.
    public init(plist: AnyObject) throws {
        if plist === kCFBooleanTrue {
            self = .Bool(true)
            return
        } else if plist === kCFBooleanFalse {
            self = .Bool(false)
            return
        }
        switch plist {
        case is NSNull:
            self = .Null
        case let n as NSNumber:
            let typeChar: UnicodeScalar
            let objCType = UnsafePointer<UInt8>(n.objCType)
            if objCType == nil || objCType[0] == 0 || objCType[1] != 0 {
                typeChar = "?"
            } else {
                typeChar = UnicodeScalar(objCType[0])
            }
            switch typeChar {
            case "c", "i", "s", "l", "q", "C", "I", "S", "L", "B":
                self = .Int64(n.longLongValue)
            case "Q": // unsigned long long
                let val = n.unsignedLongLongValue
                if val > UInt64(Swift.Int64.max) {
                    fallthrough
                }
                self = .Int64(Swift.Int64(val))
            default:
                self = .Double(n.doubleValue)
            }
        case let s as Swift.String:
            self = .String(s)
        case let dict as NSDictionary:
            var obj: [Swift.String: JSON] = Dictionary(minimumCapacity: dict.count)
            for (key, value) in dict {
                guard let key = key as? Swift.String else { throw JSONPlistError.NonStringKey }
                obj[key] = try JSON(plist: value)
            }
            self = .Object(JSONObject(obj))
        case let array as NSArray:
            var ary: ContiguousArray<JSON> = []
            ary.reserveCapacity(array.count)
            for elt in array {
                ary.append(try JSON(plist: elt))
            }
            self = .Array(ary)
        default:
            throw JSONPlistError.IncompatibleType
        }
    }
    
    /// Returns the JSON as a plist-compatible Foundation type.
    public var plist: AnyObject {
        switch self {
        case .Null: return NSNull()
        case .Bool(let b): return b as NSNumber
        case .String(let s): return s
        case .Int64(let i): return NSNumber(longLong: i)
        case .Double(let d): return d
        case .Object(let obj):
            let dict = NSMutableDictionary(capacity: obj.count)
            for (key, value) in obj {
                dict[key] = value.plist
            }
            return dict
        case .Array(let ary):
            return ary.map({$0.plist})
        }
    }
    
    /// Returns the JSON as a plist-compatible Foundation type, discarding any nulls.
    public var plistNoNull: AnyObject? {
        switch self {
        case .Null: return nil
        case .Bool(let b): return b as NSNumber
        case .String(let s): return s
        case .Int64(let i): return NSNumber(longLong: i)
        case .Double(let d): return d
        case .Object(let obj):
            let dict = NSMutableDictionary(capacity: obj.count)
            for (key, value) in obj {
                if let value = value.plistNoNull {
                    dict[key] = value
                }
            }
            return dict
        case .Array(let ary):
            return ary.flatMap({$0.plistNoNull})
        }
    }
}

/// An error that is thrown when converting from `AnyObject` to `JSON`.
/// - SeeAlso: `JSON.init(plist:)`
public enum JSONPlistError: ErrorType {
    /// Thrown when a non-plist-compatible type is found.
    case IncompatibleType
    /// Thrown when a dictionary has a key that is not a string.
    case NonStringKey
}

private struct UTF8Decoder: SequenceType {
    init(data: NSData) {
        self.data = data
    }
    
    func generate() -> Generator {
        return Generator(data: data)
    }
    
    private let data: NSData
    
    private struct Generator: GeneratorType {
        init(data: NSData) {
            self.data = data
            let ptr = UnsafeBufferPointer(start: UnsafePointer<UInt8>(data.bytes), count: data.length)
            gen = ptr.generate()
            utf8 = UTF8()
        }
        
        mutating func next() -> UnicodeScalar? {
            switch utf8.decode(&gen) {
            case .Result(let scalar): return scalar
            case .Error: return "\u{FFFD}"
            case .EmptyInput: return nil
            }
        }
        
        private let data: NSData
        private var gen: UnsafeBufferPointerGenerator<UInt8>
        private var utf8: UTF8
    }
}

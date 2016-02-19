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

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

/// A streaming JSON parser that consumes a sequence of unicode scalars.
public struct JSONParser<Seq: SequenceType where Seq.Generator.Element == UnicodeScalar>: SequenceType {
    public init(_ seq: Seq) {
        base = seq
    }
    
    public var strict: Bool = false
    
    public func generate() -> JSONParserGenerator<Seq.Generator> {
        var gen = JSONParserGenerator(base.generate())
        gen.strict = strict
        return gen
    }
    
    private let base: Seq
}

/// The generator for JSONParser.
public struct JSONParserGenerator<Gen: GeneratorType where Gen.Element == UnicodeScalar>: JSONEventGenerator {
    public init(_ gen: Gen) {
        base = PeekGenerator(gen)
    }
    
    public var strict: Bool = false
    
    public mutating func next() -> JSONEvent? {
        do {
            // the only states that may loop are ParseArrayComma and ParseObjectComma
            // which are guaranteed to shift to other states (if they don't return) so the loop is finite
            while true {
                switch state {
                case .ParseArrayComma:
                    switch skipWhitespace() {
                    case ","?:
                        state = .ParseArray(first: false)
                        continue
                    case "]"?:
                        try popStack()
                        return .ArrayEnd
                    case .Some:
                        throw error(.InvalidSyntax)
                    case nil:
                        throw error(.UnexpectedEOF)
                    }
                case .ParseObjectComma:
                    switch skipWhitespace() {
                    case ","?:
                        state = .ParseObjectKey(first: false)
                        continue
                    case "}"?:
                        try popStack()
                        return .ObjectEnd
                    case .Some:
                        throw error(.InvalidSyntax)
                    case nil:
                        throw error(.UnexpectedEOF)
                    }
                case .Initial:
                    guard let c = skipWhitespace() else { throw error(.UnexpectedEOF) }
                    let evt = try parseValue(c)
                    switch evt {
                    case .ArrayStart, .ObjectStart:
                        break
                    default:
                        state = .ParseEnd
                    }
                    return evt
                case .ParseArray(let first):
                    guard let c = skipWhitespace() else { throw error(.UnexpectedEOF) }
                    switch c {
                    case "]":
                        if !first && strict {
                            throw error(.TrailingComma)
                        }
                        try popStack()
                        return .ArrayEnd
                    case ",":
                        throw error(.MissingValue)
                    default:
                        let evt = try parseValue(c)
                        switch evt {
                        case .ArrayStart, .ObjectStart:
                            break
                        default:
                            state = .ParseArrayComma
                        }
                        return evt
                    }
                case .ParseObjectKey(let first):
                    guard let c = skipWhitespace() else { throw error(.UnexpectedEOF) }
                    switch c {
                    case "}":
                        if !first && strict {
                            throw error(.TrailingComma)
                        }
                        try popStack()
                        return .ObjectEnd
                    case ",", ":":
                        throw error(.MissingKey)
                    default:
                        let evt = try parseValue(c)
                        switch evt {
                        case .StringValue:
                            state = .ParseObjectValue
                        default:
                            throw error(.NonStringKey)
                        }
                        return evt
                    }
                case .ParseObjectValue:
                    guard skipWhitespace() == ":" else { throw error(.ExpectedColon) }
                    guard let c = skipWhitespace() else { throw error(.UnexpectedEOF) }
                    switch c {
                    case ",", "}":
                        throw error(.MissingValue)
                    default:
                        let evt = try parseValue(c)
                        switch evt {
                        case .ArrayStart, .ObjectStart:
                            break
                        default:
                            state = .ParseObjectComma
                        }
                        return evt
                    }
                case .ParseEnd:
                    if skipWhitespace() != nil {
                        throw error(.TrailingCharacters)
                    }
                    state = .Finished
                    return nil
                case .Finished:
                    return nil
                }
            }
        } catch let error as JSONParserError {
            state = .Finished
            return .Error(error)
        } catch {
            fatalError("unexpected error \(error)")
        }
    }
    
    private mutating func popStack() throws {
        if stack.popLast() == nil {
            fatalError("exhausted stack")
        }
        switch stack.last {
        case .Array?:
            state = .ParseArrayComma
        case .Object?:
            state = .ParseObjectComma
        case nil:
            state = .ParseEnd
        }
    }
    
    private mutating func parseValue(c: UnicodeScalar) throws -> JSONEvent {
        switch c {
        case "[":
            state = .ParseArray(first: true)
            stack.append(.Array)
            return .ArrayStart
        case "{":
            state = .ParseObjectKey(first: true)
            stack.append(.Object)
            return .ObjectStart
        case "\"":
            var s = ""
            while let c = bump() {
                switch c {
                case "\"":
                    return .StringValue(s)
                case "\\":
                    let c = try bumpRequired()
                    switch c {
                    case "\"", "\\", "/": s.append(c)
                    case "b": s.append(UnicodeScalar(0x8))
                    case "f": s.append(UnicodeScalar(0xC))
                    case "n": s.append("\n" as UnicodeScalar)
                    case "r": s.append("\r" as UnicodeScalar)
                    case "t": s.append("\t" as UnicodeScalar)
                    case "u":
                        let codeUnit = try parseFourHex()
                        if UTF16.isLeadSurrogate(codeUnit) {
                            guard try (bumpRequired() == "\\" && bumpRequired() == "u") else {
                                throw error(.LoneLeadingSurrogateInUnicodeEscape)
                            }
                            let trail = try parseFourHex()
                            if UTF16.isTrailSurrogate(trail) {
                                let lead = UInt32(codeUnit)
                                let trail = UInt32(trail)
                                s.append(UnicodeScalar(((lead - 0xD800) << 10) + (trail - 0xDC00) + 0x10000))
                            } else {
                                throw error(.LoneLeadingSurrogateInUnicodeEscape)
                            }
                        } else {
                            s.append(UnicodeScalar(codeUnit))
                        }
                    default:
                        throw error(.InvalidEscape)
                    }
                case "\0"..."\u{1F}":
                    throw error(.InvalidSyntax)
                default:
                    s.append(c)
                }
            }
            throw error(.UnexpectedEOF)
        case "-", "0"..."9":
            var tempBuffer: ContiguousArray<Int8>
            if let buffer = replace(&self.tempBuffer, with: nil) {
                tempBuffer = buffer
                tempBuffer.removeAll(keepCapacity: true)
            } else {
                tempBuffer = ContiguousArray()
                tempBuffer.reserveCapacity(12)
            }
            defer { self.tempBuffer = tempBuffer }
            tempBuffer.append(Int8(truncatingBitPattern: c.value))
            outerLoop: while let c = base.peek() {
                switch c {
                case "0"..."9":
                    bump()
                    tempBuffer.append(Int8(truncatingBitPattern: c.value))
                case ".":
                    bump()
                    tempBuffer.append(Int8(truncatingBitPattern: c.value))
                    guard let c = bump(), case "0"..."9" = c else { throw error(.InvalidNumber) }
                    tempBuffer.append(Int8(truncatingBitPattern: c.value))
                    loop: while let c = base.peek() {
                        switch c {
                        case "0"..."9":
                            bump()
                            tempBuffer.append(Int8(truncatingBitPattern: c.value))
                        case "e", "E":
                            bump()
                            tempBuffer.append(Int8(truncatingBitPattern: c.value))
                            guard let c = bump() else { throw error(.InvalidNumber) }
                            tempBuffer.append(Int8(truncatingBitPattern: c.value))
                            switch c {
                            case "-", "+":
                                guard let c = bump(), case "0"..."9" = c else { throw error(.InvalidNumber) }
                                tempBuffer.append(Int8(truncatingBitPattern: c.value))
                            case "0"..."9": break
                            default: throw error(.InvalidNumber)
                            }
                            while let c = base.peek() {
                                switch c {
                                case "0"..."9":
                                    bump()
                                    tempBuffer.append(Int8(truncatingBitPattern: c.value))
                                default:
                                    break loop
                                }
                            }
                            break loop
                        default:
                            break loop
                        }
                    }
                    tempBuffer.append(0)
                    return .DoubleValue(tempBuffer.withUnsafeBufferPointer({strtod($0.baseAddress, nil)}))
                case "e", "E":
                    bump()
                    tempBuffer.append(Int8(truncatingBitPattern: c.value))
                    guard let c = bump(), case "0"..."9" = c else { throw error(.InvalidNumber) }
                    tempBuffer.append(Int8(truncatingBitPattern: c.value))
                    loop: while let c = base.peek() {
                        switch c {
                        case "0"..."9":
                            bump()
                            tempBuffer.append(Int8(truncatingBitPattern: c.value))
                        default:
                            break loop
                        }
                    }
                    tempBuffer.append(0)
                    return .DoubleValue(tempBuffer.withUnsafeBufferPointer({strtod($0.baseAddress, nil)}))
                default:
                    break outerLoop
                }
            }
            if tempBuffer.count == 1 && tempBuffer[0] == 0x2d /* - */ {
                throw error(.InvalidNumber)
            }
            tempBuffer.append(0)
            let num = tempBuffer.withUnsafeBufferPointer({ ptr -> Int64? in
                errno = 0
                let n = strtoll(ptr.baseAddress, nil, 10)
                if n == 0 && errno != 0 {
                    return nil
                } else {
                    return n
                }
            })
            if let num = num {
                return .Int64Value(num)
            }
            // out of range, fall back to Double
            return .DoubleValue(tempBuffer.withUnsafeBufferPointer({strtod($0.baseAddress, nil)}))
        case "t":
            let line = self.line, column = self.column
            guard case "r"? = bump(), case "u"? = bump(), case "e"? = bump() else {
                throw JSONParserError(code: .InvalidSyntax, line: line, column: column)
            }
            return .BooleanValue(true)
        case "f":
            let line = self.line, column = self.column
            guard case "a"? = bump(), case "l"? = bump(), case "s"? = bump(), case "e"? = bump() else {
                throw JSONParserError(code: .InvalidSyntax, line: line, column: column)
            }
            return .BooleanValue(false)
        case "n":
            let line = self.line, column = self.column
            guard case "u"? = bump(), case "l"? = bump(), case "l"? = bump() else {
                throw JSONParserError(code: .InvalidSyntax, line: line, column: column)
            }
            return .NullValue
        default:
            throw error(.InvalidSyntax)
        }
    }
    
    private mutating func skipWhitespace() -> UnicodeScalar? {
        while let c = bump() {
            switch c {
            case " ", "\t", "\n", "\r": continue
            default: return c
            }
        }
        return nil
    }
    
    private mutating func parseFourHex() throws -> UInt16 {
        var codepoint: UInt32 = 0
        for _ in 0..<4 {
            let c = try bumpRequired()
            codepoint <<= 4
            switch c {
            case "0"..."9":
                codepoint += c.value - 48
            case "a"..."f":
                codepoint += c.value - 87
            case "A"..."F":
                codepoint += c.value - 55
            default:
                throw error(.InvalidEscape)
            }
        }
        return UInt16(truncatingBitPattern: codepoint)
    }
    
    @inline(__always) private mutating func bump() -> UnicodeScalar? {
        let c = base.next()
        if c == "\n" {
            line += 1
            column = 0
        } else {
            column += 1
        }
        return c
    }
    
    @inline(__always) private mutating func bumpRequired() throws -> UnicodeScalar {
        guard let c = bump() else { throw error(.UnexpectedEOF) }
        return c
    }
    
    private func error(code: JSONParserError.Code) -> JSONParserError {
        return JSONParserError(code: code, line: line, column: column)
    }
    
    /// The line of the last emitted token.
    public private(set) var line: UInt = 0
    /// The column of the last emitted token.
    public private(set) var column: UInt = 0
    
    private var base: PeekGenerator<Gen>
    private var state: State = .Initial
    private var stack: [Stack] = []
    private var tempBuffer: ContiguousArray<Int8>?
}

private enum State {
    /// Initial state
    case Initial
    /// Parse an element or the end of the array
    case ParseArray(first: Bool)
    /// Parse a comma or the end of the array
    case ParseArrayComma
    /// Parse an object key or the end of the array
    case ParseObjectKey(first: Bool)
    /// Parse a colon followed by an object value
    case ParseObjectValue
    /// Parse a comma or the end of the object
    case ParseObjectComma
    /// Parse whitespace or EOF
    case ParseEnd
    /// Parsing has completed
    case Finished
}

private enum Stack {
    case Array
    case Object
}

/// A streaming JSON parser event.
public enum JSONEvent {
    /// The start of an object.
    /// Inside of an object, each key/value pair is emitted as a
    /// `StringValue` for the key followed by the `JSONEvent` sequence
    /// that describes the value.
    case ObjectStart
    /// The end of an object.
    case ObjectEnd
    /// The start of an array.
    case ArrayStart
    /// The end of an array.
    case ArrayEnd
    /// A boolean value.
    case BooleanValue(Bool)
    /// A signed 64-bit integral value.
    case Int64Value(Int64)
    /// A double value.
    case DoubleValue(Double)
    /// A string value.
    case StringValue(String)
    /// The null value.
    case NullValue
    /// A parser error.
    case Error(JSONParserError)
}

/// A generator of `JSONEvent`s that records column/line info.
public protocol JSONEventGenerator: GeneratorType {
    /// The line of the last emitted token.
    var line: UInt { get }
    /// The column of the last emitted token.
    var column: UInt { get }
}

public struct JSONParserError: ErrorType, CustomStringConvertible {
    public let code: Code
    public let line: UInt
    public let column: UInt
    
    public init(code: Code, line: UInt, column: UInt) {
        self.code = code
        self.line = line
        self.column = column
    }
    
    public var _code: Int { return code.rawValue }
    
    public enum Code: Int {
        /// A generic syntax error.
        case InvalidSyntax
        /// An invalid number.
        case InvalidNumber
        /// An invalid string escape.
        case InvalidEscape
        /// A unicode string escape with an invalid code point.
        case InvalidUnicodeScalar
        /// A unicode string escape representing a leading surrogate without
        /// a corresponding trailing surrogate.
        case LoneLeadingSurrogateInUnicodeEscape
        /// A control character in a string.
        case ControlCharacterInString
        /// A comma was found where a colon was expected in an object.
        case ExpectedColon
        /// A comma or colon was found in an object without a key.
        case MissingKey
        /// An object key was found that was not a string.
        case NonStringKey
        /// A comma or object end was encountered where a value was expected.
        case MissingValue
        /// A trailing comma was found in an array or object. Only emitted when `strict` mode is enabled.
        case TrailingComma
        /// Trailing (non-whitespace) characters found after the close
        /// of the root value.
        case TrailingCharacters
        /// EOF was found before the root value finished parsing.
        case UnexpectedEOF
    }
    
    public var description: String {
        return "JSONParserError(\(code), line: \(line), column: \(column))"
    }
}

private struct PeekGenerator<Base: GeneratorType> {
    init(_ base: Base) {
        self.base = base
    }
    
    mutating func peek() -> Base.Element? {
        if let elt = peeked {
            return elt
        }
        let elt = base.next()
        peeked = .Some(elt)
        return elt
    }
    
    mutating func next() -> Base.Element? {
        if let elt = peeked {
            peeked = nil
            return elt
        }
        return base.next()
    }
    
    private var base: Base
    private var peeked: Base.Element??
}

private func replace<T>(inout a: T, with b: T) -> T {
    var b = b
    swap(&a, &b)
    return b
}

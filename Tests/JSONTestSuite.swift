//
//  JSONTestSuite.swift
//  PMJSON
//
//  Created by Kevin Ballard on 10/26/16.
//  Copyright © 2016 Postmates. All rights reserved.
//

import XCTest
import PMJSON

/// Tests for [JSONTestSuite](https://github.com/nst/JSONTestSuite).
final class JSONTestSuite: XCTestCase {
    private static let skipTests: [String] = [
        "n_structure_100000_opening_arrays",
        "n_structure_open_array_object"
    ]
    
    /// Whether or not we should expect to parse indeterminate cases.
    /// Some cases test things we explicitly want to support, others don't.
    private static let indeterminateParsing: [String: ShouldParse] = [
        "i_object_key_lone_2nd_surrogate": .no,
        "i_string_1st_surrogate_but_2nd_missing": .no,
        "i_string_1st_valid_surrogate_2nd_invalid": .no,
        "i_string_incomplete_surrogate_and_escape_valid": .no,
        "i_string_incomplete_surrogate_pair": .no,
        "i_string_incomplete_surrogates_escape_valid": .no,
        "i_string_inverted_surrogates_U+1D11E": .no,
        "i_string_lone_second_surrogate": .no,
        "i_string_not_in_unicode_range": .no,
        "i_string_truncated-utf-8": .no,
        
        // The following tests are for noncharacters that are still valid codepoints
        "i_string_unicode_U+10FFFE_nonchar": .yes,
        "i_string_unicode_U+1FFFE_nonchar": .yes,
        "i_string_unicode_U+FDD0_nonchar": .yes,
        "i_string_unicode_U+FFFE_nonchar": .yes,
        
        "i_string_UTF-16_invalid_lonely_surrogate": .no,
        "i_string_UTF-16_invalid_surrogate": .no,
        // JSON.decode(data) will handle invalid UTF-8, but we're parsing strictly as a String first
        "i_string_UTF-8_invalid_sequence": .no,
        "i_structure_500_nested_arrays": .yes,
        "i_structure_UTF-8_BOM_empty_object": .yes]
    
    private static var testCases: [String: (url: URL, shouldParse: ShouldParse)] = [:]
    
    override class func defaultTestSuite() -> XCTestSuite {
        guard testCases.isEmpty,
            let fixtures = Bundle(for: JSONTestSuite.self).resourcePath.map({ URL(fileURLWithPath: $0, isDirectory: true) })
            else { return super.defaultTestSuite() }
        if let parsingEnum = FileManager.default.enumerator(at: fixtures, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles, errorHandler: nil) {
            let imp = unsafeBitCast(executeIMP, to: IMP.self)
            for case let url as URL in parsingEnum where url.pathExtension == "json" {
                let name = url.deletingPathExtension().lastPathComponent
                guard let identifier = name.sanitized else {
                    print("*** Skipping test \(url.lastPathComponent) due to invalid name")
                    continue
                }
                guard !skipTests.contains(identifier) else { continue }
                var selName = "test_\(identifier)"
                var attempt = 1
                while testCases[selName] != nil {
                    attempt += 1
                    selName = "test_\(identifier)_\(attempt)"
                }
                let shouldParse: ShouldParse
                if name.hasPrefix("y_") {
                    shouldParse = .yes
                } else if name.hasPrefix("i_") {
                    shouldParse = indeterminateParsing[name] ?? .maybe
                } else {
                    shouldParse = .no
                }
                testCases[selName] = (url, shouldParse)
                class_addMethod(self, Selector(selName), imp, "c@:^@")
            }
        }
        return super.defaultTestSuite()
    }
    
    enum ShouldParse {
        case yes
        case no
        /// Whether it parses is implementation-defined.
        case maybe
    }
    
    static let executeIMP: @convention(c) (JSONTestSuite, Selector, NSErrorPointer) -> Bool = { (this, cmd, outError) in
        do {
            try this.execute(cmd: cmd)
            return true
        } catch {
            outError?.pointee = error as NSError
            return false
        }
    }
    
    func execute(cmd: Selector) throws {
        guard let (url, shouldParse) = JSONTestSuite.testCases[String(describing: cmd)]
            else { return XCTFail("No fixture URL found.") }
        
        let data = try Data(contentsOf: url)
        do {
            // Convert it to a String first, as there are tests that expect invalid UTF-8 to error out, or valid UTF-16 to work.
            // JSON.decode(data) will be liberal in how it accepts UTF-8
            let encoding: String.Encoding
            if data.count >= 2 && (data[0] == 0 || data[1] == 0) {
                encoding = .utf16
            } else {
                encoding = .utf8
            }
            guard let input = String(data: data, encoding: encoding) else {
                struct DecodeError: Error {}
                throw DecodeError()
            }
            _ = try JSON.decode(input, strict: true)
            switch shouldParse {
            case .yes:
                break
            case .maybe:
                XCTFail("\(url.lastPathComponent) - indeterminate parsing unspecified - parse succeeded")
            case .no:
                XCTFail("\(url.lastPathComponent) - unexpected parse success")
            }
        } catch {
            switch shouldParse {
            case .yes:
                XCTFail("\(url.lastPathComponent) - could not parse data - \(error)")
            case .maybe:
                XCTFail("\(url.lastPathComponent) - indeterminate parsing unspecified - parse failed")
            case .no:
                break
            }
        }
    }
}

private extension String {
    /// Returns the string, sanitized to be a valid identifier.
    /// If the string does not contain any valid identifier characters, returns `nil`.
    var sanitized: String? {
        guard let start = unicodeScalars.index(where: CharacterSet.identifierStart.contains) else { return nil }
        let scalars = unicodeScalars.suffix(from: start)
        var result = String.UnicodeScalarView()
        result.append(contentsOf: scalars.lazy.map({ CharacterSet.identifierContinue.contains($0) ? $0 : "_" }))
        return String(result)
    }
}

private extension CharacterSet {
    // Letters and _
    static let identifierStart: CharacterSet = {
        var cs = CharacterSet.letters
        cs.update(with: "_")
        return cs
    }()
    
    // Alphanumerics and _
    static let identifierContinue: CharacterSet = {
        var cs = CharacterSet.alphanumerics
        cs.update(with: "_")
        return cs
    }()
}

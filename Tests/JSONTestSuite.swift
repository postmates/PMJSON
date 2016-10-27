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
    /// How we should expect to parse various test cases.
    /// This is mainly intended for defining indeterminate cases, but may also
    /// be used to override other cases when the case is believed to be incorrect.
    private static let expectedParsing: [String: ShouldParse] = [
        "i_object_key_lone_2nd_surrogate": .no,
        "i_string_1st_surrogate_but_2nd_missing": .no,
        "i_string_1st_valid_surrogate_2nd_invalid": .no,
        "i_string_incomplete_surrogate_and_escape_valid": .no,
        "i_string_incomplete_surrogate_pair": .no,
        "i_string_incomplete_surrogates_escape_valid": .no,
        "i_string_inverted_surrogates_U+1D11E": .no,
        "i_string_lone_second_surrogate": .no,
        "i_string_not_in_unicode_range": .yes,
        "i_string_truncated-utf-8": .yes,
        
        // The following tests are for noncharacters that are still valid codepoints
        "i_string_unicode_U+10FFFE_nonchar": .yes,
        "i_string_unicode_U+1FFFE_nonchar": .yes,
        "i_string_unicode_U+FDD0_nonchar": .yes,
        "i_string_unicode_U+FFFE_nonchar": .yes,
        
        "i_string_UTF-16_invalid_lonely_surrogate": .no,
        "i_string_UTF-16_invalid_surrogate": .no,
        "i_string_UTF-8_invalid_sequence": .yes,
        "i_structure_500_nested_arrays": .yes,
        "i_structure_UTF-8_BOM_empty_object": .yes,
        "i_string_UTF-16LE_with_BOM": .yes,
        
        "n_number_then_00": .yes, // Indistinguishable from UTF-161LE
        // The following test handling of invalid UTF-8 byte sequences, which we support
        "n_string_invalid_utf-8": .yes,
        "n_string_iso_latin_1": .yes,
        "n_string_lone_utf8_continuation_byte": .yes,
        "n_string_overlong_sequence_2_bytes": .yes,
        "n_string_overlong_sequence_6_bytes": .yes,
        "n_string_overlong_sequence_6_bytes_null": .yes,
        "n_string_UTF8_surrogate_U+D800": .yes]
    
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
                let shouldParse: ShouldParse
                if let expected = expectedParsing[name] {
                    shouldParse = expected
                } else if name.hasPrefix("y_") {
                    shouldParse = .yes
                } else if name.hasPrefix("i_") {
                    shouldParse = .maybe
                } else if name.hasPrefix("n_") {
                    shouldParse = .no
                } else {
                    print("*** Skipping test \(url.lastPathComponent) due to unknown parse expectation")
                    continue
                }
                var selName = "test_\(identifier)"
                var attempt = 1
                while testCases[selName] != nil {
                    attempt += 1
                    selName = "test_\(identifier)_\(attempt)"
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
            _ = try JSON.decode(data, options: [.strict])
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

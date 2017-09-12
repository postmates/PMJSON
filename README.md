# PMJSON

[![Version](https://img.shields.io/badge/version-v2.0.3-blue.svg)](https://github.com/postmates/PMJSON/releases/latest)
![Platforms](https://img.shields.io/badge/platforms-ios%20%7C%20osx%20%7C%20watchos%20%7C%20tvos-lightgrey.svg)
![Languages](https://img.shields.io/badge/languages-swift-orange.svg)
![License](https://img.shields.io/badge/license-MIT%2FApache-blue.svg)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)][Carthage]
[![CocoaPods](https://img.shields.io/cocoapods/v/PMJSON.svg)](http://cocoadocs.org/docsets/PMJSON)

[Carthage]: https://github.com/carthage/carthage

PMJSON provides a pure-Swift strongly-typed JSON encoder/decoder as well as a set of convenience methods for converting to/from Foundation objects and for decoding JSON structures.

The entire JSON encoder/decoder can be used without Foundation, by removing the files `ObjectiveC.swift` and `DecimalNumber.swift` from the project. The only dependency the rest of the project has is on `Darwin`, for `strtod()` and `strtoll()`. The file `ObjectiveC.swift` adds convenience methods for translating between `JSON` values and Foundation objects as well as decoding from a `Data`, and `DecimalNumber.swift` adds convenience accessors for converting values into `NSDecimalNumber`.

## Usage

Before diving into the details, here's a simple example of writing a decoder for a struct. There are a few different options for how to deal with malformed data (e.g. whether to ignore values of wrong types, and whether to try and coerce non-string values to strings or vice versa), but the following example will be fairly strict and throw an error for incorrectly-typed values:

```swift
struct Address {
    var streetLine1: String
    var streetLine2: String?
    var city: String
    var state: String?
    var postalCode: String
    var country: String?

    init(json: JSON) throws {
        streetLine1 = try json.getString("street_line1")
        streetLine2 = try json.getStringOrNil("street_line2")
        city = try json.getString("city")
        state = try json.getStringOrNil("state")
        postalCode = try json.toString("postal_code") // coerce numbers to strings
        country = try json.getStringOrNil("country")
    }
}
```

And here's an example of decoding a nested array of values:

```swift
struct Person {
    var firstName: String
    var lastName: String? // some people don't have last names
    var age: Int
    var addresses: [Address]

    init(json: JSON) throws {
        firstName = try json.getString("firstName")
        lastName = try json.getStringOrNil("lastName")
        age = try json.getInt("age")
        addresses = try json.mapArray("addresses", Address.init(json:))
    }
}
```

If you don't want to deal with errors and just want to handle optionals, you can do that too:

```swift
struct Config {
    var name: String?
    var doThatThing: Bool
    var maxRetries: Int
    
    init(json: JSON) {
        name = json["name"]?.string
        doThatThing = json["doThatThing"]?.bool ?? false
        maxRetries = json["maxRetries"]?.int ?? 10
    }
}
```

### Parsing

The JSON decoder is split into separate parser and decoder stages. The parser consums any sequence of unicode scalars, and produces a sequence of JSON "events" (similar to a SAX XML parser). The decoder accepts a sequence of JSON events and produces a `JSON` value. This architecture is designed such that you can use just the parser alone in order to decode directly to your own data structures and bypass the `JSON` representation entirely if desired. However, most clients are expected to use both components, and this is exposed via a simple method `JSON.decode(_:options:)`.

Parsing a JSON string into a `JSON` value is as simple as:

```swift
let json = try JSON.decode(jsonString)
```

Any errors in the JSON parser are represented as `JSONParserError` values and are thrown from the `decode()` method. The error contains the precise line and column of the error, and a code that describes the problem.

A convenience method is also provided for decoding from a `Data` containing data encoded as UTF-8, UTF-16, or UTF-32:

```swift
let json = try JSON.decode(data)
```

Encoding a `JSON` value is also simple:

```swift
let jsonString = JSON.encodeAsString(json)
```

You can also encode directly to any `TextOutputStream`:

```swift
JSON.encode(json, toStream: &output)
```

And, again, a convenience method is provided for working with `Data`:

```swift
let data = JSON.encodeAsData(json)
```

#### JSON Streams

PMJSON supports parsing JSON streams, which are multiple top-level JSON values with optional whitespace delimiters (such as `{"a": 1}{"a": 2}`). The easiest way to use this is with `JSON.decodeStream(_:)` which returns a lazy sequence of `JSONStreamValue`s, which contain either a `JSON` value or a `JSONParserError` error. You can also use `JSONParser`s and `JSONDecoder`s directly for more fine-grained control over streaming.

#### `JSONParser` and `JSONDecoder`

As mentioned above, the JSON decoder is split into separate parser and decoder stages. `JSONParser` is the parser stage, and it wraps any sequence of `UnicodeScalar`s, and itself is a sequence of `JSONEvent`s. A `JSONEvent` is a single step of JSON parsing, such as `.objectStart` when a `{` is encountered, or `.stringValue(_)` when a `"string"` is encountered. You can use `JSONParser` directly to emit a stream of events if you want to do any kind of lazy processing of JSON (such as if you're dealing with a single massive JSON blob and don't want to decode the whole thing into memory at once).

Similarly, `JSONDecoder` is the decoder stage. It wraps a sequence of `JSONEvent`s, and decodes that sequence into a proper `JSON` value. The wrapped sequence must also conform to a separate protocol `JSONEventIterator` that provides line/column information, which are used when emitting errors. You can use `JSONDecoder` directly if you want to wrap a sequence of events other than `JSONParser`, or if you want a different interface to JSON stream decoding than `JSONStreamDecoder` provides.

Because of this split nature, you can easily provide your own event stream, or your own decoding stage. Or you can do things like wrap `JSONParser` in an adaptor that modfiies the events before passing them to the decoder (which may be more efficient than converting the resulting `JSON` value).

### Accessors

Besides encoding/decoding, this library also provides a comprehensive suite of accessors for getting data out of `JSON` values. There are 4 types of basic accessors provided:

1. Basic property accessors named after types such as `.string`. These accessors return the underlying value if it matches the type, or `nil` if  the value is not the right type. For example, `.string` returns `String?`. These accessors do not convert between types, e.g. `JSON.Int64(42).string` returns `nil`.
2. Property accessors beginning with the word `as`, such as `.asString`. These accessors also return an optional value, but they convert between types if it makes sense to do so. For example, `JSON.Int64(42).asString` returns `"42"`.
3. Methods beginnning with `get`, such as `getString()`. These methods return non-optional values, and throw `JSONError`s if the value's type does not match. These methods do not convert between types, e.g. `try JSON.Int64(42).getString()` throws an error. For every method of this type, there's also a variant ending in `OrNil`, such as `getStringOrNil()`, which does return an optional. These methods only return `nil` if the value is `null`, otherwise they throw an error.
4. Methods beginning with `to`, such as `toString()`. These are just like the `get` methods except they convert between types when appropriate, using the same rules that the `as` methods do, e.g. `try JSON.Int64(42).toString()` returns `"42"`. Like the `get` methods, there are also variants ending in `OrNil`.

`JSON` also provides both keyed and indexed subscript operators that return a `JSON?`, and are always safe to call (even with out-of-bounds indexes). And it provides 2 kinds of subscripting accessors:

1. For every basic `get` accessor, there's a variant that takes a key or an index. These are equivalent to subscripting the receiver and invoking the `get` accessor on the result, except they produce better errors (and they handle missing keys/out-of-bounds indexes properly). For example, `getString("key")` or `getString(index)`. The `OrNil` variants also return `nil` if the key doesn't exist or the index is out-of-bounds.
2. Similarly, there are subscripting equivalents for the `to` accessors as well.

And finally, the `getObject()` and `getArray()` accessors provide variants that take a closure. These variants are recommended over the basic accessors as they produce better errors. For example, given the following JSON:

```json
{
  "object": {
    "elements": [
      {
        "name": null
      }
    ]
  }
}
```

And the following code:

```swift
try json.getObject("object").getArray("elements").getObject(0).getString("name")
```

The error thrown by this code will have the description `"name: expected string, found null"`.

But given the following equivalent code:

```swift
try json.getObject("object", { try $0.getArray("elements", { try $0.getObject(0, { try $0.getString("name") }) }) })
```

The error thrown by this code will have the description `"object.elements[0].name: expected string, found null"`.

All of these accessors are also available on the `JSONObject` type (which is the type that represents an object).

The last code snippet above looks very verbose, but in practice you don't end up writing code like that. Instead you'll often end up just writing things like

```swift
try json.mapArray("elements", Element.init(json:))
```

### Helpers

The `JSON` type has static methods `map()` and `flatMap()` for working with arrays (since PMJSON does not define its own array type). The benefit of using these methods over using the equivalent `SequenceType` methods is the PMJSON static methods produce better errors.

There are also helpers for converting to/from Foundation objects. `JSON` offers an initializer `init(ns: AnyObject) throws` that converts from any JSON-compatible object to a `JSON`. `JSON` and `JSONObject` both offer the property `.ns`, which returns a Foundation object equivalent to the `JSON`, and `.nsNoNull` which does the same but omits any `null` values instead of using `NSNull`.

### Performance

The test suite includes some basic performance tests. Decoding ~70KiB of JSON using PMJSON takes about 2.5-3x the time that `NSJSONSerialization` does, though I haven't tested this with different distributions of inputs and it's possible this performance is specific to the characteristics of the test input. However, encoding the same JSON back to a `Data` is actually faster with PMJSON, taking around 75% of the time that `NSJSONSerialization` does.

## Requirements

Installing as a framework requires a minimum of iOS 8, OS X 10.9, watchOS 2.0, or tvOS 9.0.

## Installation

After installing with any mechanism, you can use this by adding `import PMJSON` to your code.

### Swift Package Manager

The [Swift Package Manager][] may be used to install PMJSON by adding it to your `dependencies` list:

```swift
let package = Package(
    name: "YourPackage",
    dependencies: [
        .Package(url: "https://github.com/postmates/PMJSON.git", majorVersion: 2)
    ]
)
```

[Swift Package Manager]: https://swift.org/package-manager/

### Carthage

To install using [Carthage][], add the following to your Cartfile:

```
github "postmates/PMJSON" ~> 2.0
```

This release supports Swift 3. If you want Swift 2.3 support, you can use

```
github "postmates/PMJSON" ~> 0.9.4
```

### CocoaPods

To install using [CocoaPods][], add the following to your Podfile:

```
pod 'PMJSON', '~> 2.0'
```

This release supports Swift 3. If you want Swift 2.3 support, you can use

```
pod 'PMJSON', '~> 0.9.4'
```

[CocoaPods]: https://cocoapods.org

## License

Licensed under either of
 * Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or
   http://www.apache.org/licenses/LICENSE-2.0)
 * MIT license ([LICENSE-MIT](LICENSE-MIT) or
   http://opensource.org/licenses/MIT) at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you shall be dual licensed as above, without any additional terms or conditions.

## Version History

#### v2.0.3 (2017-09-12)

* Add Linux support for `Decimal` (on Swift 3.1 and later). NOTE: Decimal support is still buggy in Swift 3.1, and the workarounds we employ to get the correct values on Apple platforms don't work on Linux. You probably shouldn't rely on this working correctly on Linux until Swift fixes its Decimal implementation.
* Add Linux support for decoding from/encoding to `Data`.
* Add Linux support for `LocalizedError` on the Error types (only really applies to Swift 3.1 and later).
* Fix compilation on Linux using the release configuration.
* Support running the test suite with `swift test`.

#### v2.0.2 (2017-03-06)

* Fix Linux compatibility.

#### v2.0.1 (2017-02-26)

* Add method `JSON.parser(for:options:)` that returns a `JSONParser<AnySequence<UnicodeScalar>>` from a `Data`. Like `JSON.decode(_:options:)`, this method automatically detects UTF-8, UTF-16, or UTF-32 input.
* Fix compatibility with Swift Package Manager.

#### v2.0.0 (2017-01-02)

* Add full support for decimal numbers (on supported platforms). This takes the form of a new `JSON` variant `.decimal`, any relevant accessors, and full parsing/decoding support with the new option `.useDecimals`. With this option, any number that would have been decoded as a `Double` will be decoded as a `Decimal` instead.
* Add a set of `forEach` accessors for working with arrays, similar to the existing `map` and `flatMap` accessors.

#### v1.2.1 (2016-10-27)

* Handle UTF-32 input.
* Detect UTF-16 and UTF-32 input without a BOM.
* Fix bug where we weren't passing decoder options through for UTF-16 input.

#### v1.2.0 (2016-10-27)

* Change how options are provided to the encoder/decoder/parser. All options are now provided in the form of a struct that uses array literal syntax (similar to `OptionSet`s). The old methods that take strict/pretty flags are now marked as deprecated.
* Add a new depth limit option to the decoder, with a default of 10,000.
* Implement a new test suite based on [JSONTestSuite](https://github.com/nst/JSONTestSuite).
* Fix a crash if the input stream contained a lone trail surrogate without a lead surrogate.
* Fix incorrect parsing of numbers of the form `1e-1` or `1e+1`.
* When the `strict` option is specified, stop accepting numbers of the form `01` or `-01`.
* Add support for UTF-16 when decoding a `Data` that has a UTF-16 BOM.
* Skip a UTF-8 BOM if present when decoding a `Data`.

#### v1.1.0 (2016-10-20)

* Add `Hashable` to `JSONEvent` and `JSONParserError`.
* Make `JSONParserError` conform to `CustomNSError` for better Obj-C errors.
* Full JSON stream support. `JSONParser` and `JSONDecoder` can now both operate in streaming mode, a new type `JSONStreamDecoder` was added as a lazy sequence of JSON values, and a convenience method `JSON.decodeStream(_:)` was added.
* Rename `JSONEventGenerator` to `JSONEventIterator` and `JSONParserGenerator` to `JSONParserIterator`. The old names are available (but deprecated) for backwards compatibility.
* Add support for pattern matching with `JSONParserError`. It should now work just like any other error, allowing you to say e.g. `if case JSONParserError.invalidSyntax = error { … }`.

#### v1.0.1 (2016-09-15)

* Fix CocoaPods.

#### v1.0.0 (2016-09-08)

* Support Swift 3.0.
* Add setters for basic accessors so you can write code like `json["foo"].object?["key"] = "bar"`.
* Provide a localized description for errors when bridged to `NSError`.
* Add support to `JSONParser` for streams of JSON values (e.g. `"[1][2]"`).

#### v0.9.3 (2016-05-23)

* Add a set of convenience methods on `JSON` and `JSONObject` for mapping arrays returned by subscripting with a key or index: `mapArray(_:_:)`, `mapArrayOrNil(_:_:)`, `flatMapArray(_:_:)`, and `flatMapArrayOrNil(_:_:)`.
* Add new set of convenience `JSON` initializers.
* Change `description` and `debugDescription` for `JSON` and `JSONObject` to be more useful.
  `description` is now the JSON-encoded string.
* Implement `CustomReflectable` for `JSON` and `JSONObject`.

#### v0.9.2 (2016-03-04)

* CocoaPods support.

#### v0.9.1 (2016-02-19)

* Linux support.
* Swift Package Manager support.
* Rename instances of `plist` in the API to `ns`. The old names are still available but marked as deprecated.
* Support the latest Swift snapshot (2012-02-08).

#### v0.9 (2016-02-12)

Initial release.

# PMJSON

[![Version](https://img.shields.io/badge/version-v0.9-blue.svg)](https://github.com/postmates/PMJSON/releases/latest)
![Platforms](https://img.shields.io/badge/platforms-ios%20%7C%20osx%20%7C%20watchos%20%7C%20tvos-lightgrey.svg)
![Languages](https://img.shields.io/badge/languages-swift-orange.svg)
![License](https://img.shields.io/badge/license-MIT%2FApache-blue.svg)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)][Carthage]

[Carthage]: https://github.com/carthage/carthage

PMJSON provides a pure-Swift strongly-typed JSON encoder/decoder as well as a set of convenience methods for converting to/from Foundation plist objects and for decoding JSON structures.

The entire JSON encoder/decoder can be used without Foundation, by removing the files `ObjectiveC.swift` and `DecimalNumber.swift` from the project. The only dependency the rest of the project has is on `Darwin`, for `strtod()` and `strtoll()`. The file `ObjectiveC.swift` adds convenience methods for translating between `JSON` values and Foundation plist-compatible objects as well as decoding from an `NSData`, and `DecimalNumber.swift` adds convenience accessors for converting values into `NSDecimalNumber`.

## Usage

### Parsing

The JSON decoder is split into separate parser and decoder stages. The parser consums any sequence of unicode scalars, and produces a sequence of JSON "events" (similar to a SAX XML parser). The decoder accepts a sequence of JSON events and produces a `JSON` value. This architecture is designed such that you can use just the parser alone in order to decode directly to your own data structures and bypass the `JSON` representation entirely if desired. However, most clients are expected to use both components, and this is exposed via a simple method `JSON.decode(_:strict:)`.

Parsing a JSON string into a `JSON` value is as simple as:

```swift
let json = try JSON.decode(jsonString)
```

Any errors in the JSON parser are represented as `JSONParserError` values and are thrown from the `decode()` method. The error contains the precise line and column of the error, and a code that describes the problem.

A convenience method is also provided for decoding from an `NSData` containing UTF8-encoded data:

```swift
let json = try JSON.decode(data)
```

Encoding a `JSON` value is also simple:

```swift
let jsonString = JSON.encodeAsString(json)
```

You can also encode directly to any `OutputStreamType`:

```swift
JSON.encode(json, toStream: &output)
```

And, again, a convenience method is provided for working with `NSData`:

```swift
let data = JSON.encodeAsData(json)
```

### Accessors

Besides encoding/decoding, this library also provides a comprehensive suite of accessors for getting data out of `JSON` values. There's 4 types of basic accessors provided:

1. Basic property accessors named after types such as `.string`. These accessors return the underlying value if it matches the type, or `nil` if  the value is not the right type. For example, `.string` returns `String?`. These accessors do not convert between types, e.g. `JSON.Int64(42).string` returns `nil`.
2. Property accessors beginning with the word `as`, such as `.asString`. These accessors also return an optional value, but they convert between types if it makes sense to do so. For example, `JSON.Int64(42).asString` returns `"42"`.
3. Methods beginnning with `get`, such as `getString()`. These methods return non-optional values, and throw `JSONError`s if the value's type does not match. These methods do not convert between types, e.g. `try JSON.Int64(42).getString()` throws an error. For every method of this type, there's also a variant ending in `OrNil`, such as `getStringOrNil()`, which does return an optional. These methods only return `nil` if the value is `null`, otherwise they throw an error.
4. Methods beginning with `to`, such as `toString()`. These are just like the `get` methods except they convert between types when appropriate, using the same rules that the `as` methods do, e.g. `try JSON.Int64(42).toString()` returns `"42"`. Like the `get` methods, there's also variants ending in `OrNil`.

`JSON` also provides both keyed and indexed subscript operators that return a `JSON?`, and are always safe to call (even with out-of-bounds indexes). And it provides 2 kinds of subscripting accessors:

1. For every basic `get` accessor, there's a variant that takes a key or an index. These are equivalent to subscripting the receiver and invoking the `get` accessor on the result, except they produce better errors (and they handle missing keys/out-of-bounds indexes properly). For example, `getString("key")` or `getString(index)`. The `OrNil` variants also return `nil` if the key doesn't exist or the index is out-of-bounds.
2. Similarly, there's subscripting equivalents for the `to` accessors as well.

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

### Helpers

The `JSON` type has static methods `map()` and `flatMap()` for working with arrays (since PMJSON does not define its own array type). The benefit of using these methods over using the equivalent `SequenceType` methods is the PMJSON static methods produce better errors.

There's also helpers for converting to/from plist-compatible objects. `JSON` offers an initializer `init(plist: AnyObject) throws` that converts from any plist-compatible object to a `JSON`. `JSON` and `JSONObject` both offer the property `.plist`, which returns a plist-compatible object equivalent to the `JSON`, and `.plistNoNull` which does the same but omits any `null` values instead of using `NSNull`.

### Performance

The test suite includes some basic performance tests. Decoding ~70KiB of JSON using PMJSON takes about 2.5-3x the time that `NSJSONSerialization` does, though I haven't tested this with different distributions of inputs and it's possible this performance is specific to the characteristics of the test input. However, encoding the same JSON back to an `NSData` is actually faster with PMJSON, taking around 75% of the time that `NSJSONSerialization` does.

## Requirements

Installing as a framework requires a minimum of iOS 8, OS X 10.9, watchOS 2.0, or tvOS 9.0.

## Installation

To install using [Carthage][], add the following to your Cartfile:

```
github "postmates/PMJSON"
```

Once installed, you can use this by adding `import PMJSON` to your code.

## License

Licensed under either of
 * Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or
   http://www.apache.org/licenses/LICENSE-2.0)
 * MIT license ([LICENSE-MIT](LICENSE-MIT) or
   http://opensource.org/licenses/MIT) at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you shall be dual licensed as above, without any additional terms or conditions.

## Version History

#### v0.9

Initial release.

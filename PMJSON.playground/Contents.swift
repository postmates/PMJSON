//: Playground - noun: a place where people can play

import PMJSON

// Print some pretty output so we can eyeball it and make sure it looks good
let json: JSON = [
    "foo": "bar",
    "array": [1,2,3,4,5],
    "dict": [
        "color": "red",
        "fruit": "apple"
    ],
    "empty_dict": [:],
    "empty_array": []
]

print(JSON.encodeAsString(json, options: [.pretty]))

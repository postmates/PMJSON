//
//  JSONKey.swift
//  PMJSON
//
//  Created by Kevin Ballard on 2/16/18.
//  Copyright © 2018 Kevin Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

internal enum JSONKey: CodingKey {
    static let `super` = JSONKey.string("super")
    
    case int(Int)
    case string(String)
    
    var stringValue: String {
        switch self {
        case .int(let x): return String(x)
        case .string(let s): return s
        }
    }
    
    var intValue: Int? {
        switch self {
        case .int(let x): return x
        case .string: return nil
        }
    }
    
    init?(stringValue: String) {
        self = .string(stringValue)
    }
    
    init?(intValue: Int) {
        self = .int(intValue)
    }
}

//
//  SwiftCompatibility.swift
//  PMJSON
//
//  Created by Kevin Ballard on 3/5/18.
//  Copyright © 2018 Kevin Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#if !swift(>=4.1)
    extension Sequence {
        func compactMap<ElementOfResult>(_ transform: (Element) throws -> ElementOfResult?) rethrows -> [ElementOfResult] {
            return try flatMap(transform)
        }
    }
    
    extension LazySequenceProtocol {
        func compactMap<ElementOfResult>(_ transform: @escaping (Element) -> ElementOfResult?) -> LazyMapSequence<LazyFilterSequence<LazyMapSequence<Elements, ElementOfResult?>>, ElementOfResult> {
            return flatMap(transform)
        }
    }
    
    extension LazyCollectionProtocol {
        func compactMap<ElementOfResult>(_ transform: @escaping (Element) -> ElementOfResult?) -> LazyMapCollection<LazyFilterCollection<LazyMapCollection<Elements, ElementOfResult?>>, ElementOfResult> {
            return flatMap(transform)
        }
    }
#endif

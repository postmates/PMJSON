//
//  CombineSupport.swift
//  PMJSON
//
//  Created by Lily Ballard on 11/13/19.
//  Copyright © 2019 Lily Ballard.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#if canImport(Combine)
import Combine
import Foundation

extension JSON.Decoder: TopLevelDecoder {
    public typealias Input = Data
}

extension JSON.Encoder: TopLevelEncoder {
    public typealias Output = Data
}
#endif

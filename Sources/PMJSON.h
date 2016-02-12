//
//  JSON.h
//  JSON
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

#if defined(__cplusplus)
#define PMJSON_EXTERN extern "C"
#else
#define PMJSON_EXTERN extern
#endif

//! Project version number for JSON.
PMJSON_EXTERN double PMJSONVersionNumber;

//! Project version string for JSON.
PMJSON_EXTERN const unsigned char PMJSONVersionString[];

#undef PMJSON_EXTERN

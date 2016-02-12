//
//  JSON.h
//  JSON
//
//  Created by Kevin Ballard on 10/8/15.
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

//
//  JSON.h
//  JSON
//
//  Created by Kevin Ballard on 10/8/15.
//

#if defined(__cplusplus)
#define JSON_EXTERN extern "C"
#else
#define JSON_EXTERN extern
#endif

//! Project version number for JSON.
JSON_EXTERN double JSONVersionNumber;

//! Project version string for JSON.
JSON_EXTERN const unsigned char JSONVersionString[];

#undef JSON_EXTERN

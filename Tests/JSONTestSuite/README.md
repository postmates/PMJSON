# JSON Parsing Test Suite
A comprehensive test suite for RFC 7159 compliant JSON parsers

**Note**: This directory contains just the test files from [JSONTestSuite](https://github.com/nst/JSONTestSuite).

This repository was created as an appendix to the article [Parsing JSON is a Minefield 💣](http://seriot.ch/parsing_json.php).

**/test\_parsing/**

The name of these files tell if their contents should be accepted or rejected.

- `y_` content must be accepted by parsers
- `n_` content must be rejected by parsers
- `i_` parsers are free to accept or reject content

import XCTest
import PMJSONTests

XCTMain([
    testCase(JSONDecoderTests.allLinuxTests),
    testCase(JSONStreamDecoderTests.allLinuxTests),
    testCase(JSONAccessorTests.allLinuxTests),
    testCase(JSONParserTests.allLinuxTests),
    testCase(JSONEncoderTests.allLinuxTests),
    //testCase(JSONBenchmarks.allLinuxTests)
    // NB: Benchmarks are disabled for now because they're really slow under debug configuration
    ])

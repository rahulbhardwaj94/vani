// Minimal assertion harness — CLT ships no XCTest/swift-testing, so tests
// are a plain executable: every `expect` records pass/fail, main exits 1 on
// any failure.
var passCount = 0
var failCount = 0

func expect(_ actual: String, _ expected: String, file: String = #fileID, line: Int = #line) {
    if actual == expected {
        passCount += 1
    } else {
        failCount += 1
        print("""
        FAIL \(file):\(line)
          expected: \(expected)
          actual:   \(actual)
        """)
    }
}

func summary() -> Int32 {
    print("\n\(passCount) passed, \(failCount) failed")
    return failCount == 0 ? 0 : 1
}

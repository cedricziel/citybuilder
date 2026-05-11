import Testing
@testable import CityCore

// CANARY: This test is intentionally false. Its purpose is to verify that
// the swift-testing test target, coverage instrumentation, the pre-push
// hook, and (once wired) CI all surface a failing test as a red bar.
//
// Per M0 task 1.10, this file MUST be removed in the very next commit
// once the red bar is observed locally. If you are reading this in main,
// the workflow regressed — delete the file and open an issue.
@Test("CANARY: deliberately failing test for verifying the red bar")
func canaryFailsDeliberately() {
    #expect(1 == 2, "Canary test must fail. If this passes, the assertion machinery is broken.")
}

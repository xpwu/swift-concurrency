import XCTest
@testable import xpwu_concurrency

final class xpwu_concurrencyTests: XCTestCase {
    func testExample() throws {
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest

        // Defining Test Cases and Test Methods
        // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
    }
	
	func testChannel() async throws {
		let ch = Channel<Bool>(buffer: 1)
		await ch.Send(true)
		let r = await ch.Receive()
		XCTAssertNotNil(r)
		XCTAssertTrue(r!)
	}
	
	func testChannel2() async throws {
		let ch = Channel<Bool>(buffer: 1)
		async let _ = ch.Send(true)
		let r = await ch.Receive()
		XCTAssertNotNil(r)
		XCTAssertTrue(r!)
	}
}

import XCTest
import xpwu_x
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
	
	func testChannel_01() async throws {
		let ch = Channel<Bool>()
		async let rf = ch.Receive()
		await ch.Send(true)
		let r = await rf
		XCTAssertNotNil(r)
		XCTAssertTrue(r!)
	}
	
	func testChannel_02() async throws {
		let ch = Channel<Bool>()
		async let _ = ch.Send(true)
		let r = await ch.Receive()
		XCTAssertNotNil(r)
		XCTAssertTrue(r!)
	}
	
	func testChannelCancel1() async throws {
		let ch = Channel<Bool>()
		let task = Task {
			await ch.SendOrFailed(true)
		}
		try! await Task.sleep(nanoseconds: 1000000)
		task.cancel()
		let r = await task.value
		XCTAssertNotNil(r)
		XCTAssertNotNil(r as? CancellationError)
	}
	
	func testChannelCancel2() async throws {
		let ch = Channel<Bool>()
		let task = Task {
			await ch.ReceiveOrFailed()
		}
		try! await Task.sleep(nanoseconds: 1000000)
		task.cancel()
		let r = await task.value
		XCTAssertNotNil(r)
		switch r {
		case .failure(let err):
			XCTAssertNotNil(err as? CancellationError)
		default:
			XCTAssertTrue(false)
		}
	}
	
	func testTimeout() async throws {
		let ch = Channel<Bool>()
		
		let rt = await withTimeout(1*Duration.Second) {
			await ch.Receive() ?? false
		}
		XCTAssertNil(rt)
	}
}

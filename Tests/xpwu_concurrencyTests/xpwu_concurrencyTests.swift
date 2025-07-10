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
		_ = try await ch.Send(true)
		let r = await ch.ReceiveOrNil()
		XCTAssertNotNil(r)
		XCTAssertTrue(r!)
	}
	
	func testChannel2() async throws {
		let ch = Channel<Bool>(buffer: 1)
		async let _ = ch.Send(true)
		let r = await ch.ReceiveOrNil()
		XCTAssertNotNil(r)
		XCTAssertTrue(r!)
	}
	
	func testChannel_01() async throws {
		let ch = Channel<Bool>()
		async let rf = ch.ReceiveOrNil()
		_ = await ch.SendOrErr(true)
		let r = await rf
		XCTAssertNotNil(r)
		XCTAssertTrue(r!)
	}
	
	func testChannel_02() async throws {
		let ch = Channel<Bool>()
		async let _ = ch.SendOrErr(true)
		let r = await ch.ReceiveOrNil()
		XCTAssertNotNil(r)
		XCTAssertTrue(r!)
	}
	
	func testChannelCancel1() async throws {
		let ch = Channel<Bool>()
		let task = Task {
			await ch.SendOrErr(true)
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
		
		let rt = try await withTimeoutOrNil(1*Duration.Second) {
			try await ch.Receive()!
		}
		XCTAssertNil(rt)
	}
	
	func testSem() async throws {
		let con = 9
		let sem = Semaphore(permits: 3)
		
		async let group = withTaskGroup(of: Void.self, returning: Bool.self) { group in
			for _ in 1...con {
				group.addTask {
					let err = await sem.AcquireOrErr()
					XCTAssertNil(err)
				}
			}
			
			await group.waitForAll()
			return true
		}
		
		try! await Task.sleep(nanoseconds: 3000000000)
		
		for _ in 1...con {
			await sem.Release()
		}
		
		let r = await group
		XCTAssertTrue(r)
	}
	
	func testSem3() async throws {
		let con = 9
		let sem = Semaphore(permits: 3)
		
		async let group = withTaskGroup(of: Void.self, returning: Bool.self) { group in
			for _ in 1...con {
				group.addTask {
					let err = await sem.AcquireOrErr()
					XCTAssertNil(err)
				}
			}
			
			await group.waitForAll()
			return true
		}
		
		try! await Task.sleep(nanoseconds: 3000000000)
		
		for _ in 1...con/3 + 1 {
			await sem.Release(3)
		}
		
		let r = await group
		XCTAssertTrue(r)
	}
	
	func testSemRelease() async throws {
		let sem = Semaphore(permits: 5)
		await sem.Release()
		await sem.Release()
		let ava = await sem.AvailablePermits
		XCTAssertEqual(sem.Permits, ava)
	}
	
	func testSemRelease3() async throws {
		let sem = Semaphore(permits: 5)
		await sem.Release(3)
		let ava = await sem.AvailablePermits
		XCTAssertEqual(sem.Permits, ava)
	}
	
	func testSemCancel() async throws {
		let con = 9
		let sem = Semaphore(permits: 3)
		
		async let group = withTaskGroup(of: Void.self, returning: Bool.self) { group in
			for _ in 0 ..< 3 {
				group.addTask {
					let err = await sem.AcquireOrErr()
					XCTAssertNil(err)
				}
			}
			
			try! await Task.sleep(nanoseconds: 1000000000)
			
			for _ in 3 ..< con {
				group.addTask {
					let err = await sem.AcquireOrErr()
					XCTAssertNotNil(err)
				}
			}
			
			try! await Task.sleep(nanoseconds: 1000000000)
			
			group.cancelAll()
			
			await group.waitForAll()
			return true
		}
		
		let r = await group
		XCTAssertTrue(r)
	}
	
	func testSendCloseRec() async throws {
		let ch = Channel<Bool>(buffer: 1)
		_ = try! await ch.Send(true)
		await ch.Close()
		let ret = try! await ch.Receive()
		XCTAssertNotNil(ret)
		XCTAssertEqual(ret, true)
	}
}

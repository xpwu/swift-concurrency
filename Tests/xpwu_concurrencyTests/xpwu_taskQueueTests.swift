//
//  xpwu_taskQueueTests.swift
//  xpwu_concurrency
//
//  Created by xpwu on 2025/6/23.
//

import XCTest
import xpwu_x
@testable import xpwu_concurrency

class Runner {
	var index = 0
}

final class xpwu_taskQueueTests: XCTestCase {
	func testInit() async throws {
		_ = TaskQueue {
			Runner()
		}
		
		XCTAssertTrue(true)
	}
	
	func testClose() async throws {
		let queue = TaskQueue {
			Runner()
		}
		
		await queue.close { runner in
			
		}
		
		await queue.close { runner in
			
		}
		
		XCTAssertTrue(true)
	}
	
	func testEn() async throws {
		let queue = TaskQueue {
			Runner()
		}
		var index = 0
		var ret = await queue.en { runner in
			runner.index += 1
			return runner.index
		}
		XCTAssertNoThrow(index = try ret.get())
		XCTAssertTrue(index == 1)
		
		ret = await queue.en { runner in
			runner.index += 1
			return runner.index
		}
		XCTAssertNoThrow(index = try ret.get())
		XCTAssertTrue(index == 2)
		
		await queue.close { runner in
			XCTAssertEqual(2, runner.index)
		}
		
		await queue.close { runner in
			XCTExpectFailure()
		}
		
		ret = await queue.en { runner in
			runner.index += 1
			return runner.index
		}
		if case .failure(let failure) = ret {
			XCTAssertTrue(failure is TaskQueueClosed)
		} else {
			XCTExpectFailure()
		}
		
	}
}

//
//  File.swift
//  
//
//  Created by xpwu on 2024/9/25.
//

import Foundation

actor semaphore {
	let acquireSuspend: queue<@Sendable ()->Void> = queue()
	let max: Int
	var current: Int = 0
	
	var availablePermits:Int {
		get {
			max - current
		}
	}
	
	init(max: Int) {
		self.max = [max, 1].max()!
	}
	
	// nil: not suspend
	func tryAcquire(_ waiting: @escaping @Sendable ()->Void) -> node<@Sendable ()->Void>? {
		if (current < max) {
			current += 1
			return nil
		}
		
		return acquireSuspend.en(waiting)
	}
	
	func cancel(_ n: node<@Sendable ()->Void>) {
		n.inValid()
	}
	
	func release() {
		if let d = acquireSuspend.de() {
			d()
			return
		}
		
		// de() == nil
		current -= 1
		assert(current >= 0)
	}
	
	func releaseAll() {
		while let d = acquireSuspend.de() {
			d()
		}
		current = 0
	}
}

public final class Semaphore: Sendable {
	let sem: semaphore
	public let Permits: Int
	public var AvailablePermits: Int {
		get async {
			await sem.availablePermits
		}
	}
	
	public init(permits: Int) {
		self.Permits = permits
		self.sem = semaphore(max: max(1, permits))
	}
}

public extension Semaphore {
	// Error: CancellationError
	func AcquireOrErr() async -> Error? {
		let cancer = canceler()
		
		return await withTaskCancellationHandler {
			return await withCheckedContinuation({ (continuation: CheckedContinuation<Error?, Never>) in
				
				let resumeF = {(_ err: Error?)async ->Void in
					if !(await cancer.resumedAndOld()) {
						continuation.resume(returning: err)
					}
				}
				
				Task {
					let node = await sem.tryAcquire {
						Task {
							await resumeF(nil)
						}
					}
					
					// not suspend
					guard let node else {
						await resumeF(nil)
						return
					}
					
					let success = await cancer.suspend {
						await self.sem.cancel(node)
						await resumeF( CancellationError())
					}
					// 失败，立即执行
					if !success {
						await self.sem.cancel(node)
						await resumeF( CancellationError())
					}
				}
			})
		} onCancel: {
			Task {
				if let suspend = await cancer.cancel() {
					await suspend()
				}
			}
		}
	}
	
	func Acquire() async throws/*(CancellationError)*/ {
		let err = await AcquireOrErr()
		switch err {
		case let err as CancellationError:
			throw err
		default:
			break
		}
	}
	
	func Release() async {
		await sem.release()
	}
	
	func ReleaseAll() async {
		await sem.releaseAll()
	}
}

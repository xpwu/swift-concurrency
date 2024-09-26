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
		self.max = max
	}
	
	func tryAcquire(_ waiting: @escaping @Sendable ()->Void) -> Bool {
		if (current < max) {
			current += 1
			return true
		}
		
		acquireSuspend.en(waiting)
		return false
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

public class Semaphore {
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
	func Acquire() async {
		await withCheckedContinuation({ (continuation: CheckedContinuation<Void, Never>) in
			Task {
				let success = await sem.tryAcquire {
					continuation.resume()
				}
				
				if success {
					continuation.resume()
				}
			}
		})
	}
	
	func Release() async {
		await sem.release()
	}
	
	func ReleaseAll() async {
		await sem.releaseAll()
	}
}

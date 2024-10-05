//
//  File.swift
//  
//
//  Created by xpwu on 2024/9/25.
//

import Foundation
import xpwu_x

public struct TimeoutError: Error {
	public init(){}
}

// Error: TimeoutError or CancellationError
public func withTimeoutOrFailed<R: Sendable>(_ duration: Duration
																							 , _ body:@escaping () async -> R) async -> Result<R, Error> {
	
	return await withTaskGroup(of: Result<R, Error>.self) { group in
		group.addTask {
			do {
				try await Task.sleep(nanoseconds: duration.microSecond()*1000)
			} catch {
				return .failure(CancellationError())
			}
			
			return .failure(TimeoutError())
		}
		group.addTask {
			return .success(await body())
		}
		
		// group is not empty!
		let ret = await group.next()!
		
		if group.isCancelled {
			return .failure(CancellationError())
		}
		group.cancelAll()
		
		return ret
	}
}

// return nil: timeout or else error
public func withTimeout<R: Sendable>(_ duration: Duration, _ body:@escaping () async -> R) async -> R? {
	switch await withTimeoutOrFailed(duration, body) {
	case .success(let ret):
		return ret
	default:
		return nil
	}
}


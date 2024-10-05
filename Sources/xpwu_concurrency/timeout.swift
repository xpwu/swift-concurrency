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

// return nil: timeout
public func withTimeoutOrNil<R: Sendable>(_ duration: Duration
																		 , _ body:@escaping () async throws/*(CancellationError)*/ -> R) async throws/*(CancellationError)*/ -> R? {
	let ret = await withTimeoutOrFailed(duration) { () async -> R? in
		do {
			return try await body()
		}catch {
			// CancellationError
			return nil
		}
	}
	
	switch ret {
	case .success(let ret):
		if let ret {
			return ret
		}
		throw CancellationError()
	case .failure(let err):
		switch err {
		case let e as CancellationError:
			throw e
		default:
			return nil
		}
	}
}

public func withTimeout<R: Sendable>(_ duration: Duration
																		 , _ body:@escaping () async throws/*(CancellationError)*/ -> R) async throws/*(CancellationError)*/ -> Result<R, TimeoutError> {
	let ret = try await withTimeoutOrNil(duration, body)
	if let ret {
		return .success(ret)
	}
	return .failure(TimeoutError())
}


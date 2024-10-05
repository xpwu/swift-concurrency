//
//  Created by xpwu on 2024/9/25.
//

import Foundation

public class Mutex {
	let sem = Semaphore(permits: 1)
	
	public init(){}
}

public extension Mutex {
	func Lock() async throws/*(CancellationError)*/ {
		try await sem.Acquire()
	}
	
	func LockOrErr() async -> Error? {
		await sem.AcquireOrErr()
	}
	
	func Unlock() async {
		await sem.Release()
	}
}

public extension Mutex {
	// Error: CancellationError
	func withLockOrFailed<R>(_ body: ()async ->R) async -> Result<R, Error> {
		let err = await LockOrErr()
		if let err {
			return .failure(err)
		}
		
		let ret = await body()
		await Unlock()
		
		return .success(ret)
	}
	
	// throws(CancellationError)
	func withLock<R>(_ body: ()async throws/*(CancellationError)*/ ->R)async throws/*(CancellationError)*/ -> R {
		let ret = await withLockOrFailed { ()async ->R? in
			do {
				return try await body()
			}catch {
				// CancellationError
				return nil
			}
		}
		
		switch ret {
		case .failure(_):
			throw CancellationError()
		case .success(let ret):
			if let ret {
				return ret
			}
			throw CancellationError()
		}
	}
	
	// nil: CancellationError
	func withLockOrNil<R>(_ body: ()async->R)async -> R? {
		switch await withLockOrFailed(body) {
		case .failure(_):
			return nil
		case .success(let ret):
			return ret
		}
	}
}

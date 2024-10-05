//
//  Created by xpwu on 2024/9/25.
//

import Foundation

public class Mutex {
	let sem = Semaphore(permits: 1)
	
	public init(){}
}

public extension Mutex {
	func Lock() async -> Error? {
		await sem.Acquire()
	}
	
	func Unlock() async {
		await sem.Release()
	}
}

public extension Mutex {
	// Error: CancellationError
	func withLockOrFailed<R>(_ body: ()async->R) async -> Result<R, Error> {
		let err = await Lock()
		if let err {
			return .failure(err)
		}
		
		let ret = await body()
		await Unlock()
		
		return .success(ret)
	}
	
	func withLock<R>(_ body: ()async->R) async -> R? {
		switch await withLockOrFailed(body) {
		case .failure(_):
			return nil
		case .success(let ret):
			return ret
		}
	}
}

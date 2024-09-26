//
//  Created by xpwu on 2024/9/25.
//

import Foundation

public class Mutex {
	let sem = Semaphore(permits: 1)
	
	public init(){}
}

public extension Mutex {
	func Lock() async {
		await sem.Acquire()
	}
	
	func Unlock() async {
		await sem.Release()
	}
}

public extension Mutex {
	func WithLock<R>(_ body: ()async->R) async -> R {
		await Lock()
		let ret = await body()
		await Unlock()
		
		return ret
	}
}

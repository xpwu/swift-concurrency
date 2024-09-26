//
//  File.swift
//  
//
//  Created by xpwu on 2024/9/25.
//

import Foundation
import xpwu_x

public func WithTimeout<R: Sendable>(_ duration: Duration, _ body:@escaping () async -> R) async -> R? {
	
	return await withTaskGroup(of: R?.self) { group in
		group.addTask {
			do {
				try await Task.sleep(nanoseconds: duration.microSecond()*1000)
			} catch {
				return nil
			}
			
			return nil
		}
		group.addTask {
			return await body()
		}
		
		// group is not empty!
		let ret = await group.next()!
		group.cancelAll()
		
		return ret
	}
}


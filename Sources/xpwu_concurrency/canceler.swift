//
//  File.swift
//  
//
//  Created by xpwu on 2024/10/5.
//

import Foundation

actor canceler {
	var canceled: Bool = false
	var cancelF: (()async->Void)?
	var resumed: Bool = false

	// false: 已经取消了，挂起失败
	func suspend(cancelF f: @escaping ()async ->Void)->Bool {
		cancelF = f
		return !canceled
	}
	
	func resumedAndOld()->Bool {
		let old = resumed
		resumed = true
		return old
	}
	
	// return: 已经挂起了，需要调用方执行”取消挂起“的操作
	func cancel()-> (()async->Void)? {
		canceled = true
		return cancelF
	}
}

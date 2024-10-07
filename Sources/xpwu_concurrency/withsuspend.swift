//
//  File.swift
//  
//
//  Created by xpwu on 2024/10/7.
//

import Foundation

public class Suspend<T: Sendable> {
	// 当 task cancel 时的回调函数，可以利用此函数释放资源
	public var onTaskCanceled: (() ->Void)?
	
	// 可以多次调用，但是只有第一次的调用才有效
	public func resume(returning value: T) {
		resume_(value)
	}
	
	private let resume_: (T) ->Void
	
	init(resume: @escaping (T) -> Void) {
		self.resume_ = resume
	}
}

// 如果要设置 onTaskCanceled, 必须在 block 执行结束前设置，block 执行结束后的设置都无效
// resume 的调用，可以在需要的任何地方调用，block 执行结束前，或者 block 执行结束后的其他时间点
// Suspend 只有两种结果：要么 resume, 要么 canceled by task
public func withSuspend<T: Sendable>(_ block: @escaping(Suspend<T>) async ->Void) async throws/*(CancellationError)*/ ->T {
	let cancer = canceler()
	
	let ret = await withTaskCancellationHandler {
		return await withCheckedContinuation({ (continuation: CheckedContinuation<Result<T, CancellationError>, Never>) in
			
			let resumeF = {(_ v: Result<T, CancellationError>)async ->Void in
				if !(await cancer.resumedAndOld()) {
					continuation.resume(returning: v)
				}
			}
			
			let cont = Suspend{ v in
				Task{await resumeF(.success(v))}
			}
			
			Task {
				await block(cont)
				
				let success = await cancer.suspend {
					cont.onTaskCanceled?()
					await resumeF(.failure(CancellationError()))
				}
				// 失败，立即执行
				if !success {
					cont.onTaskCanceled?()
					await resumeF(.failure(CancellationError()))
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
	
	switch ret {
	case .failure(_):
		throw CancellationError()
	case .success(let v):
		return v
	}
}

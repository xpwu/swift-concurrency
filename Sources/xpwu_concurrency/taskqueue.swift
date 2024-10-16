//
//  File.swift
//  
//
//  Created by xpwu on 2024/10/16.
//

import Foundation


class tCtx {
	@TaskLocal
	static var ctx: Int = 0
}

public typealias TaskQueueClosed = ChannelClosed

typealias toClose = Bool

public class TaskQueue<Runner> {
	private var queue = Channel<(Runner?) async ->toClose>(buffer: .Unlimited)
	private var runner: Runner?
	
	public init(with runner : @escaping () async ->Runner) {
		Task {[unowned self] in
			let r = await runner()
			self.runner = r
			
			await tCtx.$ctx.withValue(1) {
				while true {
					switch await queue.ReceiveOrFailed() {
					case .failure(_):
						break
					case .success(let task):
						let toClose = await task(self.runner)
						if toClose {
							await queue.Close()
							self.runner = nil
						}
					}
				}
			}
		}
	}
}

extension TaskQueue {
	// Error: TaskQueueClosed|CancellationError
	public func en<R>(_ task: @escaping (Runner) async ->R) async -> Result<R, Error> {
		// process nest
		// 此时的执行协程必定是 TaskQueue 内部自建的协程，所以不存在资源竞争问题
		if tCtx.ctx == 1 {
			guard let runner = self.runner else {
				return .failure(TaskQueueClosed())
			}
			return .success(await task(runner))
		}
		
		let ch = Channel<Result<R, Error>>(buffer: 1)
		
		let err = await queue.SendOrErr{runner in
			// 内建 Task 必定没有取消，ch 也没关闭
			guard let runner else {
				// TaskQueue closed.
				_ = await ch.SendOrErr(.failure(TaskQueueClosed()))
				return false
			}
			_ = await ch.SendOrErr(.success(await task(runner)))
			return false
		}
		if let err {
			return .failure(err)
		}
		
		let ret = await ch.ReceiveOrFailed()
		switch ret {
		case .success(let r):
			return r
		case .failure(let e):
			return .failure(e)
		}
	}
	
	public func close(runner close: @escaping (Runner)->Void) async {
		_ = await queue.SendOrErr { runner in
			close(runner!)
			return true
		}
	}
}

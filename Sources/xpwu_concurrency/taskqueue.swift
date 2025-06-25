//
//  taskqueue.swift
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

actor RunnerActor<Runner> {
	private var value: Runner? = nil
	
	public func set(_ v: Runner?) {
		value = v
	}
	
	public func get()-> Runner? {
		return value
	}
}

public final class TaskQueue<Runner>: Sendable {
	private let queue = Channel<@Sendable (Runner?) async -> Void>(buffer: .Unlimited)
	private let runner: RunnerActor = RunnerActor<Runner>()
	
	/**
	 init.Task 与 deinit.Task 不捕获 self(TaskQueue)，TaskQueue 的生命周期由调用方决定。
	 即使 TaskQueue 已释放，也需要确保已经放入 queue 中的任务能执行完，所以强捕获了 self.queue 及 self.runner。
	 为确保 self.queue 等能释放，所以在 deinit 中执行 queue.Close()。
	 */
	
	public init(with runner : @escaping () async ->Runner) {
		let queue = self.queue
		let selfRunner = self.runner
		Task {
			await selfRunner.set(await runner())
			
			await tCtx.$ctx.withValue(1) {
				var loop = true
				while loop {
					switch await queue.ReceiveOrFailed() {
					case .failure(_):
						loop = false
					case .success(let task):
						await task(await selfRunner.get())
					}
				}
			}
		}
	}
	
	deinit {
		let queue = self.queue
		// 无论是否已经 close()，都再执行 queue.Close()，确保 queue 能正常退出
		Task {
			await queue.Close()
		}
	}
}

extension TaskQueue {
	// Error: TaskQueueClosed|CancellationError
	public func en<R>(_ task: @escaping (Runner) async ->R) async -> Result<R, Error> {
		// process nest
		if tCtx.ctx == 1 {
			guard let runner = await self.runner.get() else {
				return .failure(TaskQueueClosed())
			}
			return .success(await task(runner))
		}
		
		let ch = Channel<Result<R, Error>>(buffer: 1)
		
		let err = await queue.SendOrErr{runner in
			// 内建 Task 必定没有取消，ch 也没关闭
			if let runner {
				_ = await ch.SendOrErr(.success(await task(runner)))
			} else {
				// TaskQueue closed.
				_ = await ch.SendOrErr(.failure(TaskQueueClosed()))
			}
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
	
	//可多次执行，但是只有第一次才会回调 'close: @escaping (Runner)->Void' 函数
	public func close(runner close: @escaping (Runner)async->Void) async {
		let ch = Channel<Void>(buffer: 1)
		
		let queue = self.queue
		let selfRunner = self.runner
		let err = await queue.SendOrErr { runner in
			// 第一次执行 TaskQueue.close，也只有第一次才会回调 'close: @escaping (Runner)->Void' 函数。
			if let runner {
				await close(runner)
				// 所有在 close 执行后的排队任务，都返回 TaskQueueClosed, 所以 self.runner = nil (见 TaskQueue.en() 的逻辑)
				await selfRunner.set(nil)
			}
			
			_ = await ch.SendOrErr(())
		}
		// 必须先加入上面的 close 任务后，才能执行 queue.Close()
		await queue.Close()
		
		// 没有加入成功，立即返回
		if err != nil {
			return
		}
		
		_ = await ch.ReceiveOrFailed()
	}
}

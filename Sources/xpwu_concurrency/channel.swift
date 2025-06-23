//
//
//  Created by xpwu on 2024/9/25.
//

import Foundation

public struct ChannelClosed: Error {
	public var msg: String = ""
}

public protocol SendChannel<E>: Sendable {
	associatedtype E: Sendable
	// Error: ChannelClosed or CancellationError
	func SendOrErr(_ e: E) async ->Error?
	func Close(reason: String) async
}

public extension SendChannel {
	func Send() async throws/*(CancellationError)*/ -> ChannelClosed? where E == Void {
		try await Send(())
	}
	
	func Send(_ e: E) async throws/*(CancellationError)*/-> ChannelClosed? {
		let err = await SendOrErr(e)
		switch err {
		case let err as CancellationError:
			throw err
		case let err as ChannelClosed:
			return err
		default:
			return nil
		}
	}
	
	func Close() async {
		await Close(reason: "")
	}
}

public protocol ReceiveChannel<E>: Sendable {
	associatedtype E: Sendable
	// Error: ChannelClosed or CancellationError
	func ReceiveOrFailed() async -> Result<E, Error>
}

public extension ReceiveChannel {
	// nil: ChannelClosed or CancellationError
	func ReceiveOrNil() async -> E? {
		switch await ReceiveOrFailed() {
		case .success(let r):
			return r
		case .failure(_):
			return nil
		}
	}
	
	// nil: ChannelClosed
	func Receive() async throws/*(CancellationError)*/ -> E? {
		switch await ReceiveOrFailed() {
		case .success(let r):
			return r
		case .failure(let err):
			switch err {
			case let e as CancellationError:
				throw e
			default:
				return nil
			}
		}
	}
}

struct objectForCancel {
	let cancelF: ()->Void
}

/**
 close() 执行后，执行 sendxxx 的操作会返回失败，
			执行 receivexxx 的操作会返回 close() 之前的未被 receive 的数据，
			所有数据被 receive 完后，执行的 receivexxx 会返回失败
 */

actor channel<E: Sendable> {
	// 以下所有的数据 仅能在 actor 内操作
	let data: queue<E> = queue()
	let sendSuspend: queue<(E, (ChannelClosed?)->Void)> = queue()
	let receiveSuspend: queue<(Result<E, ChannelClosed>)->Void> = queue()
	let max: Int
	var closed: ChannelClosed?
	
	init(_ max: Int = 0) {
		self.max = max
	}
	
	func close(reason msg: String = "") {
		closed = ChannelClosed(msg: msg)
		while let s = sendSuspend.de() {
			s.1(closed)
		}
		while let r = receiveSuspend.de() {
			r(.failure(closed!))
		}
	}
	
	enum isSuspended<T> {
		case Yes(object: objectForCancel), No(todo: (()->Void)?, value: T), Failed(ChannelClosed)
	}
	
	// 不确定返回的闭包 在 actor 外执行的安全性，所以这里使用 actor 的方法来执行
	func cancel(object: objectForCancel) {
		object.cancelF()
	}
	
	func send(_ e:E, ifsuspend waiting: @escaping @Sendable (ChannelClosed?) ->Void) -> isSuspended<Void> {
		
		if let closed {
			return .Failed(closed)
		}
		
		let rfun = receiveSuspend.de()
		
		if data.count >= max &&  rfun == nil {
			let node = sendSuspend.en((e, waiting))
			return .Yes(object: objectForCancel(cancelF: {node.inValid()}))
		}
		
		// rfun != nil: data is empty
		if let rfun {
			return .No(todo: {rfun(.success(e))}, value: ())
		}
		
		// rfun == nil && data.count < max: max != 0
		_ = data.en(e)
		return .No(todo: nil, value: ())
	}
	
	func receive(ifsuspend waiting: @escaping @Sendable (Result<E, ChannelClosed>)->Void) -> isSuspended<E> {
		
		if let closed {
			// 返回 close 之前没有读取完的数据
			if let value = data.de() {
				return .No(todo: nil, value: value)
			}
			return .Failed(closed)
		}
		
		let value = data.de()
		let suspend = sendSuspend.de()
		
		if value == nil && suspend == nil {
			let node = receiveSuspend.en(waiting)
			return .Yes(object: objectForCancel(cancelF: {node.inValid()}))
		}
		
		// value != nil: max != 0
		if let value {
			var todo: (()->Void)? = nil
			if let (d, sfun) = suspend {
				_ = data.en(d)
				todo = {sfun(nil)}
			}
			return .No(todo: todo, value: value)
		}
		
		// value == nil && suspend != nil: max == 0
		let (d, sfun) = suspend!
		return .No(todo: {sfun(nil)}, value: d)
	}

}

public final class Channel<E: Sendable>: Sendable {
	let chan: channel<E>
	
	public init(buffer: Int = 0) {
		chan = channel(buffer)
	}
}

extension Int {
	public static let Unlimited: Int = Int.max
}

extension Channel: SendChannel {
	public func Close(reason: String) async {
		await chan.close(reason: reason)
	}
	
	public func SendOrErr(_ e: E) async -> Error? {
		let cancer = canceler()
		
		return await withTaskCancellationHandler {
			return await withCheckedContinuation({ (continuation: CheckedContinuation<Error?, Never>) in
				
				let resumeF = {(_ err: Error?)async ->Void in
					if !(await cancer.resumedAndOld()) {
						continuation.resume(returning: err)
					}
				}
				
				Task {
					let isSuspended = await self.chan.send(e) {err in
						Task {
							await resumeF(err)
						}
					}
					
					switch isSuspended {
					case .Failed(let err):
						await resumeF(err)
					case .No(let todo , _):
						todo?()
						await resumeF(nil)
					case .Yes(let object):
						let success = await cancer.suspend {
							await self.chan.cancel(object: object)
							await resumeF( CancellationError())
						}
						// 失败，立即执行
						if !success {
							await self.chan.cancel(object: object)
							await resumeF( CancellationError())
						}
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
	}
}

extension Channel: ReceiveChannel {
	public func ReceiveOrFailed() async -> Result<E, Error> {
		let cancer = canceler()
		
		return await withTaskCancellationHandler {
			return await withCheckedContinuation({ (continuation: CheckedContinuation<Result<E, Error>, Never>) in
				
				let resumeF = {(result: Result<E, Error>)async ->Void in
					if !(await cancer.resumedAndOld()) {
						continuation.resume(returning: result)
					}
				}
				
				Task {
					let isSuspended = await self.chan.receive {value in
						Task {
							switch value {
							case .failure(let err):
								await resumeF(.failure(err))
							case .success(let v):
								await resumeF(.success(v))
							}
						}
					}
					
					switch isSuspended {
					case .Failed(let err):
						await resumeF(.failure(err))
					case let .No(todo, value):
						todo?()
						await resumeF(.success(value))
					case .Yes(let object):
						let success = await cancer.suspend {
							await self.chan.cancel(object: object)
							await resumeF(.failure(CancellationError()))
						}
						// 失败，立即执行
						if !success {
							await self.chan.cancel(object: object)
							await resumeF(.failure(CancellationError()))
						}
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
	}
}


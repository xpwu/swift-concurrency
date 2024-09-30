//
//
//  Created by xpwu on 2024/9/25.
//

import Foundation

public struct ChannelClosed: Error {
	public var msg: String = ""
}

public protocol SendChannel<E> {
	associatedtype E: Sendable
	func SendOrFailed(_ e: E) async ->ChannelClosed?
	func Close(reason: String) async
}

public extension SendChannel {
	func Send() async where E == Void {
		await Send(())
	}
	
	func Send(_ e: E) async {
		_ = await SendOrFailed(e)
	}
	
	func Close() async {
		await Close(reason: "")
	}
}

public protocol ReceiveChannel<E> {
	associatedtype E: Sendable
	func ReceiveOrFailed() async -> Result<E, ChannelClosed>
}

public extension ReceiveChannel {
	func Receive() async -> E? {
		switch await ReceiveOrFailed() {
		case .success(let r):
			return r
		case .failure(_):
			return nil
		}
	}
}

actor channel<E: Sendable> {
	let data: queue<E> = queue()
	let sendSuspend: queue<(ChannelClosed?)->Void> = queue()
	let receiveSuspend: queue<(Result<E, ChannelClosed>)->Void> = queue()
	let max: Int
	var closed: ChannelClosed?
	
	init(_ max: Int = 0) {
		self.max = max
	}
	
	func close(reason msg: String = "") {
		closed = ChannelClosed(msg: msg)
		while let s = sendSuspend.de() {
			s(closed)
		}
		while let r = receiveSuspend.de() {
			r(.failure(closed!))
		}
	}
	
	enum isSuspended<T> {
		case Yes, No(todo: (()->Void)?, value: T), Failed(ChannelClosed)
	}
	
	func send(_ e:E, ifsuspend waiting: @escaping @Sendable (ChannelClosed?)->Void) -> isSuspended<Void> {
		
		if let closed {
			return .Failed(closed)
		}
		
		data.en(e)
		if data.count > max {
			sendSuspend.en(waiting)
			return .Yes
		}
		
		let rfun = receiveSuspend.de()
		var todo: (()->Void)? = nil
		if let rfun {
			let d = data.de()!
			todo = {rfun(.success(d))}
		}
		
		return .No(todo: todo, value: ())
	}
	
	func receive(ifsuspend waiting: @escaping @Sendable (Result<E, ChannelClosed>)->Void) -> isSuspended<E> {
		
		if let closed {
			return .Failed(closed)
		}
		
		let value = data.de()
		guard let value else {
			receiveSuspend.en(waiting)
			return .Yes
		}
		
		let sfun = sendSuspend.de()
		var todo: (()->Void)? = nil
		if let sfun {
			todo = {sfun(nil)}
		}
		
		return .No(todo: todo, value: value)
	}

}

public class Channel<E: Sendable> {
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
	
	public func SendOrFailed(_ e: E) async -> ChannelClosed? {
		return await withCheckedContinuation({ (continuation: CheckedContinuation<ChannelClosed?, Never>) in
			Task {
				let isSuspended = await self.chan.send(e) {err in
					continuation.resume(returning: err)
				}
				
				switch isSuspended {
				case .Failed(let err):
					continuation.resume(returning: err)
				case .No(let todo , _):
					todo?()
					continuation.resume(returning: nil)
				case .Yes:
					break
				}
			}
		})
	}
}

extension Channel: ReceiveChannel {
	public func ReceiveOrFailed() async -> Result<E, ChannelClosed> {
		return await withCheckedContinuation({ (continuation: CheckedContinuation<Result<E, ChannelClosed>, Never>) in
			Task {
				let isSuspended = await self.chan.receive {value in
					continuation.resume(returning: value)
				}
				
				switch isSuspended {
				case .Failed(let err):
					continuation.resume(returning: .failure(err))
				case let .No(todo, value):
					todo?()
					continuation.resume(returning: .success(value))
				case .Yes:
					break
				}
			}
		})
	}
}


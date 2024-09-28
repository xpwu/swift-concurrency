//
//
//  Created by xpwu on 2024/9/25.
//

import Foundation

public protocol SendChannel<E> {
	associatedtype E: Sendable
	func Send(_ e: E) async
}

public extension SendChannel {
	func Send() async where E == Void {
		await Send(())
	}
}

public protocol ReceiveChannel<E> {
	associatedtype E: Sendable
	func Receive() async -> E
}

actor channel<E: Sendable> {
	let data: queue<E> = queue()
	let sendSuspend: queue<()->Void> = queue()
	let receiveSuspend: queue<()->Void> = queue()
	let max: Int
	
	init(_ max: Int = 0) {
		self.max = max
	}
	
	func send(_ e:E, waiting: @escaping @Sendable ()->Void) ->(todo: (()->Void)?, needWait: Bool) {
		data.en(e)
		let todo = receiveSuspend.de()
		var needWait = false
		
		if data.count >= max {
			sendSuspend.en(waiting)
			needWait = true
		}
		
		return (todo, needWait)
	}
	
	// return if value == nil {need wait} else {not need wait}
	func receive(waiting: @escaping @Sendable (E)->Void) async ->(todo: (()->Void)?, value: E?) {
		let value = data.de()
		let todo = sendSuspend.de()
		
		if value == nil {
			receiveSuspend.en {[unowned self] in
				waiting(self.data.de()!)
			}
		}
		
		return (todo, value)
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
	
	public func Send(_ e: E) async {
		await withCheckedContinuation({ (continuation: CheckedContinuation<Void, Never>) in
			Task {
				let (todo, needWait) = await chan.send(e) {
					continuation.resume()
				}
				
				todo?()
				
				if !needWait {
					continuation.resume()
				}
			}
		})
	}
}

extension Channel: ReceiveChannel {
	public func Receive() async -> E {
		await withCheckedContinuation({ (continuation: CheckedContinuation<E, Never>) in
			Task {
				let (todo, value) = await chan.receive {value in
					continuation.resume(returning: value)
				}
				
				todo?()
				
				if let v = value {
					continuation.resume(returning: v)
				}
			}
		})
	}
}


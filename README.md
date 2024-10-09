# swift-concurrency
swift concurrency 相关的库，完全符合 concurrency 的使用

## 0、代码库的引用
使用 SwiftPM 引用此 github 库即可

## 1、Channel
```swift
protocol SendChannel<E> {
  func SendOrErr(_ e: E) async ->Error?
  func Close(reason: String) async
  func Send(_ e: E) async throws/*(CancellationError)*/-> ChannelClosed?
}

protocol ReceiveChannel<E> {
  func ReceiveOrFailed() async -> Result<E, Error>
  func ReceiveOrNil() async -> E?
  func Receive() async throws/*(CancellationError)*/ -> E?
}

class Channel<E: Sendable>: SendChannel, ReceiveChannel
```

## 2、Mutex
```swift
class Mutex {
  func Lock() async throws/*(CancellationError)*/
  func LockOrErr() async -> Error?
  func Unlock() async
  
  // Error: CancellationError
  func withLockOrFailed<R>(_ body: ()async ->R) async -> Result<R, Error>
  func withLock<R>(_ body: ()async throws/*(CancellationError)*/ ->R)async throws/*(CancellationError)*/ -> R 
  // nil: CancellationError
  func withLockOrNil<R>(_ body: ()async->R)async -> R?
}
```

## 3、Semaphore
```swift
class Semaphore {
  // Error: CancellationError
  func AcquireOrErr() async -> Error?
  func Acquire() async throws/*(CancellationError)*/
  func Release() async 
  func ReleaseAll() async
}
```

## 4、Timeout
```swift
// Error: TimeoutError or CancellationError
func withTimeoutOrFailed<R: Sendable>(_ duration: Duration, _ body:@escaping () async -> R) async -> Result<R, Error>

func withTimeoutOrNil<R: Sendable>(_ duration: Duration, _ body:@escaping () async throws/*(CancellationError)*/ -> R) async throws/*(CancellationError)*/ -> R?
func withTimeout<R: Sendable>(_ duration: Duration, _ body:@escaping () async throws/*(CancellationError)*/ -> R) async throws/*(CancellationError)*/ -> Result<R, TimeoutError>
```
[Duration](https://github.com/xpwu/swift-x/blob/master/Sources/xpwu_x/duration.swift) 来自第三方库

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
* Close() 特别说明：执行 Close() 后，所有的 Sendxxx 方法都会返回 error；
所有的 Receivexxx 方法都会先依次返回 Close() 前已加入的数据，再次调用 Receivexxx 
方法时，返回 error


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
  func Release(count=1) async 
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

## 5、TaskQueue
```swift
init(@escaping () async ->Runner)
func close(runner close: @escaping (Runner) async ->Void) async

// Error: TaskQueueClosed|CancellationError
func en<R>(_ task: @escaping (Runner) async ->R) async -> Result<R, Error>
```
* close() 说明：close() 执行后，所有的 en() 都返回 error

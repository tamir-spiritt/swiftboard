// Single-threaded WebAssembly: mutexes are no-ops (there is only one thread to exclude).
#if os(WASI)
import WASILibc

@inline(__always) public func pthread_mutex_init(_ m: UnsafeMutablePointer<pthread_mutex_t>, _ a: UnsafePointer<pthread_mutexattr_t>?) -> Int32 { 0 }
@inline(__always) public func pthread_mutex_destroy(_ m: UnsafeMutablePointer<pthread_mutex_t>) -> Int32 { 0 }
@inline(__always) public func pthread_mutex_lock(_ m: UnsafeMutablePointer<pthread_mutex_t>) -> Int32 { 0 }
@inline(__always) public func pthread_mutex_unlock(_ m: UnsafeMutablePointer<pthread_mutex_t>) -> Int32 { 0 }
@inline(__always) public func pthread_mutex_trylock(_ m: UnsafeMutablePointer<pthread_mutex_t>) -> Int32 { 0 }
#endif

#if os(WASI)
// rwlocks, thread identity: one thread, nothing to wait for
@inline(__always) public func pthread_rwlock_init(_ l: UnsafeMutablePointer<pthread_rwlock_t>, _ a: UnsafePointer<pthread_rwlockattr_t>?) -> Int32 { 0 }
@inline(__always) public func pthread_rwlock_destroy(_ l: UnsafeMutablePointer<pthread_rwlock_t>) -> Int32 { 0 }
@inline(__always) public func pthread_rwlock_rdlock(_ l: UnsafeMutablePointer<pthread_rwlock_t>) -> Int32 { 0 }
@inline(__always) public func pthread_rwlock_wrlock(_ l: UnsafeMutablePointer<pthread_rwlock_t>) -> Int32 { 0 }
@inline(__always) public func pthread_rwlock_tryrdlock(_ l: UnsafeMutablePointer<pthread_rwlock_t>) -> Int32 { 0 }
@inline(__always) public func pthread_rwlock_trywrlock(_ l: UnsafeMutablePointer<pthread_rwlock_t>) -> Int32 { 0 }
@inline(__always) public func pthread_rwlock_unlock(_ l: UnsafeMutablePointer<pthread_rwlock_t>) -> Int32 { 0 }
public func pthread_self() -> pthread_t { OpaquePointer(bitPattern: 1)! }
public func pthread_equal(_ a: pthread_t?, _ b: pthread_t?) -> Int32 { a == b ? 1 : 0 }
public func pthread_main_np() -> Int32 { 1 }
/// Darwin sysctl: nothing to report in the browser.
public func sysctlbyname(_ name: UnsafePointer<CChar>, _ oldp: UnsafeMutableRawPointer?, _ oldlenp: UnsafeMutablePointer<Int>?, _ newp: UnsafeMutableRawPointer?, _ newlen: Int) -> Int32 { -1 }
#endif

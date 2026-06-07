import Foundation

enum LoadingState<T> {
    case idle
    case loading
    case success(T)
    case error(message: String, canRetry: Bool)
}

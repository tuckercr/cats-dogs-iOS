import Foundation

enum LoadingState<T>: Equatable where T: Equatable {
    case idle
    case loading
    case success(T)
    case error(errorKey: String, canRetry: Bool)

    var successValue: T? {
        if case .success(let value) = self { return value }
        return nil
    }

    var errorMessage: String? {
        if case .error(let key, _) = self {
            return WeatherErrorMessages.message(for: key)
        }
        return nil
    }
}

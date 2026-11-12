import Foundation

public enum ScreenState<Value: Sendable>: Sendable {
    case loading
    case empty
    case content(Value, isRefreshing: Bool, isStale: Bool)
    case failed(message: String, retained: Value?)
    case unavailable(message: String)
}

extension ScreenState: Equatable where Value: Equatable {}

extension ScreenState: Hashable where Value: Hashable {}

extension ScreenState {
    public var value: Value? {
        switch self {
        case .content(let val, _, _):
            return val
        case .failed(_, let retained):
            return retained
        case .loading, .empty, .unavailable:
            return nil
        }
    }

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var isRefreshing: Bool {
        if case .content(_, let isRefreshing, _) = self { return isRefreshing }
        return false
    }

    public var isStale: Bool {
        if case .content(_, _, let isStale) = self { return isStale }
        return false
    }
}

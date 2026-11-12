import Foundation
import protocol Observation.Observable
import struct Observation.ObservationRegistrar

public enum ObservationSource: String, Codable, Sendable {
    case healthKit
    case user
    case derived
    case aiEstimate
    case fixture
    case legacy
}

public enum DataQuality: String, Codable, Sendable {
    case measured
    case estimated
    case stale
    case unavailable
}

public struct Observation<Value: Sendable>: Sendable {
    public let value: Value?
    public let unit: String
    public let observedAt: Date?
    public let source: ObservationSource
    public let quality: DataQuality
    public let observedCount: Int
    public let expectedCount: Int?

    public init(
        value: Value?,
        unit: String,
        observedAt: Date? = nil,
        source: ObservationSource,
        quality: DataQuality,
        observedCount: Int = 1,
        expectedCount: Int? = nil
    ) {
        self.value = value
        self.unit = unit
        self.observedAt = observedAt
        self.source = source
        self.quality = quality
        self.observedCount = observedCount
        self.expectedCount = expectedCount
    }
}

extension Observation: Equatable where Value: Equatable {}

extension Observation: Hashable where Value: Hashable {}

extension Observation: Codable where Value: Codable {}

extension Observation {
    /// Creates an observation explicitly marked as unavailable with no fabricated value.
    public static func unavailable(
        unit: String = "",
        observedAt: Date? = nil,
        source: ObservationSource = .derived,
        expectedCount: Int? = nil
    ) -> Observation<Value> {
        Observation(
            value: nil,
            unit: unit,
            observedAt: observedAt,
            source: source,
            quality: .unavailable,
            observedCount: 0,
            expectedCount: expectedCount
        )
    }

    /// Convenience property indicating if the observation contains a valid measured or estimated value.
    public var hasValue: Bool {
        value != nil
    }
}

// MARK: - SwiftData @Model Macro Compatibility Bridge
// SwiftData's @Model macro generates code referencing `Observation.Observable` and `Observation.ObservationRegistrar()`.
// When `Lifecore.Observation` is in scope, these declarations bridge macro expansion to the Apple Observation framework.
public typealias LifecoreSystemObservable = Observable
public typealias LifecoreSystemObservationRegistrar = ObservationRegistrar

extension Observation where Value == Never {
    public typealias Observable = LifecoreSystemObservable

    public static func ObservationRegistrar() -> LifecoreSystemObservationRegistrar {
        LifecoreSystemObservationRegistrar()
    }
}

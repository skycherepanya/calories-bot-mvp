import Foundation

/// Safe finite chart domain calculators for Swift Charts.
/// Guarantees non-inverted `ClosedRange<Double>`, positive padding, and exclusion of non-finite/non-positive values.
public enum ChartDomain {

    /// Computes safe Y-axis domain for body weight series.
    ///
    /// Padding rule: `max(1.5, (maxVal - minVal) * 0.1)`.
    /// Does NOT clamp to artificial physiological extremes (supports full dynamic range without clipping valid weights).
    public static func weight(_ values: [Double]) -> ClosedRange<Double>? {
        let filtered = values.filter { $0.isFinite && $0 > 0 }
        guard let minVal = filtered.min(), let maxVal = filtered.max() else {
            return nil
        }
        let padding = max(1.5, (maxVal - minVal) * 0.1)
        return (minVal - padding)...(maxVal + padding)
    }

    /// Computes safe Y-axis domain for nocturnal HRV (rMSSD / SDNN in ms).
    public static func hrvDomain(_ values: [Double]) -> ClosedRange<Double>? {
        let filtered = values.filter { $0.isFinite && $0 > 0 }
        guard let minVal = filtered.min(), let maxVal = filtered.max() else {
            return nil
        }
        let padding = max(5.0, (maxVal - minVal) * 0.1)
        let lower = max(0.0, minVal - padding)
        let upper = maxVal + padding
        if lower < upper {
            return lower...upper
        } else {
            return lower...(lower + 10.0)
        }
    }

    /// Computes safe Y-axis domain for sleeping Resting Heart Rate (bpm).
    public static func rhrDomain(_ values: [Double]) -> ClosedRange<Double>? {
        let filtered = values.filter { $0.isFinite && $0 > 0 }
        guard let minVal = filtered.min(), let maxVal = filtered.max() else {
            return nil
        }
        let padding = max(3.0, (maxVal - minVal) * 0.1)
        let lower = max(20.0, minVal - padding)
        let upper = maxVal + padding
        if lower < upper {
            return lower...upper
        } else {
            return lower...(lower + 5.0)
        }
    }

    /// Computes safe Y-axis domain for EWMA ACWR ratio.
    public static func acwrDomain(_ values: [Double]) -> ClosedRange<Double>? {
        let filtered = values.filter { $0.isFinite && $0 >= 0 }
        guard let minVal = filtered.min(), let maxVal = filtered.max() else {
            return nil
        }
        let effectiveMin = min(0.5, minVal)
        let effectiveMax = max(1.5, maxVal)
        let padding = max(0.1, (effectiveMax - effectiveMin) * 0.05)
        let lower = max(0.0, effectiveMin - padding)
        let upper = effectiveMax + padding
        if lower < upper {
            return lower...upper
        } else {
            return 0.0...2.0
        }
    }

    /// Computes safe Y-axis domain for Aerobic Efficiency (m/min per bpm).
    public static func aerobicEfficiencyDomain(_ values: [Double]) -> ClosedRange<Double>? {
        let filtered = values.filter { $0.isFinite && $0 > 0 }
        guard let minVal = filtered.min(), let maxVal = filtered.max() else {
            return nil
        }
        let padding = max(0.08, (maxVal - minVal) * 0.1)
        let lower = max(0.1, minVal - padding)
        let upper = maxVal + padding
        if lower < upper {
            return lower...upper
        } else {
            return lower...(lower + 0.2)
        }
    }
}

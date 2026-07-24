import os

/// Structured logging — the on-device half of monitoring.
///
/// os.Logger streams into Console.app and sysdiagnoses, and is what crash and
/// observability tooling (MetricKit, Sentry, …) hooks into in production.
/// Two rules for a health app:
/// - Log *events and metrics*, never *content*: a sharpness score is fine,
///   an intake answer is not.
/// - Anything dynamic is `.private` by default; only values that are provably
///   not personal are marked `.public`.
enum Log {
    private static let subsystem = "com.philippegodfroy.HealthIntake"

    static let scan = Logger(subsystem: subsystem, category: "scan")
    static let engine = Logger(subsystem: subsystem, category: "engine")
    static let consent = Logger(subsystem: subsystem, category: "consent")
}

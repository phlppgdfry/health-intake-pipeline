import Foundation

/// The clinical sign-off gate.
///
/// Principle: anything that shows advice goes live only after clinical
/// sign-off. The gate makes that rule a type, not a convention — the UI cannot
/// render an `AdviceResponse` directly, only a `ReleasedAdvice`, and the sole
/// way to obtain one is through this gate.
enum SignOffGate {
    /// Advice that passed the gate. The `fileprivate` initializer is the whole
    /// point: no other code path can construct one.
    struct ReleasedAdvice: Equatable {
        let summary: String
        let recommendations: [String]

        fileprivate init(summary: String, recommendations: [String]) {
            self.summary = summary
            self.recommendations = recommendations
        }
    }

    enum Verdict: Equatable {
        case released(ReleasedAdvice)
        /// Advice exists but has not been clinically approved — the UI shows a
        /// waiting state and never the content.
        case withheld
    }

    /// Gates on `clinicallyApproved` first, not on nil-checks: even a
    /// response that happens to carry non-nil content stays withheld unless
    /// approved. The nil-guard below is defense in depth against an
    /// inconsistent server response, not the primary rule.
    static func evaluate(_ response: AdviceResponse) -> Verdict {
        guard response.clinicallyApproved,
              let summary = response.summary,
              let recommendations = response.recommendations else {
            return .withheld
        }
        return .released(ReleasedAdvice(summary: summary, recommendations: recommendations))
    }
}

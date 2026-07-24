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

        fileprivate init(_ response: AdviceResponse) {
            summary = response.summary
            recommendations = response.recommendations
        }
    }

    enum Verdict: Equatable {
        case released(ReleasedAdvice)
        /// Advice exists but has not been clinically approved — the UI shows a
        /// waiting state and never the content.
        case withheld
    }

    static func evaluate(_ response: AdviceResponse) -> Verdict {
        response.clinicallyApproved ? .released(ReleasedAdvice(response)) : .withheld
    }
}

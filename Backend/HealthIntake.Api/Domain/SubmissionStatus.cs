namespace HealthIntake.Api.Domain;

/// Server-side clinical gate: advice content only leaves the API once a
/// submission reaches Approved. PendingReview and Rejected both withhold it.
public enum SubmissionStatus
{
    PendingReview,
    Approved,
    Rejected,
}

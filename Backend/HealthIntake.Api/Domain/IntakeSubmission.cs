namespace HealthIntake.Api.Domain;

/// One intake + scan, its generated advice, and its review status.
///
/// `Summary`/`Recommendations` are generated and stored at creation time (see
/// `AdviceGenerator`) so review is instant, but they are only ever handed
/// back to a client once `Status == Approved` — enforced in the controller's
/// mapping to `IntakeSubmissionResponse`, not by omitting them from storage.
public class IntakeSubmission
{
    public Guid Id { get; set; }
    /// Client-supplied idempotency key (fase 3) — a retried or replayed
    /// offline-queue submission with the same key returns the existing
    /// submission instead of creating a duplicate. Null for requests sent
    /// without an `Idempotency-Key` header.
    public string? ClientRequestId { get; set; }
    public List<IntakeAnswerRecord> Answers { get; set; } = [];
    public double ScanSharpness { get; set; }
    public SubmissionStatus Status { get; set; } = SubmissionStatus.PendingReview;
    public string Summary { get; set; } = string.Empty;
    public List<string> Recommendations { get; set; } = [];
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? ReviewedAt { get; set; }
}

public class IntakeAnswerRecord
{
    public string QuestionId { get; set; } = string.Empty;
    public string Answer { get; set; } = string.Empty;
}

using HealthIntake.Api.Domain;

namespace HealthIntake.Api.Dtos;

/// `Summary`/`Recommendations` are `null` and `ClinicallyApproved` is `false`
/// unless the submission's `Status` is `Approved` — the server-side clinical
/// gate. See `IntakeSubmissionsController.ToResponse`. `Answers`/
/// `ScanSharpness` are always included — unlike advice, the raw intake isn't
/// gated, and a clinician reviewing a `PendingReview` submission needs to see
/// what was submitted.
public record IntakeSubmissionResponse(
    Guid Id,
    SubmissionStatus Status,
    List<IntakeAnswerDto> Answers,
    double ScanSharpness,
    string? Summary,
    List<string>? Recommendations,
    bool ClinicallyApproved,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ReviewedAt);

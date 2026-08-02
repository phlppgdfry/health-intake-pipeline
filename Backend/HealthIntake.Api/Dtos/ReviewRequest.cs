namespace HealthIntake.Api.Dtos;

/// Fase 1's fundament for the fase 4 clinical review flow: a clinician (or,
/// for now, whoever calls this endpoint) approves or rejects a submission.
public record ReviewRequest(bool Approve);

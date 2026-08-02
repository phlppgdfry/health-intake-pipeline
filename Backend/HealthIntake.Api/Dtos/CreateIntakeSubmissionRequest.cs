using System.ComponentModel.DataAnnotations;

namespace HealthIntake.Api.Dtos;

/// Mirrors the iOS app's `AdviceRequest` (App/Engine/APIClient.swift) field
/// for field, so wiring the app to this API is a JSON-mapping exercise, not
/// a redesign.
public record CreateIntakeSubmissionRequest(
    [Required, MinLength(1, ErrorMessage = "At least one answer is required.")]
    List<IntakeAnswerDto> Answers,
    [Range(0, double.MaxValue, ErrorMessage = "scanSharpness must be non-negative.")]
    double ScanSharpness);

public record IntakeAnswerDto(
    [Required] string QuestionId,
    [Required] string Answer);

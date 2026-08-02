using HealthIntake.Api.Auth;
using HealthIntake.Api.Data;
using HealthIntake.Api.Domain;
using HealthIntake.Api.Dtos;
using HealthIntake.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HealthIntake.Api.Controllers;

[ApiController]
[Route("api/intake-submissions")]
public class IntakeSubmissionsController(
    HealthIntakeDbContext db,
    IAdviceGenerator adviceGenerator,
    TimeProvider timeProvider,
    ILogger<IntakeSubmissionsController> logger) : ControllerBase
{
    /// Idempotent on `Idempotency-Key`: a retried or offline-queue-replayed
    /// request with a key already seen returns the existing submission
    /// instead of creating a duplicate — a client-side network error never
    /// tells the caller whether the server actually received the request.
    [HttpPost]
    public async Task<ActionResult<IntakeSubmissionResponse>> Create(
        CreateIntakeSubmissionRequest request, CancellationToken cancellationToken)
    {
        var clientRequestId = Request.Headers["Idempotency-Key"].FirstOrDefault();

        if (!string.IsNullOrEmpty(clientRequestId))
        {
            var existing = await db.IntakeSubmissions
                .FirstOrDefaultAsync(s => s.ClientRequestId == clientRequestId, cancellationToken);
            if (existing is not null)
            {
                return CreatedAtAction(nameof(GetById), new { id = existing.Id }, ToResponse(existing));
            }
        }

        var answers = request.Answers
            .Select(a => new IntakeAnswerRecord { QuestionId = a.QuestionId, Answer = a.Answer })
            .ToList();

        var (summary, recommendations) = adviceGenerator.Generate(answers, request.ScanSharpness);

        var submission = new IntakeSubmission
        {
            Id = Guid.NewGuid(),
            ClientRequestId = clientRequestId,
            Answers = answers,
            ScanSharpness = request.ScanSharpness,
            Status = SubmissionStatus.PendingReview,
            Summary = summary,
            Recommendations = recommendations,
            CreatedAt = timeProvider.GetUtcNow(),
        };

        db.IntakeSubmissions.Add(submission);

        try
        {
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException) when (!string.IsNullOrEmpty(clientRequestId))
        {
            // Lost a race with a concurrent request carrying the same key —
            // the unique index rejected our insert. Return the winner.
            db.Entry(submission).State = EntityState.Detached;
            var winner = await db.IntakeSubmissions
                .FirstAsync(s => s.ClientRequestId == clientRequestId, cancellationToken);
            logger.LogInformation(
                "Submission {SubmissionId} already existed for this idempotency key", winner.Id);
            return CreatedAtAction(nameof(GetById), new { id = winner.Id }, ToResponse(winner));
        }

        // Never log `answers`/`summary` — health data, not diagnostic data.
        logger.LogInformation("Created submission {SubmissionId}", submission.Id);
        return CreatedAtAction(nameof(GetById), new { id = submission.Id }, ToResponse(submission));
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<IntakeSubmissionResponse>> GetById(Guid id, CancellationToken cancellationToken)
    {
        var submission = await db.IntakeSubmissions.FindAsync([id], cancellationToken);
        return submission is null ? NotFound() : ToResponse(submission);
    }

    /// Clinician-only: exposes every patient's answers.
    [HttpGet]
    [TypeFilter(typeof(ApiKeyAuthFilter))]
    public async Task<ActionResult<List<IntakeSubmissionResponse>>> List(CancellationToken cancellationToken)
    {
        var submissions = await db.IntakeSubmissions
            .OrderByDescending(s => s.CreatedAt)
            .ToListAsync(cancellationToken);
        return submissions.Select(ToResponse).ToList();
    }

    /// Clinician-only: the actual gate-keeping action.
    [HttpPatch("{id:guid}/review")]
    [TypeFilter(typeof(ApiKeyAuthFilter))]
    public async Task<ActionResult<IntakeSubmissionResponse>> Review(
        Guid id, ReviewRequest request, CancellationToken cancellationToken)
    {
        var submission = await db.IntakeSubmissions.FindAsync([id], cancellationToken);
        if (submission is null)
        {
            return NotFound();
        }

        submission.Status = request.Approve ? SubmissionStatus.Approved : SubmissionStatus.Rejected;
        submission.ReviewedAt = timeProvider.GetUtcNow();
        await db.SaveChangesAsync(cancellationToken);

        logger.LogInformation(
            "Submission {SubmissionId} reviewed: {Status}", submission.Id, submission.Status);
        return ToResponse(submission);
    }

    /// The server-side clinical gate: advice content is withheld from the
    /// response for anything short of `Approved`, regardless of what is
    /// stored — mirrors the rule the iOS app's `SignOffGate` enforces
    /// client-side, but here it is the actual source of truth.
    private static IntakeSubmissionResponse ToResponse(IntakeSubmission submission)
    {
        var approved = submission.Status == SubmissionStatus.Approved;
        return new IntakeSubmissionResponse(
            submission.Id,
            submission.Status,
            submission.Answers.Select(a => new IntakeAnswerDto(a.QuestionId, a.Answer)).ToList(),
            submission.ScanSharpness,
            approved ? submission.Summary : null,
            approved ? submission.Recommendations : null,
            approved,
            submission.CreatedAt,
            submission.ReviewedAt);
    }
}

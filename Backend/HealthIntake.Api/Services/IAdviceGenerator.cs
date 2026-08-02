using HealthIntake.Api.Domain;

namespace HealthIntake.Api.Services;

public interface IAdviceGenerator
{
    (string Summary, List<string> Recommendations) Generate(IReadOnlyList<IntakeAnswerRecord> answers, double scanSharpness);
}

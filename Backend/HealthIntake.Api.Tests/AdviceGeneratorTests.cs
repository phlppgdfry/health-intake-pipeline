using HealthIntake.Api.Domain;
using HealthIntake.Api.Services;

namespace HealthIntake.Api.Tests;

public class AdviceGeneratorTests
{
    [Fact]
    public void Generate_SummaryReflectsAnswerCountAndSharpness()
    {
        var generator = new AdviceGenerator();
        var answers = new List<IntakeAnswerRecord>
        {
            new() { QuestionId = "reason", Answer = "Skin concern" },
            new() { QuestionId = "duration", Answer = "A few weeks" },
        };

        var (summary, recommendations) = generator.Generate(answers, 42.9);

        Assert.Contains("2 answers", summary);
        Assert.Contains("42", summary);
        Assert.NotEmpty(recommendations);
    }

    [Fact]
    public void Generate_WithNoAnswers_StillProducesRecommendations()
    {
        var generator = new AdviceGenerator();

        var (summary, recommendations) = generator.Generate([], 0);

        Assert.Contains("0 answers", summary);
        Assert.NotEmpty(recommendations);
    }
}

using HealthIntake.Api.Domain;

namespace HealthIntake.Api.Services;

/// Deterministic stand-in for a real advice engine — mirrors the tone of the
/// iOS app's `MockAdviceAPI` so the two are easy to compare while the iOS app
/// still talks to its mock (fase 2 wires the app to this API instead).
/// Content is generated at submission time regardless of review outcome; the
/// clinical gate that withholds it lives in the controller, not here.
public class AdviceGenerator : IAdviceGenerator
{
    public (string Summary, List<string> Recommendations) Generate(
        IReadOnlyList<IntakeAnswerRecord> answers, double scanSharpness)
    {
        var summary =
            $"Based on your {answers.Count} answers and a scan with sharpness {(int)scanSharpness}, here is your personal advice.";

        var recommendations = new List<string>
        {
            "Keep a short daily log of your symptoms for two weeks.",
            "Discuss the scan result during your next consultation.",
            "Re-scan in the app if the concern changes visibly.",
        };

        return (summary, recommendations);
    }
}

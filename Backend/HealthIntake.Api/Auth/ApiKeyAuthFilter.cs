using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace HealthIntake.Api.Auth;

/// Protects clinician-only endpoints (the submission list and the review
/// action) with a shared API key sent as `X-Api-Key`. Deliberately not on
/// `Create`/`GetById` — those are called by the iOS app on behalf of a
/// patient, which has no login system in this demo; the list and review
/// endpoints expose *every* patient's answers, which is the actual data a
/// clinician-only boundary needs to protect.
///
/// A shared static key is a demo-appropriate stand-in, not a real auth
/// system: no per-clinician identity, no expiry, no revocation. A real
/// deployment would use ASP.NET Core Identity, OAuth, or similar.
public class ApiKeyAuthFilter(IConfiguration configuration) : IAuthorizationFilter
{
    public const string HeaderName = "X-Api-Key";

    public void OnAuthorization(AuthorizationFilterContext context)
    {
        var expectedKey = configuration["Clinician:ApiKey"];
        if (string.IsNullOrEmpty(expectedKey))
        {
            // Fail closed: an unconfigured server should refuse clinician
            // access rather than silently allow it.
            context.Result = new StatusCodeResult(StatusCodes.Status500InternalServerError);
            return;
        }

        if (!context.HttpContext.Request.Headers.TryGetValue(HeaderName, out var providedKey)
            || !FixedTimeEquals(providedKey.ToString(), expectedKey))
        {
            context.Result = new UnauthorizedResult();
        }
    }

    /// A plain `!=` leaks how many leading characters matched through
    /// response-time differences — cheap to avoid, so avoid it.
    private static bool FixedTimeEquals(string provided, string expected)
    {
        var providedBytes = Encoding.UTF8.GetBytes(provided);
        var expectedBytes = Encoding.UTF8.GetBytes(expected);
        return providedBytes.Length == expectedBytes.Length
            && CryptographicOperations.FixedTimeEquals(providedBytes, expectedBytes);
    }
}

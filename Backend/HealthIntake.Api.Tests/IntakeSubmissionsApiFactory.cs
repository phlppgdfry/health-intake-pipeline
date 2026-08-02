using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace HealthIntake.Api.Tests;

/// Boots the real app (Development environment, so `Program.cs` migrates the
/// database on startup) against a dedicated test database — separate from
/// the one used for manual/Swagger testing so the two don't share state.
/// Requires `docker compose up -d` in `Backend/` to be running.
public class IntakeSubmissionsApiFactory : WebApplicationFactory<Program>
{
    public const string ApiKey = "test-clinician-key";

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");
        builder.UseSetting(
            "ConnectionStrings:HealthIntakeDb",
            "Host=localhost;Port=5544;Database=healthintake_test;Username=healthintake;Password=healthintake");
        builder.UseSetting("Clinician:ApiKey", ApiKey);
    }
}

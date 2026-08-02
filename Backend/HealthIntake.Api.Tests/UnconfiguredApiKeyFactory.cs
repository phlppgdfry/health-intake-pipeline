using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace HealthIntake.Api.Tests;

/// Same as `IntakeSubmissionsApiFactory`, but deliberately blanks out
/// `Clinician:ApiKey` (appsettings.Development.json ships a dev default, so
/// omitting the override wouldn't actually be "unconfigured") — verifies
/// `ApiKeyAuthFilter` fails closed (500, not a silent pass-through) when the
/// server itself is misconfigured.
public class UnconfiguredApiKeyFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");
        builder.UseSetting(
            "ConnectionStrings:HealthIntakeDb",
            "Host=localhost;Port=5544;Database=healthintake_test;Username=healthintake;Password=healthintake");
        builder.UseSetting("Clinician:ApiKey", "");
    }
}

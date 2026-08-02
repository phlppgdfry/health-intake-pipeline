using System.Net;

namespace HealthIntake.Api.Tests;

public class ApiKeyAuthFilterTests(UnconfiguredApiKeyFactory factory) : IClassFixture<UnconfiguredApiKeyFactory>
{
    [Fact]
    public async Task List_WithNoConfiguredKey_FailsClosed()
    {
        var response = await factory.CreateClient().GetAsync("/api/intake-submissions");

        Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);
    }
}

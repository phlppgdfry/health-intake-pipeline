using System.Net;

namespace HealthIntake.Api.Tests;

public class HealthEndpointTests(IntakeSubmissionsApiFactory factory) : IClassFixture<IntakeSubmissionsApiFactory>
{
    [Fact]
    public async Task Health_IsReachableWithoutApiKey()
    {
        var response = await factory.CreateClient().GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("Healthy", await response.Content.ReadAsStringAsync());
    }
}

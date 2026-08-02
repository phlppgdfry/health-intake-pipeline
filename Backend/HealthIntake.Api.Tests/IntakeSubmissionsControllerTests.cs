using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using HealthIntake.Api.Domain;
using HealthIntake.Api.Dtos;

namespace HealthIntake.Api.Tests;

public class IntakeSubmissionsControllerTests(IntakeSubmissionsApiFactory factory)
    : IClassFixture<IntakeSubmissionsApiFactory>
{
    private readonly IntakeSubmissionsApiFactory _factory = factory;
    private readonly HttpClient _client = MakeAuthenticatedClient(factory);

    private static HttpClient MakeAuthenticatedClient(IntakeSubmissionsApiFactory factory)
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Api-Key", IntakeSubmissionsApiFactory.ApiKey);
        return client;
    }

    // Matches the server's JsonStringEnumConverter (Program.cs) so `status`
    // round-trips as "PendingReview"/"Approved"/"Rejected" instead of failing
    // to parse against the client's numeric-enum defaults.
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter() },
    };

    private static readonly object SampleRequest = new
    {
        answers = new[] { new { questionId = "reason", answer = "Skin concern" } },
        scanSharpness = 42.0,
    };

    [Fact]
    public async Task Create_WithholdsAdviceUntilApproved()
    {
        var createResponse = await _client.PostAsJsonAsync("/api/intake-submissions", SampleRequest);
        createResponse.EnsureSuccessStatusCode();

        var created = await createResponse.Content.ReadFromJsonAsync<IntakeSubmissionResponse>(JsonOptions);

        Assert.NotNull(created);
        Assert.Equal(SubmissionStatus.PendingReview, created!.Status);
        Assert.Null(created.Summary);
        Assert.Null(created.Recommendations);
        Assert.False(created.ClinicallyApproved);
        // Unlike advice, the raw intake isn't gated — a reviewer needs to
        // see it before a submission is even approved.
        Assert.Equal("reason", created.Answers.Single().QuestionId);
        Assert.Equal(42.0, created.ScanSharpness);
    }

    [Fact]
    public async Task Review_Approve_ReleasesAdvice()
    {
        var created = await CreateSubmission();

        var reviewResponse = await PatchReview(created.Id, approve: true);
        reviewResponse.EnsureSuccessStatusCode();

        var reviewed = await reviewResponse.Content.ReadFromJsonAsync<IntakeSubmissionResponse>(JsonOptions);

        Assert.Equal(SubmissionStatus.Approved, reviewed!.Status);
        Assert.False(string.IsNullOrEmpty(reviewed.Summary));
        Assert.NotEmpty(reviewed.Recommendations!);
        Assert.True(reviewed.ClinicallyApproved);
        Assert.NotNull(reviewed.ReviewedAt);

        // `List<string>` breaks record structural equality (reference-only),
        // so compare fields rather than the whole record.
        var fetched = await _client.GetFromJsonAsync<IntakeSubmissionResponse>(
            $"/api/intake-submissions/{created.Id}", JsonOptions);
        Assert.Equal(reviewed.Id, fetched!.Id);
        Assert.Equal(reviewed.Status, fetched.Status);
        Assert.Equal(reviewed.Summary, fetched.Summary);
        Assert.Equal(reviewed.Recommendations, fetched.Recommendations);
        Assert.Equal(reviewed.ClinicallyApproved, fetched.ClinicallyApproved);
    }

    [Fact]
    public async Task Review_Reject_KeepsAdviceWithheld()
    {
        var created = await CreateSubmission();

        var reviewResponse = await PatchReview(created.Id, approve: false);
        reviewResponse.EnsureSuccessStatusCode();

        var reviewed = await reviewResponse.Content.ReadFromJsonAsync<IntakeSubmissionResponse>(JsonOptions);

        Assert.Equal(SubmissionStatus.Rejected, reviewed!.Status);
        Assert.Null(reviewed.Summary);
        Assert.Null(reviewed.Recommendations);
        Assert.False(reviewed.ClinicallyApproved);
    }

    [Fact]
    public async Task GetById_UnknownId_ReturnsNotFound()
    {
        var response = await _client.GetAsync($"/api/intake-submissions/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Review_UnknownId_ReturnsNotFound()
    {
        var response = await PatchReview(Guid.NewGuid(), approve: true);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task List_IncludesCreatedSubmission()
    {
        var created = await CreateSubmission();

        var submissions = await _client.GetFromJsonAsync<List<IntakeSubmissionResponse>>(
            "/api/intake-submissions", JsonOptions);

        Assert.Contains(submissions!, s => s.Id == created.Id);
    }

    [Fact]
    public async Task Create_WithSameIdempotencyKey_ReturnsSameSubmission()
    {
        var key = Guid.NewGuid().ToString();

        var first = await CreateSubmission(idempotencyKey: key);
        var second = await CreateSubmission(idempotencyKey: key);

        Assert.Equal(first.Id, second.Id);

        var submissions = await _client.GetFromJsonAsync<List<IntakeSubmissionResponse>>(
            "/api/intake-submissions", JsonOptions);
        Assert.Single(submissions!, s => s.Id == first.Id);
    }

    [Fact]
    public async Task Create_WithDifferentIdempotencyKeys_CreatesSeparateSubmissions()
    {
        var first = await CreateSubmission(idempotencyKey: Guid.NewGuid().ToString());
        var second = await CreateSubmission(idempotencyKey: Guid.NewGuid().ToString());

        Assert.NotEqual(first.Id, second.Id);
    }

    // Create/GetById are called by the iOS app on a patient's behalf (no
    // login system in this demo) and stay open. List/Review expose or act
    // on every patient's data and require the clinician API key.

    [Fact]
    public async Task Create_WithoutApiKey_Succeeds()
    {
        var response = await _factory.CreateClient().PostAsJsonAsync("/api/intake-submissions", SampleRequest);
        Assert.True(response.IsSuccessStatusCode);
    }

    [Fact]
    public async Task List_WithoutApiKey_ReturnsUnauthorized()
    {
        var response = await _factory.CreateClient().GetAsync("/api/intake-submissions");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task List_WithWrongApiKey_ReturnsUnauthorized()
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Api-Key", "not-the-right-key");

        var response = await client.GetAsync("/api/intake-submissions");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Review_WithoutApiKey_ReturnsUnauthorized()
    {
        var created = await CreateSubmission();

        var response = await _factory.CreateClient().PatchAsync(
            $"/api/intake-submissions/{created.Id}/review",
            JsonContent.Create(new ReviewRequest(true)));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Create_WithNoAnswers_ReturnsBadRequest()
    {
        var response = await _client.PostAsJsonAsync(
            "/api/intake-submissions", new { answers = Array.Empty<object>(), scanSharpness = 42.0 });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Create_WithNegativeScanSharpness_ReturnsBadRequest()
    {
        var response = await _client.PostAsJsonAsync(
            "/api/intake-submissions",
            new { answers = new[] { new { questionId = "reason", answer = "Skin concern" } }, scanSharpness = -1.0 });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    private async Task<IntakeSubmissionResponse> CreateSubmission(string? idempotencyKey = null)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "/api/intake-submissions")
        {
            Content = JsonContent.Create(SampleRequest),
        };
        if (idempotencyKey is not null)
        {
            request.Headers.Add("Idempotency-Key", idempotencyKey);
        }
        var response = await _client.SendAsync(request);
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<IntakeSubmissionResponse>(JsonOptions))!;
    }

    private Task<HttpResponseMessage> PatchReview(Guid id, bool approve)
    {
        var request = new HttpRequestMessage(HttpMethod.Patch, $"/api/intake-submissions/{id}/review")
        {
            Content = JsonContent.Create(new ReviewRequest(approve)),
        };
        return _client.SendAsync(request);
    }
}

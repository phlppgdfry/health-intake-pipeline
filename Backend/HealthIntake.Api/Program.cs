using System.Text.Json.Serialization;
using HealthIntake.Api.Auth;
using HealthIntake.Api.Data;
using HealthIntake.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

// Structured logging (fase 5): replaces the default console logger with
// Serilog, configurable via the "Serilog" section in appsettings — useful
// once this needs to ship to a real log sink (e.g. Seq, Application
// Insights) instead of plain console text.
//
// `preserveStaticLogger: true` deliberately avoids touching the global
// `Log.Logger` — without it, spinning up more than one host in the same
// process (exactly what `WebApplicationFactory`-based tests do) throws
// "the logger is already frozen" on the second instantiation.
builder.Host.UseSerilog((context, services, configuration) => configuration
    .ReadFrom.Configuration(context.Configuration)
    .ReadFrom.Services(services)
    .Enrich.FromLogContext()
    .WriteTo.Console(),
    preserveStaticLogger: true);

var connectionString = builder.Configuration.GetConnectionString("HealthIntakeDb")
    ?? throw new InvalidOperationException("Missing ConnectionStrings:HealthIntakeDb configuration.");

builder.Services.AddDbContext<HealthIntakeDbContext>(options => options.UseNpgsql(connectionString));
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddScoped<IAdviceGenerator, AdviceGenerator>();
builder.Services.AddHealthChecks().AddDbContextCheck<HealthIntakeDbContext>();

builder.Services.AddControllers()
    .AddJsonOptions(options => options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    // Lets Swagger's "Authorize" button set X-Api-Key once for every
    // request — the open endpoints (Create/GetById) just ignore it.
    options.AddSecurityDefinition(ApiKeyAuthFilter.HeaderName, new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.ApiKey,
        In = ParameterLocation.Header,
        Name = ApiKeyAuthFilter.HeaderName,
        Description = "Required for GET /api/intake-submissions and PATCH .../review.",
    });
    options.AddSecurityRequirement(document => new OpenApiSecurityRequirement
    {
        { new OpenApiSecuritySchemeReference(ApiKeyAuthFilter.HeaderName, document), [] },
    });
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    await scope.ServiceProvider.GetRequiredService<HealthIntakeDbContext>().Database.MigrateAsync();

    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseSerilogRequestLogging();
app.UseHttpsRedirection();
// Fase 4: `wwwroot/index.html` is the clinician review page — a plain
// static page calling the same GET/PATCH endpoints Swagger already
// exposes. The page itself needs no auth (it's just HTML/JS); the API
// calls it makes are protected by `ApiKeyAuthFilter` (fase 5).
app.UseDefaultFiles();
app.UseStaticFiles();
app.UseAuthorization();
app.MapControllers();
// Unauthenticated on purpose: orchestration/monitoring probes (Docker,
// Kubernetes, uptime checks) hit this, not clinicians.
app.MapHealthChecks("/health");

app.Run();

/// Exposed so `HealthIntake.Api.Tests` can boot the app via `WebApplicationFactory<Program>`.
public partial class Program;

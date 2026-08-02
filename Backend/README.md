# Backend

A real ASP.NET Core + PostgreSQL API behind the iOS case study, built in five
fases: real backend (1) → iOS wired to it (2) → reliable offline sync (3) →
clinician review UI (4) → CI/Docker/hardening (5). All five are done.

## Why it's shaped this way

The one rule this API exists to enforce for real: **advice is never
released to a client until a submission is `Approved`.** The iOS app's
`SignOffGate` (`App/ClinicalGate/SignOffGate.swift`) enforces this as a
client-side type; here it is enforced by the server, because the server —
not the client — is the actual source of truth for what's clinically safe
to show. `Summary` and `Recommendations` are generated at submission time
(so review is instant) but only ever leave `IntakeSubmissionsController` in
the response once `Status == Approved` — see
[`ToResponse`](HealthIntake.Api/Controllers/IntakeSubmissionsController.cs).
`Answers`/`ScanSharpness` are *not* gated — a reviewer needs to see the
intake before deciding.

The request shape (`answers` + `scanSharpness`) mirrors the iOS app's
`AdviceRequest` (`App/Engine/APIClient.swift`) field for field, so the iOS
`RemoteAdviceAPI` (fase 2) is a JSON-mapping exercise, not a redesign.

## Idempotency (fase 3)

`POST /api/intake-submissions` accepts an `Idempotency-Key` header. A
retried or offline-queue-replayed request with a key already seen returns
the *existing* submission instead of creating a duplicate — necessary
because a network error never tells the client whether the server actually
received the request. The iOS app derives this key from a hash of the
intake content (`RemoteAdviceAPI.idempotencyKey(for:)`), so the same intake
always maps to the same key. Enforced with a filtered unique index on
`ClientRequestId` (`HealthIntakeDbContext`), racing concurrent requests with
the same key included.

## Security (fase 5)

- **API key on clinician endpoints** — `GET /api/intake-submissions` (the
  list) and `PATCH /{id}/review` require an `X-Api-Key` header matching the
  `Clinician:ApiKey` config value (`ApiKeyAuthFilter`). `POST` and
  `GET /{id}` stay open: they're called by the iOS app on a patient's
  behalf, and this demo has no patient login system to check against
  instead. The list/review boundary is the one that actually matters —
  it's the one exposing *every* patient's answers. An unconfigured key
  fails closed (500), not open. This is a demo-appropriate stand-in for
  real auth (no per-clinician identity, no expiry, no revocation) — a real
  deployment would use ASP.NET Core Identity, OAuth, or similar.
- **Input validation** — `[MinLength(1)]` on `answers` (an empty intake is
  rejected) and `[Range(0, ...)]` on `scanSharpness`. `[ApiController]`
  turns a failed validation into an automatic `400` with
  `ValidationProblemDetails` — no manual `ModelState` check needed.
- **Structured logging** — Serilog (console sink, configurable via the
  `Serilog` config section) replaces the default logger, plus
  `UseSerilogRequestLogging()` for one structured line per HTTP request.
  The controller logs submission IDs and status transitions, deliberately
  never the answers or advice text — that's health data, not diagnostic
  data.
- **`/health`** — unauthenticated on purpose (orchestration/monitoring
  probes, not clinicians), checks the database via
  `AddDbContextCheck<HealthIntakeDbContext>()`.

## Run it

```bash
docker compose up -d --build   # Postgres (5544) + the API (8080), built from
                                # HealthIntake.Api/Dockerfile
```

Or, for active development with hot reload instead of a container:

```bash
docker compose up -d postgres
cd HealthIntake.Api
dotnet ef database update      # or just `dotnet run` — it migrates on
                                # startup in Development
dotnet run                     # http://localhost:5241
```

- Clinician review page: http://localhost:8080/ (or :5241 with `dotnet
  run`) — a plain static page (`wwwroot/index.html`, fase 4) listing
  `PendingReview` submissions with Approve/Reject buttons. Enter the
  clinician API key (`dev-clinician-key` in `appsettings.Development.json`)
  in the field at the top — it's saved to `localStorage` so you only type
  it once.
- Swagger UI: same host, `/swagger` (Development only). For the
  `List`/`Review` endpoints there too, add the `X-Api-Key` header via
  Swagger's "Authorize" — Swagger doesn't know about the custom filter, so
  just add the header manually per request, or use the review page instead.

Manual flow via Swagger + the review page:

1. `POST /api/intake-submissions` — creates a submission, `status:
   PendingReview`, `summary`/`recommendations` are `null`.
2. Approve it on the review page (or `PATCH /api/intake-submissions/{id}/review`
   with `{"approve": true}` and the API key header).
3. `GET /api/intake-submissions/{id}` — now `summary`/`recommendations` are
   populated and `clinicallyApproved: true`.

## Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `POST` | `/api/intake-submissions` | open | Create a submission; generates advice server-side, withheld until reviewed. Honors `Idempotency-Key`. Validates `answers`/`scanSharpness`. |
| `GET` | `/api/intake-submissions/{id}` | open | Fetch one submission |
| `GET` | `/api/intake-submissions` | `X-Api-Key` | List all submissions (the review page filters this to `PendingReview`) |
| `PATCH` | `/api/intake-submissions/{id}/review` | `X-Api-Key` | Approve or reject |
| `GET` | `/health` | open | Liveness/readiness — checks the database |

## Docker (fase 5)

`docker-compose.yml` builds and runs the API alongside Postgres (see "Run
it" above). To build/run the image standalone against a Postgres elsewhere:

```bash
docker build -f HealthIntake.Api/Dockerfile -t health-intake-api .
docker run -p 8080:8080 \
  -e ASPNETCORE_ENVIRONMENT=Development \
  -e ConnectionStrings__HealthIntakeDb="Host=<postgres-host>;Port=5432;Database=healthintake;Username=healthintake;Password=healthintake" \
  health-intake-api
```

`ASPNETCORE_ENVIRONMENT=Development` is what enables migrate-on-start and
Swagger — set it explicitly for a demo container; a real deployment would
run migrations as a separate release step and inject a Production-grade
`Clinician__ApiKey` instead of relying on the Development default.

## Tests

```bash
docker compose up -d postgres
docker exec backend-postgres-1 psql -U healthintake -d healthintake \
  -c "CREATE DATABASE healthintake_test;"   # once, if it doesn't exist yet
dotnet test
```

- `AdviceGeneratorTests` — pure unit tests, no database.
- `IntakeSubmissionsControllerTests` — `WebApplicationFactory<Program>`
  against the real Postgres container (`healthintake_test`, kept separate
  from the `healthintake` database used for manual/Swagger testing).
  Covers idempotency, input validation (400s), and the API-key boundary
  (401 without/with the wrong key, success with it).

## CI (fase 5)

[`.github/workflows/backend-ci.yml`](../.github/workflows/backend-ci.yml) —
separate from the iOS workflow, only runs when `Backend/` changes. On
`ubuntu-latest` with a `postgres:16` service container (same port
convention as local dev, 5544): restore, build, `dotnet format
--verify-no-changes`, create the test database, `dotnet test` with coverage
collection (uploaded as an artifact), and a Docker build of the API image to
catch Dockerfile regressions.

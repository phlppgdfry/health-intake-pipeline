using Xunit;

// All test classes share one physical Postgres database (`healthintake_test`)
// via WebApplicationFactory, and each one runs Database.MigrateAsync() on
// startup. Left parallel, xUnit's default (parallel-by-class) races multiple
// hosts migrating the same fresh database at once — flaky, not just slow.
// The whole suite runs in ~1s either way, so serial execution costs nothing.
[assembly: CollectionBehavior(DisableTestParallelization = true)]

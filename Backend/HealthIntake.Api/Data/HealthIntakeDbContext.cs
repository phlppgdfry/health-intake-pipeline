using HealthIntake.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace HealthIntake.Api.Data;

public class HealthIntakeDbContext(DbContextOptions<HealthIntakeDbContext> options) : DbContext(options)
{
    public DbSet<IntakeSubmission> IntakeSubmissions => Set<IntakeSubmission>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<IntakeSubmission>(entity =>
        {
            entity.Property(s => s.Status).HasConversion<string>();
            // Filtered so multiple submissions with no idempotency key
            // (ClientRequestId null) don't collide on the unique constraint.
            entity.HasIndex(s => s.ClientRequestId)
                .IsUnique()
                .HasFilter("\"ClientRequestId\" IS NOT NULL");
            // Npgsql maps List<string> to a native text[] column.
            entity.OwnsMany(s => s.Answers, answers =>
            {
                answers.ToJson();
            });
        });
    }
}

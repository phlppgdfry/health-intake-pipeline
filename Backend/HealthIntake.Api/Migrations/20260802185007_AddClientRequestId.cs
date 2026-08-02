using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace HealthIntake.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddClientRequestId : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ClientRequestId",
                table: "IntakeSubmissions",
                type: "text",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_IntakeSubmissions_ClientRequestId",
                table: "IntakeSubmissions",
                column: "ClientRequestId",
                unique: true,
                filter: "\"ClientRequestId\" IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_IntakeSubmissions_ClientRequestId",
                table: "IntakeSubmissions");

            migrationBuilder.DropColumn(
                name: "ClientRequestId",
                table: "IntakeSubmissions");
        }
    }
}

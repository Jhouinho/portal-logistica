using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Portal.Infrastructure.Identity.Migrations
{
    /// <inheritdoc />
    public partial class InitialIdentityHcaLogi : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "u_HcaLogiRoles",
                columns: table => new
                {
                    Id = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                    NormalizedName = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                    ConcurrencyStamp = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_u_HcaLogiRoles", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "u_HcaLogiUsers",
                columns: table => new
                {
                    Id = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    UsStamp = table.Column<string>(type: "nvarchar(25)", maxLength: 25, nullable: true),
                    Usercode = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    UserName = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                    NormalizedUserName = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                    Email = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                    NormalizedEmail = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                    EmailConfirmed = table.Column<bool>(type: "bit", nullable: false),
                    PasswordHash = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    SecurityStamp = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ConcurrencyStamp = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    PhoneNumber = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    PhoneNumberConfirmed = table.Column<bool>(type: "bit", nullable: false),
                    TwoFactorEnabled = table.Column<bool>(type: "bit", nullable: false),
                    LockoutEnd = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    LockoutEnabled = table.Column<bool>(type: "bit", nullable: false),
                    AccessFailedCount = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_u_HcaLogiUsers", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "u_HcaLogiRoleClaims",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    RoleId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    ClaimType = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ClaimValue = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_u_HcaLogiRoleClaims", x => x.Id);
                    table.ForeignKey(
                        name: "FK_u_HcaLogiRoleClaims_u_HcaLogiRoles_RoleId",
                        column: x => x.RoleId,
                        principalTable: "u_HcaLogiRoles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "u_HcaLogiUserClaims",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    ClaimType = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ClaimValue = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_u_HcaLogiUserClaims", x => x.Id);
                    table.ForeignKey(
                        name: "FK_u_HcaLogiUserClaims_u_HcaLogiUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "u_HcaLogiUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "u_HcaLogiUserLogins",
                columns: table => new
                {
                    LoginProvider = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    ProviderKey = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    ProviderDisplayName = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    UserId = table.Column<string>(type: "nvarchar(450)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_u_HcaLogiUserLogins", x => new { x.LoginProvider, x.ProviderKey });
                    table.ForeignKey(
                        name: "FK_u_HcaLogiUserLogins_u_HcaLogiUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "u_HcaLogiUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "u_HcaLogiUserRoles",
                columns: table => new
                {
                    UserId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    RoleId = table.Column<string>(type: "nvarchar(450)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_u_HcaLogiUserRoles", x => new { x.UserId, x.RoleId });
                    table.ForeignKey(
                        name: "FK_u_HcaLogiUserRoles_u_HcaLogiRoles_RoleId",
                        column: x => x.RoleId,
                        principalTable: "u_HcaLogiRoles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_u_HcaLogiUserRoles_u_HcaLogiUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "u_HcaLogiUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "u_HcaLogiUserTokens",
                columns: table => new
                {
                    UserId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    LoginProvider = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    Value = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_u_HcaLogiUserTokens", x => new { x.UserId, x.LoginProvider, x.Name });
                    table.ForeignKey(
                        name: "FK_u_HcaLogiUserTokens_u_HcaLogiUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "u_HcaLogiUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_u_HcaLogiRoleClaims_RoleId",
                table: "u_HcaLogiRoleClaims",
                column: "RoleId");

            migrationBuilder.CreateIndex(
                name: "RoleNameIndex",
                table: "u_HcaLogiRoles",
                column: "NormalizedName",
                unique: true,
                filter: "[NormalizedName] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_u_HcaLogiUserClaims_UserId",
                table: "u_HcaLogiUserClaims",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_u_HcaLogiUserLogins_UserId",
                table: "u_HcaLogiUserLogins",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_u_HcaLogiUserRoles_RoleId",
                table: "u_HcaLogiUserRoles",
                column: "RoleId");

            migrationBuilder.CreateIndex(
                name: "EmailIndex",
                table: "u_HcaLogiUsers",
                column: "NormalizedEmail");

            migrationBuilder.CreateIndex(
                name: "UserNameIndex",
                table: "u_HcaLogiUsers",
                column: "NormalizedUserName",
                unique: true,
                filter: "[NormalizedUserName] IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "u_HcaLogiRoleClaims");

            migrationBuilder.DropTable(
                name: "u_HcaLogiUserClaims");

            migrationBuilder.DropTable(
                name: "u_HcaLogiUserLogins");

            migrationBuilder.DropTable(
                name: "u_HcaLogiUserRoles");

            migrationBuilder.DropTable(
                name: "u_HcaLogiUserTokens");

            migrationBuilder.DropTable(
                name: "u_HcaLogiRoles");

            migrationBuilder.DropTable(
                name: "u_HcaLogiUsers");
        }
    }
}

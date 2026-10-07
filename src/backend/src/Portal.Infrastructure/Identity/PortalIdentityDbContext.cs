using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace Portal.Infrastructure.Identity;

public sealed class PortalIdentityDbContext : IdentityDbContext<PortalUserIdentity>
{
    public PortalIdentityDbContext(DbContextOptions<PortalIdentityDbContext> options)
        : base(options)
    {
    }

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.Entity<PortalUserIdentity>(e =>
        {
            e.ToTable("u_HcaLogiUsers");
            e.Property(x => x.UsStamp).HasMaxLength(25);
            e.Property(x => x.Usercode).HasMaxLength(20);
        });

        builder.Entity<Microsoft.AspNetCore.Identity.IdentityRole>(e => e.ToTable("u_HcaLogiRoles"));
        builder.Entity<Microsoft.AspNetCore.Identity.IdentityUserRole<string>>(e => e.ToTable("u_HcaLogiUserRoles"));
        builder.Entity<Microsoft.AspNetCore.Identity.IdentityUserClaim<string>>(e => e.ToTable("u_HcaLogiUserClaims"));
        builder.Entity<Microsoft.AspNetCore.Identity.IdentityUserLogin<string>>(e => e.ToTable("u_HcaLogiUserLogins"));
        builder.Entity<Microsoft.AspNetCore.Identity.IdentityUserToken<string>>(e => e.ToTable("u_HcaLogiUserTokens"));
        builder.Entity<Microsoft.AspNetCore.Identity.IdentityRoleClaim<string>>(e => e.ToTable("u_HcaLogiRoleClaims"));
    }
}

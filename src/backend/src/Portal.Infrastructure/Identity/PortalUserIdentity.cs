using Microsoft.AspNetCore.Identity;

namespace Portal.Infrastructure.Identity;

public sealed class PortalUserIdentity : IdentityUser
{
    /// <summary>PHC US.usstamp (preenchido/actualizado no login).</summary>
    public string? UsStamp { get; set; }

    /// <summary>PHC US.usercode.</summary>
    public string? Usercode { get; set; }
}

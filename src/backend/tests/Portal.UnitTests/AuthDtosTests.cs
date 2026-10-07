using Portal.Application.Auth;
using Xunit;

namespace Portal.UnitTests;

public class AuthDtosTests
{
    [Fact]
    public void LoginRequest_holds_login_and_password()
    {
        var req = new LoginRequest("sa", "Secret1");
        Assert.Equal("sa", req.Login);
        Assert.Equal("Secret1", req.Password);
    }

    [Fact]
    public void UtilizadorDto_includes_isAdmin()
    {
        var dto = new UtilizadorDto("sa", "Admin", true);
        Assert.True(dto.IsAdmin);
    }
}

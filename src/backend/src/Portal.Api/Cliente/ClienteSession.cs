using System.Globalization;
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Portal.Application.Cliente;

namespace Portal.Api.Cliente;

public static class ClienteSession
{
    public static async Task SignInAsync(HttpContext http, ClienteFicha ficha)
    {
        var claims = new List<Claim>
        {
            new(ClienteAuthConstants.ClaimNo, ficha.No.ToString(CultureInfo.InvariantCulture)),
            new(ClienteAuthConstants.ClaimEstab, ficha.Estab.ToString(CultureInfo.InvariantCulture)),
            new(ClienteAuthConstants.ClaimNcont, ficha.Ncont),
            new(ClienteAuthConstants.ClaimNome, ficha.Nome),
            new(ClaimTypes.Name, ficha.Nome),
            new(ClaimTypes.NameIdentifier, $"{ficha.No}:{ficha.Estab}")
        };

        var identity = new ClaimsIdentity(claims, ClienteAuthConstants.CookieScheme);
        var principal = new ClaimsPrincipal(identity);
        await http.SignInAsync(
            ClienteAuthConstants.CookieScheme,
            principal,
            new AuthenticationProperties
            {
                IsPersistent = true,
                IssuedUtc = DateTimeOffset.UtcNow,
                ExpiresUtc = DateTimeOffset.UtcNow.AddMinutes(ClienteAuthConstants.SessionMinutes),
                AllowRefresh = true
            });
    }

    public static async Task SignOutAsync(HttpContext http) =>
        await http.SignOutAsync(ClienteAuthConstants.CookieScheme);

    public static bool TryGetCliente(ClaimsPrincipal user, out decimal no, out decimal estab)
    {
        no = 0;
        estab = 0;
        var noS = user.FindFirstValue(ClienteAuthConstants.ClaimNo);
        var estabS = user.FindFirstValue(ClienteAuthConstants.ClaimEstab);
        if (string.IsNullOrEmpty(noS) || string.IsNullOrEmpty(estabS))
            return false;
        return decimal.TryParse(noS, NumberStyles.Any, CultureInfo.InvariantCulture, out no)
               && decimal.TryParse(estabS, NumberStyles.Any, CultureInfo.InvariantCulture, out estab);
    }
}

using System.Globalization;
using System.Security.Cryptography;
using System.Text;

namespace Portal.Application.Cliente;

/// <summary>Hash canónico da submissão (sem preços — calculados no servidor).</summary>
public static class ClientePedidoIdempotency
{
    public static string ComputePayloadHash(IEnumerable<ClientePedidoLinhaInput> linhas)
    {
        var ordered = linhas
            .OrderBy(l => l.LinhaOrd)
            .Select(l =>
                string.Join(
                    '|',
                    l.LinhaOrd.ToString(CultureInfo.InvariantCulture),
                    (l.Ref ?? "").Trim(),
                    l.Qtt.ToString(CultureInfo.InvariantCulture),
                    ClienteCorLimits.Normalize(l.Cor)));

        var canonical = string.Join('\n', ordered);
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(canonical));
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    public static string FormatNumeroInterno(long pedidoId, DateTime dataSubmissaoUtc) =>
        $"PM-{dataSubmissaoUtc:yyyy}-{pedidoId.ToString(CultureInfo.InvariantCulture).PadLeft(6, '0')}";
}

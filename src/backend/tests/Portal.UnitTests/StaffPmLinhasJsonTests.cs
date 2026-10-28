using System.Text.Json;
using Portal.Application.Cliente;

namespace Portal.UnitTests;

public class StaffPmLinhasJsonTests
{
    [Fact]
    public void Json_deserializa_ref_camelCase()
    {
        const string json = """
        {"linhas":[{"linhaOrd":1,"ref":"1051","design":"CELOSIA","cor":"Branco","qtt":8,"precoUnitario":6.5},{"linhaOrd":null,"ref":"1052","design":"NOVA","cor":"","qtt":1,"precoUnitario":0}]}
        """;
        var opts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
        var body = JsonSerializer.Deserialize<StaffPmGuardarLinhasRequest>(json, opts);
        Assert.NotNull(body);
        Assert.NotNull(body!.Linhas);
        Assert.Equal(2, body.Linhas.Count);
        Assert.Equal("1051", body.Linhas[0].Ref);
        Assert.Equal(8m, body.Linhas[0].Qtt);
        Assert.Null(body.Linhas[1].LinhaOrd);
        Assert.Equal("1052", body.Linhas[1].Ref);
    }

    [Fact]
    public void Json_aspnet_camelCase_policy()
    {
        const string json = """
        {"linhas":[{"linhaOrd":1,"ref":"1051","design":"A","cor":"","qtt":1,"precoUnitario":1}]}
        """;
        var opts = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            PropertyNameCaseInsensitive = true
        };
        var body = JsonSerializer.Deserialize<StaffPmGuardarLinhasRequest>(json, opts);
        Assert.Equal("1051", body!.Linhas[0].Ref);
    }
}

using System.Data;
using Portal.Application.Cliente;

namespace Portal.Infrastructure.Cliente;

/// <summary>
/// Constrói o TVP dbo.HCA_PedidoMobileLinhaType (após script 100: +edebito opcional).
/// Legado: edebito = NULL → SP usa CL.preco/ST.epvN.
/// Staff: edebito = PrecoUnitario persistido do operador → BI.edebito.
/// </summary>
public static class PedidoMobileLinhaTvp
{
    public static DataTable BuildLegado(IEnumerable<(int LinhaOrd, string Ref, decimal Qtt, string Cor)> linhas)
    {
        var tvp = CreateSchema();
        foreach (var l in linhas.OrderBy(x => x.LinhaOrd))
        {
            var row = tvp.NewRow();
            row["linha_ord"] = l.LinhaOrd;
            row["ref"] = l.Ref.Trim();
            row["qtt"] = l.Qtt;
            row["cor"] = ClienteCorLimits.Normalize(l.Cor);
            row["edebito"] = DBNull.Value;
            tvp.Rows.Add(row);
        }

        return tvp;
    }

    public static DataTable BuildStaffComPrecoOperador(IEnumerable<ClientePmLinhaPersistida> linhas)
    {
        var tvp = CreateSchema();
        foreach (var l in linhas.OrderBy(x => x.LinhaOrd))
        {
            var row = tvp.NewRow();
            row["linha_ord"] = l.LinhaOrd;
            row["ref"] = l.Ref.Trim();
            row["qtt"] = l.Qtt;
            row["cor"] = ClienteCorLimits.Normalize(l.Cor);
            row["edebito"] = StaffPmPrecoRules.RoundPreco(l.PrecoUnitario);
            tvp.Rows.Add(row);
        }

        return tvp;
    }

    private static DataTable CreateSchema()
    {
        var tvp = new DataTable();
        tvp.Columns.Add("linha_ord", typeof(int));
        tvp.Columns.Add("ref", typeof(string));
        tvp.Columns.Add("qtt", typeof(decimal));
        tvp.Columns.Add("cor", typeof(string));
        tvp.Columns.Add("edebito", typeof(decimal));
        return tvp;
    }
}

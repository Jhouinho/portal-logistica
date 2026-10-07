using Portal.Application.Encomendas;

namespace Portal.Application.PrevisoesEntrada;

public sealed record PrevisaoEntradaListaItemDto(
    Guid Id,
    string DataInicio,
    string DataFim,
    bool Fechada,
    string? FechadaEm,
    string? FechadaPor,
    int TotalLinhas,
    decimal QuantidadeTotal);

public sealed record PrevisaoEntradaLinhaDto(
    Guid Id,
    string Ref,
    string Cor,
    string Design,
    decimal QuantidadePrevista,
    decimal QuantidadeAlocada,
    decimal QuantidadeDisponivel);

public sealed record PrevisaoEntradaDetalheDto(
    Guid Id,
    string DataInicio,
    string DataFim,
    bool Fechada,
    string? FechadaEm,
    string? FechadaPor,
    IReadOnlyList<PrevisaoEntradaLinhaDto> Linhas);

public sealed record CriarPrevisaoEntradaRequest(string DataInicio, string DataFim);

public sealed record GuardarPrevisaoEntradaLinhaRequest(
    string Ref,
    string? Cor,
    decimal QuantidadePrevista);

public sealed record GuardarPrevisaoEntradaRequest(
    string DataInicio,
    string DataFim,
    IReadOnlyList<GuardarPrevisaoEntradaLinhaRequest> Linhas);

public sealed record PrevisaoArtigoSugestaoDto(string Ref, string Design);

public sealed record PrevisaoCorSugestaoDto(string Cor);

public sealed class PrevisoesEntradaService
{
    private readonly IPrevisoesEntradaStore _store;

    public PrevisoesEntradaService(IPrevisoesEntradaStore store)
    {
        _store = store;
    }

    public async Task<IReadOnlyList<PrevisaoEntradaListaItemDto>> ListarAsync(
        CancellationToken cancellationToken = default)
    {
        var rows = await _store.ListarAsync(cancellationToken);
        return rows.Select(r => new PrevisaoEntradaListaItemDto(
            r.Id,
            FormatDate(r.DataInicio),
            FormatDate(r.DataFim),
            r.Fechada,
            FormatDateTime(r.FechadaEm),
            NullIfEmpty(r.FechadaPor),
            r.TotalLinhas,
            r.QuantidadeTotal)).ToList();
    }

    public async Task<PrevisaoEntradaDetalheDto?> ObterAsync(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        var row = await _store.ObterAsync(id, cancellationToken);
        return row is null ? null : MapDetalhe(row);
    }

    public async Task<PrevisaoEntradaDetalheDto> CriarAsync(
        CriarPrevisaoEntradaRequest request,
        string usrLogin,
        CancellationToken cancellationToken = default)
    {
        var (inicio, fim) = ParsePeriodo(request.DataInicio, request.DataFim);
        var created = await _store.CriarAsync(inicio, fim, usrLogin, cancellationToken);
        var detalhe = await _store.ObterAsync(created.Id, cancellationToken)
                      ?? throw new PortalBusinessException("Previsão criada mas não encontrada.", 500);
        return MapDetalhe(detalhe);
    }

    public async Task<PrevisaoEntradaDetalheDto> GuardarAsync(
        Guid id,
        GuardarPrevisaoEntradaRequest request,
        string usrLogin,
        CancellationToken cancellationToken = default)
    {
        if (id == Guid.Empty)
            throw new PortalBusinessException("Id inválido.");

        var (inicio, fim) = ParsePeriodo(request.DataInicio, request.DataFim);

        var linhas = (request.Linhas ?? Array.Empty<GuardarPrevisaoEntradaLinhaRequest>())
            .Where(l => !string.IsNullOrWhiteSpace(l.Ref))
            .Select(l => (
                Ref: l.Ref.Trim(),
                // Cor: sem TRIM — mesma semântica de BI.u_cor (NOT NULL).
                Cor: l.Cor ?? string.Empty,
                Qty: l.QuantidadePrevista < 0 ? 0m : l.QuantidadePrevista))
            .GroupBy(l => (l.Ref, l.Cor))
            .Select(g =>
            {
                var last = g.Last();
                return (last.Ref, last.Cor, last.Qty);
            })
            .ToList();

        await _store.GuardarAsync(id, usrLogin, inicio, fim, linhas, cancellationToken);
        // Releitura via obter: incluir Alocado/Disponível (guardar não os devolve).
        var refreshed = await _store.ObterAsync(id, cancellationToken)
                        ?? throw new PortalBusinessException("Previsão não encontrada.", 404);
        return MapDetalhe(refreshed);
    }

    public async Task<IReadOnlyList<PrevisaoArtigoSugestaoDto>> SugerirArtigosAsync(
        string termo,
        int limit = 20,
        CancellationToken cancellationToken = default)
    {
        var rows = await _store.SugerirArtigosAsync(termo, limit, cancellationToken);
        return rows.Select(r => new PrevisaoArtigoSugestaoDto(r.Ref, r.Design)).ToList();
    }

    public async Task<IReadOnlyList<PrevisaoCorSugestaoDto>> SugerirCoresAsync(
        string artigoRef,
        string? termo = null,
        int limit = 30,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(artigoRef))
            return Array.Empty<PrevisaoCorSugestaoDto>();

        var rows = await _store.SugerirCoresAsync(artigoRef.Trim(), termo, limit, cancellationToken);
        return rows.Select(r => new PrevisaoCorSugestaoDto(r.Cor)).ToList();
    }

    public async Task<PrevisaoEntradaDetalheDto> FecharAsync(
        Guid id,
        string usrLogin,
        CancellationToken cancellationToken = default)
    {
        if (id == Guid.Empty)
            throw new PortalBusinessException("Id inválido.");

        var row = await _store.FecharAsync(id, usrLogin, cancellationToken);
        return MapDetalhe(row);
    }

    public async Task<(PrevisaoEntradaDetalheDto Detalhe, int LinhasAdicionadas)> AtualizarLinhasAsync(
        Guid id,
        string usrLogin,
        CancellationToken cancellationToken = default)
    {
        if (id == Guid.Empty)
            throw new PortalBusinessException("Id inválido.");

        var (row, n) = await _store.AtualizarLinhasAsync(id, usrLogin, cancellationToken);
        return (MapDetalhe(row), n);
    }

    private static PrevisaoEntradaDetalheDto MapDetalhe(PrevisaoEntradaDetalheRow row) =>
        new(
            row.Id,
            FormatDate(row.DataInicio),
            FormatDate(row.DataFim),
            row.Fechada,
            FormatDateTime(row.FechadaEm),
            NullIfEmpty(row.FechadaPor),
            row.Linhas.Select(l => new PrevisaoEntradaLinhaDto(
                l.Id,
                l.Ref,
                l.Cor,
                l.Design,
                l.QuantidadePrevista,
                l.QuantidadeAlocada,
                l.QuantidadeDisponivel)).ToList());

    private static (DateOnly Inicio, DateOnly Fim) ParsePeriodo(string? dataInicio, string? dataFim)
    {
        if (!DateOnly.TryParse(dataInicio, out var inicio))
            throw new PortalBusinessException("Data de início inválida.");
        if (!DateOnly.TryParse(dataFim, out var fim))
            throw new PortalBusinessException("Data de fim inválida.");
        if (inicio > fim)
            throw new PortalBusinessException(
                "A data de início não pode ser posterior à data de fim.");
        return (inicio, fim);
    }

    private static string FormatDate(DateTime d) => d.ToString("yyyy-MM-dd");

    private static string? FormatDateTime(DateTime? d) =>
        d is null ? null : d.Value.ToString("o");

    private static string? NullIfEmpty(string? s) =>
        string.IsNullOrWhiteSpace(s) ? null : s.Trim();
}

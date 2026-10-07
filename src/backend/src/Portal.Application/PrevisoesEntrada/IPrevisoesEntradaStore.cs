namespace Portal.Application.PrevisoesEntrada;

public sealed record PrevisaoEntradaListaRow(
    Guid Id,
    DateTime DataInicio,
    DateTime DataFim,
    bool Fechada,
    DateTime? FechadaEm,
    string? FechadaPor,
    int TotalLinhas,
    decimal QuantidadeTotal);

public sealed record PrevisaoEntradaLinhaRow(
    Guid Id,
    Guid PrevisaoId,
    string Ref,
    string Cor,
    string Design,
    decimal QuantidadePrevista,
    decimal QuantidadeAlocada,
    decimal QuantidadeDisponivel);

public sealed record PrevisaoEntradaDetalheRow(
    Guid Id,
    DateTime DataInicio,
    DateTime DataFim,
    bool Fechada,
    DateTime? FechadaEm,
    string? FechadaPor,
    IReadOnlyList<PrevisaoEntradaLinhaRow> Linhas);

public sealed record PrevisaoArtigoSugestaoRow(string Ref, string Design);

public sealed record PrevisaoCorSugestaoRow(string Cor);

public interface IPrevisoesEntradaStore
{
    Task<IReadOnlyList<PrevisaoEntradaListaRow>> ListarAsync(CancellationToken cancellationToken = default);

    Task<PrevisaoEntradaDetalheRow?> ObterAsync(Guid id, CancellationToken cancellationToken = default);

    Task<(Guid Id, DateOnly DataInicio, DateOnly DataFim)> CriarAsync(
        DateOnly dataInicio,
        DateOnly dataFim,
        string usrLogin,
        CancellationToken cancellationToken = default);

    Task<PrevisaoEntradaDetalheRow> GuardarAsync(
        Guid id,
        string usrLogin,
        DateOnly dataInicio,
        DateOnly dataFim,
        IReadOnlyList<(string Ref, string Cor, decimal QuantidadePrevista)> linhas,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<PrevisaoArtigoSugestaoRow>> SugerirArtigosAsync(
        string termo,
        int limit = 20,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<PrevisaoCorSugestaoRow>> SugerirCoresAsync(
        string artigoRef,
        string? termo = null,
        int limit = 30,
        CancellationToken cancellationToken = default);

    Task<PrevisaoEntradaDetalheRow> FecharAsync(
        Guid id,
        string usrLogin,
        CancellationToken cancellationToken = default);

    Task<(PrevisaoEntradaDetalheRow Detalhe, int LinhasAdicionadas)> AtualizarLinhasAsync(
        Guid id,
        string usrLogin,
        CancellationToken cancellationToken = default);
}

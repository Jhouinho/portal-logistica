using Portal.Domain.Encomendas;

namespace Portal.Application.Encomendas;

public sealed record MarcarFechoPickingRequest(bool Fechada);

public sealed record FechoPickingAtualizadaDto(
    string BoStamp,
    bool Fechada,
    int NumeroEncomenda,
    int Ndos);

public sealed record MarcarCheckInRequest(IReadOnlyList<string> BoStamps);

public sealed record CheckInAtualizadaDto(
    string BoStamp,
    bool CheckIn,
    string? CheckInPor,
    DateTime? CheckInEm,
    int NumeroDossier,
    int Ndos);

public sealed record CheckInLoteItemDto(
    string BoStamp,
    bool Ok,
    string? Erro,
    CheckInAtualizadaDto? Resultado);

public sealed record CheckInLoteResponseDto(
    int Total,
    int Sucesso,
    int Falha,
    IReadOnlyList<CheckInLoteItemDto> Resultados);

public interface IPickingDossiersQuery
{
    Task<(IReadOnlyList<EncomendaResumo> Items, int Total)> ListarAsync(
        EncomendasFiltro filtro,
        int seriePickingNdos,
        bool fechada,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<EncomendaLinha>> ListarLinhasAsync(
        string boStamp,
        int seriePickingNdos,
        CancellationToken cancellationToken = default);
}

public interface IPickingDossiersCommands
{
    Task<FechoPickingAtualizadaDto> MarcarFechoAsync(
        string boStamp,
        bool fechada,
        int seriePickingNdos,
        string? usrLogin,
        CancellationToken cancellationToken = default);

    /// <summary>Fecho operacional ndos=65: BO+BI.fechada=1 (sem faturação).</summary>
    Task<FechoPickingAtualizadaDto> FecharExpedicaoAsync(
        string boStamp,
        int serieSeparacaoNdos,
        string? usrLogin,
        CancellationToken cancellationToken = default);

    /// <summary>Reabrir ndos=65: BO+BI.fechada=0.</summary>
    Task<FechoPickingAtualizadaDto> ReabrirExpedicaoAsync(
        string boStamp,
        int serieSeparacaoNdos,
        string? usrLogin,
        CancellationToken cancellationToken = default);

    Task<CheckInAtualizadaDto> MarcarCheckInAsync(
        string boStamp,
        bool checkIn,
        int seriePickingNdos,
        string usrLogin,
        string? usrinis,
        CancellationToken cancellationToken = default);

    Task<CheckInAtualizadaDto> ReverterCheckInAsync(
        string boStamp,
        int seriePickingNdos,
        string usrLogin,
        string? usrinis,
        CancellationToken cancellationToken = default);
}

namespace Portal.Application.Encomendas;

public interface IEncomendasCommands
{
    Task<QuantidadeAutorizadaAtualizadaDto> AtualizarQuantidadeAutorizadaAsync(
        string biStamp,
        decimal quantidadeAutorizada,
        string usrLogin,
        decimal? valorAnteriorEsperado,
        bool permitirAcimaStock = false,
        string? usrinis = null,
        CancellationToken cancellationToken = default);

    Task<LinhaAtualizadaDto> AtualizarLinhaQttPrecoAsync(
        string biStamp,
        decimal? quantidade,
        decimal? precoUnitario,
        string usrinis,
        decimal? quantidadeAnteriorEsperada,
        decimal? precoAnteriorEsperado,
        CancellationToken cancellationToken = default);

    /// <param name="cor">Quando <paramref name="filtrarCor"/> é true, filtra por esta cor ('' = sem cor).</param>
    Task<AlocarArtigoResponseDto> AlocarProporcionalAsync(
        string artigoRef,
        string usrLogin,
        bool simular,
        decimal? quantidadeDisponivel,
        string? cor,
        bool filtrarCor,
        CancellationToken cancellationToken = default);

    Task<ProntaPickingAtualizadaDto> MarcarProntaPickingAsync(
        string boStamp,
        bool pronta,
        string usrLogin,
        string? usrinis = null,
        bool confirmarLinhasSemAutorizacao = false,
        string? motivo = null,
        CancellationToken cancellationToken = default);

    Task<PickWorkflowAtualizadaDto> PickingStartAsync(
        string boStamp,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default);

    Task<PickWorkflowAtualizadaDto> PickingCompleteAsync(
        string boStamp,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default);

    Task<PickWorkflowAtualizadaDto> PickingCancelAsync(
        string boStamp,
        string usrLogin,
        string? usrinis = null,
        string? motivo = null,
        CancellationToken cancellationToken = default);

    Task<PickWorkflowAtualizadaDto> PickingBackToReadyAsync(
        string boStamp,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default);

    Task<PickWorkflowAtualizadaDto> PickingReopenAsync(
        string boStamp,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default);

    Task<UrgenteAtualizadaDto> MarcarUrgenteAsync(
        string boStamp,
        bool urgente,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default);

    Task<CancelarEncomendaAtualizadaDto> CancelarEncomendaAsync(
        string boStamp,
        string motivo,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default);
}

public sealed class PortalBusinessException : Exception
{
    public int StatusCode { get; }

    public PortalBusinessException(string message, int statusCode = 400) : base(message)
    {
        StatusCode = statusCode;
    }
}

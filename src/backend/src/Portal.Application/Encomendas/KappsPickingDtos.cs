namespace Portal.Application.Encomendas;

public sealed record KappsPickingLinhaDto(
    string PickingLineKey,
    string Article,
    string Description,
    decimal Quantity,
    /// <summary>Quantidade originalmente pedida (BI2.u_qttorig / BI.qtt) — só informativa.</summary>
    decimal QuantityOriginal,
    decimal QuantitySatisfied,
    decimal QuantityPending,
    decimal QuantityPicked,
    string BaseUnit,
    string BusyUnit,
    int ConversionFator,
    decimal Warehouse,
    string PickingKey,
    decimal OriginalLineNumber,
    string? Location,
    string? Lot,
    int AllowReplacement,
    string? LinObs,
    int HasReservedQty);

public sealed record KappsPickingDetalheDto(
    string PickingKey,
    decimal Number,
    string CustomerName,
    DateTime? Date,
    string Customer,
    string Document,
    string DocumentName,
    string? EXR,
    string? SEC,
    string? TPD,
    decimal? NDC,
    string? DeliveryCustomer,
    string? DeliveryCode,
    string? Barcode,
    int AllowNewProduct,
    int UseSDR,
    /// <summary>Terminal Kapps activo (u_Kapps_DossierLin.TerminalID), se houver.</summary>
    int? ActiveTerminalId,
    /// <summary>Descrição do terminal ou rótulo «Terminal N».</summary>
    string? ActiveTerminalLabel,
    /// <summary>UserID Kapps na última actividade do dossier.</summary>
    string? ActiveUserId,
    IReadOnlyList<KappsPickingLinhaDto> Lines);

public interface IKappsPickingQuery
{
    /// <summary>
    /// Confirma se existe documento bo com o ndos indicado.
    /// </summary>
    Task<bool> ExisteBoNaSerieAsync(
        string boStamp,
        int ndos,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Resolve PickingKey Kapps: bostamp da encomenda, ou dossier ndos=66 ligado por obistamp
    /// se for aí que existem linhas Kapps (preferindo o mais avançado / concluído).
    /// </summary>
    Task<string?> ResolverPickingKeyAsync(
        string boStampEncomenda,
        int serieEncomendas,
        int seriePicking,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Lê v_Kapps_Picking_Documents / Lines com PickingKey = bostamp indicado
    /// (encomenda ndos=1 em picking; dossier ndos=66 em separação).
    /// </summary>
    Task<KappsPickingDetalheDto?> ObterDocumentoComLinhasAsync(
        string pickingKey,
        CancellationToken cancellationToken = default);
}

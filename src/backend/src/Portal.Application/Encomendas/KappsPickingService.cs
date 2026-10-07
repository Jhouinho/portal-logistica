using Microsoft.Extensions.Options;

namespace Portal.Application.Encomendas;

/// <summary>
/// Leitura do picking Kapps.
/// Em Picking: PickingKey = bostamp da encomenda (ndos=1) ou, se o Kapps picou no dossier,
/// o bostamp do ndos=66 ligado por BI.obistamp.
/// Em Separação: PickingKey = bostamp do dossier (ndos picking / 66).
/// </summary>
public sealed class KappsPickingService
{
    private readonly IKappsPickingQuery _query;
    private readonly IEncomendasQuery _encomendasQuery;
    private readonly int _serieEncomendas;
    private readonly int _seriePicking;

    public KappsPickingService(
        IKappsPickingQuery query,
        IEncomendasQuery encomendasQuery,
        IOptions<SerieEncomendasSettings> serie)
    {
        _query = query;
        _encomendasQuery = encomendasQuery;
        _serieEncomendas = serie.Value.SerieEncomendasNdos;
        _seriePicking = serie.Value.SeriePickingNdos;
    }

    public async Task<KappsPickingLookupResult> ObterPorEncomendaAsync(
        string boStampEncomenda,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(boStampEncomenda))
            return KappsPickingLookupResult.NaoEncontrado();

        var stamp = boStampEncomenda.Trim();

        var (cab, _) = await _encomendasQuery.ObterDetalheAsync(stamp, _serieEncomendas, cancellationToken);
        if (cab is null)
            return KappsPickingLookupResult.NaoEncontrado();

        // PickingKey: bostamp da encomenda, ou dossier 66 ligado (obistamp) se for aí que o Kapps picou.
        var pickingKey = await _query.ResolverPickingKeyAsync(
            stamp,
            _serieEncomendas,
            _seriePicking,
            cancellationToken);
        if (string.IsNullOrWhiteSpace(pickingKey))
            return KappsPickingLookupResult.SemPicking();

        var detalhe = await _query.ObterDocumentoComLinhasAsync(pickingKey, cancellationToken);
        if (detalhe is null)
            return KappsPickingLookupResult.SemPicking();

        return KappsPickingLookupResult.Ok(detalhe);
    }

    /// <summary>
    /// Kapps associado a um dossier de separação (ndos = SeriePickingNdos).
    /// PickingKey = bostamp do dossier.
    /// </summary>
    public async Task<KappsPickingLookupResult> ObterPorDossierAsync(
        string boStampDossier,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(boStampDossier))
            return KappsPickingLookupResult.NaoEncontrado();

        var stamp = boStampDossier.Trim();

        var existe = await _query.ExisteBoNaSerieAsync(stamp, _seriePicking, cancellationToken);
        if (!existe)
            return KappsPickingLookupResult.NaoEncontrado();

        var detalhe = await _query.ObterDocumentoComLinhasAsync(stamp, cancellationToken);
        if (detalhe is null)
            return KappsPickingLookupResult.SemPicking();

        return KappsPickingLookupResult.Ok(detalhe);
    }
}

public sealed class KappsPickingLookupResult
{
    public bool Existe { get; private init; }
    public KappsPickingDetalheDto? Detalhe { get; private init; }

    /// <summary>Alias legado — equivale a <see cref="Existe"/>.</summary>
    public bool EncomendaExiste => Existe;

    public static KappsPickingLookupResult NaoEncontrado() =>
        new() { Existe = false, Detalhe = null };

    public static KappsPickingLookupResult EncomendaNaoEncontrada() => NaoEncontrado();

    public static KappsPickingLookupResult SemPicking() =>
        new() { Existe = true, Detalhe = null };

    public static KappsPickingLookupResult Ok(KappsPickingDetalheDto detalhe) =>
        new() { Existe = true, Detalhe = detalhe };
}

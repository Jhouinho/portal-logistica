namespace Portal.Application.Encomendas;

public sealed record EncomendaListaItemDto(
    string BoStamp,
    int NumeroEncomenda,
    /// <summary>Nº do dossier (ndos 66/65) listado.</summary>
    int? NumeroDossier,
    /// <summary>Nome da série do dossier (nmdos).</summary>
    string? NomeDossier,
    int ClienteNo,
    string ClienteNome,
    /// <summary>BO.nome2 — nome principal na apresentação (PR5).</summary>
    string? ClienteNome2,
    string Data,
    string Hora,
    int TotalLinhas,
    decimal QuantidadeTotal,
    decimal QuantidadePorSatisfazer,
    string Estado,
    string EstadoPlaneamento,
    string EstadoPlaneamentoCodigo,
    bool ProntaPicking,
    string? ProntaPickingPor,
    DateTime? ProntaPickingEm,
    int PickStatus,
    bool Urgente,
    bool CheckIn = false,
    string? CheckInPor = null,
    DateTime? CheckInEm = null,
    /// <summary>BO3.TAXPOINTDT — data de entrega (leitura).</summary>
    DateTime? DataEntrega = null,
    /// <summary>BO3.u_modExp — método de expedição (leitura PHC).</summary>
    string? MetodoExpedicao = null,
    /// <summary>Nº dossier picking (ndos=66), quando resolvido na cadeia.</summary>
    int? NumeroPicking = null,
    /// <summary>Nº dossier separação/expedição (ndos=65), quando resolvido na cadeia.</summary>
    int? NumeroSeparacao = null,
    /// <summary>SUM(BI.qtt) — quantidade do documento (expedição; Separado).</summary>
    decimal QuantidadeDocumento = 0,
    /// <summary>SUM(BI.qtt2) — quantidade já expedida (Separado).</summary>
    decimal QuantidadeExpedida = 0,
    /// <summary>SUM(BI.qtt − BI.qtt2) — pendente de entrega (Separado).</summary>
    decimal QuantidadePendenteEntrega = 0,
    /// <summary>BO2.u_mEntrega — morada de entrega (texto corrido; null se vazio).</summary>
    string? MoradaEntrega = null,
    /// <summary>REGRA B: existe quantidade materializada em ndos=66 (SUM qtt &gt; 0).</summary>
    bool TemQtt66 = false);

public sealed record EncomendaListaResponseDto(
    int Page,
    int PageSize,
    int Total,
    IReadOnlyList<EncomendaListaItemDto> Items);

public sealed record EncomendaLinhaDto(
    string BiStamp,
    string Ref,
    string Descricao,
    string Cor,
    string Unidade,
    decimal Quantidade,
    decimal QuantidadeOriginalPortal,
    decimal Qtt,
    decimal Qtt2,
    decimal QuantidadePorSatisfazer,
    decimal PrecoUnitario,
    decimal PrecoUnitarioOriginal,
    decimal QuantidadeAutorizada,
    string? AutorizadaPor,
    DateTime? AutorizadaEm,
    decimal StockDisponivel,
    string? Usrinis,
    string? Usrdata,
    string? Usrhora,
    /// <summary>STOBS.u_dispPort. Default true quando a origem não carrega o campo.</summary>
    bool DisponivelNoPortal = true);

public sealed record EncomendaDetalheDto(
    string BoStamp,
    int NumeroEncomenda,
    int Serie,
    string NomeSerie,
    int ClienteNo,
    int ClienteEstab,
    string ClienteNome,
    /// <summary>BO.nome2 — nome principal na apresentação (PR5).</summary>
    string? ClienteNome2,
    string Data,
    string Hora,
    string EstadoPlaneamento,
    string EstadoPlaneamentoCodigo,
    bool ProntaPicking,
    string? ProntaPickingPor,
    DateTime? ProntaPickingEm,
    int PickStatus,
    bool Urgente,
    /// <summary>BO3.TAXPOINTDT — data de entrega (leitura).</summary>
    DateTime? DataEntrega,
    /// <summary>BO3.u_modExp — método de expedição (leitura PHC).</summary>
    string? MetodoExpedicao,
    /// <summary>BO2.u_mEntrega — morada de entrega (texto corrido; null se vazio).</summary>
    string? MoradaEntrega,
    IReadOnlyList<EncomendaLinhaDto> Linhas,
    /// <summary>REGRA B: existe quantidade materializada em ndos=66 (SUM qtt &gt; 0).</summary>
    bool TemQtt66 = false);

public sealed class EncomendasFiltro
{
    public DateTime? DataDe { get; init; }
    public DateTime? DataAte { get; init; }
    public string? HoraDe { get; init; }
    public string? HoraAte { get; init; }
    public int? ClienteNo { get; init; }
    /// <summary>Contém no nº de cliente (texto).</summary>
    public string? ClienteNoContem { get; init; }
    /// <summary>Contém no nome do cliente (BO.nome).</summary>
    public string? ClienteNomeContem { get; init; }
    public string? ArtigoRef { get; init; }
    public string? ArtigoCor { get; init; }
    public string? EstadoPlaneamento { get; init; }
    /// <summary>
    /// Filtro BO3.u_modExp: valor PHC exacto, ou <c>nao_definido</c> (vazio), ou omitido/Todos.
    /// </summary>
    public string? MetodoExpedicao { get; init; }
    /// <summary>false = por tratar; true = prontas para picking.</summary>
    public bool? ProntaPicking { get; init; }
    /// <summary>Filtro opcional de BO3.u_pickstat (0–3). Só relevante com ProntaPicking.</summary>
    public int? PickStatus { get; init; }
    /// <summary>Filtro opcional BO3.u_chkin (dossiers ndos=66).</summary>
    public bool? CheckIn { get; init; }
    /// <summary>
    /// Quando true (listagem picking/separação): só dossiers com SUM(BI.qtt−BI.qtt2) &gt; 0.
    /// Usado por «Quantidades não entregues» (ndos=66 fechados).
    /// </summary>
    public bool ApenasComPendenteEntrega { get; init; }
    /// <summary>Filtro opcional por nº documento (obrano / origem na cadeia).</summary>
    public int? Obrano { get; init; }
    public int Page { get; init; } = 1;
    public int PageSize { get; init; } = 50;
}

public sealed record AtualizarQuantidadeAutorizadaRequest(
    decimal QuantidadeAutorizada,
    decimal? ValorAnteriorEsperado,
    bool PermitirAcimaStock = false);

public sealed record MarcarProntaPickingRequest(
    bool Pronta,
    bool ConfirmarLinhasSemAutorizacao = false,
    /// <summary>Obrigatório ao cancelar (Pronta=false). Máx. 254 chars → BO3.u_pickcobs.</summary>
    string? Motivo = null);

public sealed record CancelPickingRequest(
    /// <summary>Motivo obrigatório. Máx. 254 chars → BO3.u_pickcobs.</summary>
    string Motivo);

public sealed record CancelarEncomendaRequest(
    /// <summary>Motivo obrigatório. Máx. 254 chars → BO3.u_pickcobs.</summary>
    string Motivo);

public sealed record CancelarEncomendaAtualizadaDto(
    string BoStamp,
    bool Fechada,
    int NumeroEncomenda,
    string? Motivo);

public sealed record MarcarUrgenteRequest(bool Urgente);

public sealed record UrgenteAtualizadaDto(string BoStamp, bool Urgente);

public sealed record ProntaPickingAtualizadaDto(
    string BoStamp,
    bool ProntaPicking,
    string? ProntaPickingPor,
    DateTime? ProntaPickingEm,
    int PickStatus);

public sealed record PickWorkflowAtualizadaDto(
    string BoStamp,
    bool ProntaPicking,
    int PickStatus,
    string? ProntaPickingPor,
    DateTime? ProntaPickingEm);

public sealed record QuantidadeAutorizadaAtualizadaDto(
    string BiStamp,
    decimal QuantidadeAutorizada,
    string? AutorizadaPor,
    DateTime? AutorizadaEm,
    decimal Quantidade,
    decimal QuantidadeOriginalPortal,
    decimal QuantidadePorSatisfazer,
    bool PrimeiraAutorizacao);

public sealed record AtualizarLinhaRequest(
    decimal? Quantidade,
    decimal? PrecoUnitario,
    decimal? QuantidadeAnteriorEsperada,
    decimal? PrecoAnteriorEsperado);

public sealed record LinhaAtualizadaDto(
    string BiStamp,
    decimal Quantidade,
    decimal QuantidadeOriginalPortal,
    decimal PrecoUnitario,
    decimal PrecoUnitarioOriginal,
    string? Usrinis,
    string? Usrdata,
    string? Usrhora);

public sealed record ArtigoProcuraItemDto(
    string Ref,
    string Descricao,
    string Cor,
    decimal QuantidadeEncomendada,
    decimal QuantidadeFornecida,
    decimal QuantidadePorSatisfazer,
    decimal QuantidadeDisponivel,
    decimal QuantidadeAutorizadaTotal,
    int TotalLinhas,
    int TotalEncomendas,
    string EstadoPlaneamento,
    string EstadoPlaneamentoCodigo,
    bool Urgente);

public sealed record ArtigoProcuraResponseDto(
    IReadOnlyList<ArtigoProcuraItemDto> Items,
    int Page = 1,
    int PageSize = 0,
    int TotalItems = 0);

public sealed record ArtigoEncomendaAbertaItemDto(
    string BoStamp,
    string BiStamp,
    int NumeroEncomenda,
    int ClienteNo,
    string ClienteNome,
    /// <summary>BO.nome2 — nome principal na apresentação (PR5).</summary>
    string? ClienteNome2,
    string Data,
    string Hora,
    string EstadoPlaneamento,
    string EstadoPlaneamentoCodigo,
    string Ref,
    string Descricao,
    string Cor,
    string Unidade,
    decimal Quantidade,
    decimal QuantidadeOriginalPortal,
    decimal Qtt,
    decimal Qtt2,
    decimal QuantidadePorSatisfazer,
    decimal PrecoUnitario,
    decimal PrecoUnitarioOriginal,
    decimal QuantidadeAutorizada,
    string? AutorizadaPor,
    DateTime? AutorizadaEm,
    decimal StockDisponivel,
    string? Usrinis,
    string? Usrdata,
    string? Usrhora,
    bool Urgente,
    /// <summary>BO3.TAXPOINTDT — data de entrega (leitura).</summary>
    DateTime? DataEntrega = null,
    /// <summary>BO3.u_modExp — método de expedição (leitura PHC).</summary>
    string? MetodoExpedicao = null);

public sealed record ArtigoEncomendasAbertasResponseDto(
    string Ref,
    string? Cor,
    string Descricao,
    decimal QuantidadeDisponivel,
    IReadOnlyList<ArtigoEncomendaAbertaItemDto> Encomendas);

public sealed record AlocarArtigoRequest(
    decimal? QuantidadeDisponivel,
    string? Cor,
    string? Modo = "Proporcional",
    bool Confirmar = true);

public sealed record AlocacaoLinhaDto(
    string BiStamp,
    string BoStamp,
    int NumeroEncomenda,
    decimal QuantidadePorSatisfazer,
    decimal QuantidadeProposta);

/// <summary>PR2-A: FonteStock = u_HcaPrevEntrada (teto operacional; nome de contrato legado).</summary>
public sealed record AlocarArtigoResponseDto(
    string Ref,
    decimal StockDisponivel,
    decimal QuantidadeDisponivel,
    string FonteStock,
    bool Simular,
    decimal SomaProposta,
    IReadOnlyList<AlocacaoLinhaDto> Alocacoes);

public sealed class CortesQuantidadeFiltro
{
    public DateTime? DataDe { get; init; }
    public DateTime? DataAte { get; init; }
    public int? Obrano { get; init; }
    public string? ArtigoRef { get; init; }
    public string? ArtigoCor { get; init; }
    public int Page { get; init; } = 1;
    public int PageSize { get; init; } = 50;
}

public sealed record CorteEncomendaItemDto(
    string BoStamp,
    int NumeroEncomenda,
    /// <summary>Nº do dossier 66 (quando aplicável).</summary>
    int? NumeroDossier,
    string? NomeDossier,
    string Data,
    string Hora,
    int ClienteNo,
    string ClienteNome,
    string? ClienteNome2,
    int TotalLinhas,
    decimal QuantidadeDocumento,
    decimal QuantidadeExpedida,
    decimal QuantidadePendenteEntrega,
    bool Fechada,
    bool Urgente,
    string Estado);

public sealed record CorteQuantidadeLinhaDto(
    string BiStamp,
    string BoStamp,
    string Ref,
    string Descricao,
    string Cor,
    string Unidade,
    decimal QuantidadeDocumento,
    decimal QuantidadeExpedida,
    decimal QuantidadePendenteEntrega);

public sealed record CortesQuantidadeResponseDto(
    int Page,
    int PageSize,
    int Total,
    IReadOnlyList<CorteEncomendaItemDto> Items);

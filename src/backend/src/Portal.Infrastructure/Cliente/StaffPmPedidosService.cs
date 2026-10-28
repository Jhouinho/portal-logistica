using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Portal.Application.Cliente;
using Portal.Application.Encomendas;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.Cliente;

public sealed class StaffPmPedidosService : IStaffPmPedidosService
{
    private readonly IClientePmPedidoStore _store;
    private readonly IStaffPmBo67Gateway _bo67;
    private readonly PortalClienteOptions _cliente;
    private readonly ILogger<StaffPmPedidosService> _log;

    public StaffPmPedidosService(
        IClientePmPedidoStore store,
        IStaffPmBo67Gateway bo67,
        IOptions<PortalClienteOptions> cliente,
        ILogger<StaffPmPedidosService> log)
    {
        _store = store;
        _bo67 = bo67;
        _cliente = cliente.Value;
        _log = log;
    }

    public async Task<IReadOnlyList<StaffPmPedidoListaItemDto>> ListarAsync(
        string? filtroEstado,
        int top,
        CancellationToken cancellationToken)
    {
        var rows = await _store.ListarStaffAsync(filtroEstado, top, cancellationToken);
        return rows.Select(ToLista).ToList();
    }

    public async Task<StaffPmPedidoDetalheDto?> ObterAsync(
        long pedidoId,
        CancellationToken cancellationToken)
    {
        var p = await _store.ObterPorIdStaffAsync(pedidoId, incluirLinhas: true, cancellationToken);
        return p is null ? null : ToDetalhe(p);
    }

    public async Task<StaffPmPedidoDetalheDto> GuardarPrecosAsync(
        long pedidoId,
        IReadOnlyList<StaffPmPrecoLinhaRequest> linhas,
        CancellationToken cancellationToken)
    {
        if (pedidoId <= 0)
            throw new PortalBusinessException("Pedido inválido.");

        var pedido = await _store.ObterPorIdStaffAsync(pedidoId, incluirLinhas: true, cancellationToken)
            ?? throw new PortalBusinessException("Pedido não encontrado.", statusCode: 404);

        if (!StaffPmPrecoRules.CanEditPrecos(pedido.EstadoInterno, pedido.Bostamp))
        {
            throw new PortalBusinessException(
                "Preços só podem ser editados enquanto o pedido estiver pendente de análise.",
                statusCode: 409);
        }

        var existentes = pedido.Linhas ?? Array.Empty<ClientePmLinhaPersistida>();
        var pedidos = (linhas ?? Array.Empty<StaffPmPrecoLinhaRequest>())
            .Select(l => (l.LinhaOrd, l.PrecoUnitario))
            .ToList();

        var err = StaffPmPrecoRules.ValidatePrecosOperador(existentes, pedidos);
        if (err is not null)
            throw new PortalBusinessException(err);

        var mark = await _store.TryAtualizarPrecosOperadorAsync(pedidoId, pedidos, cancellationToken);
        if (!mark.Updated || mark.Pedido is null)
        {
            throw new PortalBusinessException(
                "O estado do pedido mudou — preços não foram gravados. Actualize e tente novamente.",
                statusCode: 409);
        }

        return ToDetalhe(mark.Pedido);
    }

    public async Task<StaffPmPedidoDetalheDto> GuardarLinhasAsync(
        long pedidoId,
        IReadOnlyList<StaffPmLinhaEditRequest> linhas,
        CancellationToken cancellationToken)
    {
        if (pedidoId <= 0)
            throw new PortalBusinessException("Pedido inválido.");

        var pedido = await _store.ObterPorIdStaffAsync(pedidoId, incluirLinhas: true, cancellationToken)
            ?? throw new PortalBusinessException("Pedido não encontrado.", statusCode: 404);

        if (!StaffPmPrecoRules.CanEditPrecos(pedido.EstadoInterno, pedido.Bostamp))
        {
            throw new PortalBusinessException(
                "As linhas só podem ser editadas enquanto o pedido estiver pendente de análise.",
                statusCode: 409);
        }

        var pedidos = linhas ?? Array.Empty<StaffPmLinhaEditRequest>();
        var err = StaffPmPrecoRules.ValidateLinhasOperador(pedidos);
        if (err is not null)
            throw new PortalBusinessException(err);

        var mark = await _store.TrySubstituirLinhasOperadorAsync(pedidoId, pedidos, cancellationToken);
        if (!mark.Updated || mark.Pedido is null)
        {
            throw new PortalBusinessException(
                "O estado do pedido mudou — linhas não foram gravadas. Actualize e tente novamente.",
                statusCode: 409);
        }

        return ToDetalhe(mark.Pedido);
    }

    public async Task<StaffPmAprovarResultDto> AprovarAsync(
        long pedidoId,
        string usrinis,
        string? decididoPor,
        CancellationToken cancellationToken)
    {
        if (pedidoId <= 0)
            throw new PortalBusinessException("Pedido inválido.");

        var pedido = await _store.ObterPorIdStaffAsync(pedidoId, incluirLinhas: true, cancellationToken)
            ?? throw new PortalBusinessException("Pedido não encontrado.", statusCode: 404);

        if (StaffPmPedidoRules.IsBlockedFromApprove(pedido.EstadoInterno))
        {
            throw new PortalBusinessException(
                "Pedido rejeitado ou cancelado — não pode ser aprovado.",
                statusCode: 409);
        }

        if (StaffPmPedidoRules.IsIntegradoCompleto(pedido.EstadoInterno, pedido.Bostamp))
        {
            return ToAprovarResult(pedido, alreadyIntegrated: true, alreadyExistsBo: true);
        }

        string bostamp;
        decimal obrano;
        decimal boano;
        decimal ndos;
        bool alreadyExistsBo;

        if (StaffPmPedidoRules.NeedsReconcile(pedido.EstadoInterno, pedido.Bostamp))
        {
            bostamp = pedido.Bostamp!;
            obrano = pedido.Obrano ?? 0;
            boano = pedido.Boano ?? DateTime.UtcNow.Year;
            ndos = pedido.Ndos ?? _cliente.PedidoMobileNdos;
            alreadyExistsBo = true;
        }
        else if (StaffPmPedidoRules.CanCreateBo67(pedido.EstadoInterno, pedido.Bostamp))
        {
            pedido = await AssegurarClaimAprovacaoAsync(pedido, cancellationToken);

            if (StaffPmPedidoRules.IsIntegradoCompleto(pedido.EstadoInterno, pedido.Bostamp))
            {
                return ToAprovarResult(pedido, alreadyIntegrated: true, alreadyExistsBo: true);
            }

            if (StaffPmPedidoRules.NeedsReconcile(pedido.EstadoInterno, pedido.Bostamp))
            {
                bostamp = pedido.Bostamp!;
                obrano = pedido.Obrano ?? 0;
                boano = pedido.Boano ?? DateTime.UtcNow.Year;
                ndos = pedido.Ndos ?? _cliente.PedidoMobileNdos;
                alreadyExistsBo = true;
            }
            else if (StaffPmPedidoRules.CanContinueBo67(pedido.EstadoInterno, pedido.Bostamp))
            {
                var linhas = pedido.Linhas ?? Array.Empty<ClientePmLinhaPersistida>();
                var precoErr = StaffPmPrecoRules.ValidatePrecosParaAprovacao(linhas);
                if (precoErr is not null)
                    throw new PortalBusinessException(precoErr);

                var usr = string.IsNullOrWhiteSpace(usrinis) ? "PRT" : usrinis.Trim();
                if (usr.Length > 3) usr = usr[..3];

                var sp = await _bo67.CriarAsync(pedido, usr, cancellationToken);
                bostamp = sp.Bostamp;
                obrano = sp.Obrano;
                boano = sp.Boano;
                ndos = sp.Ndos;
                alreadyExistsBo = sp.AlreadyExists;
            }
            else
            {
                throw new PortalBusinessException(
                    "O estado do pedido mudou — não foi possível iniciar a aprovação.",
                    statusCode: 409);
            }
        }
        else
        {
            throw new PortalBusinessException(
                "Pedido não está pendente de aprovação.",
                statusCode: 409);
        }

        var mark = await _store.TryMarcarIntegradoAsync(
            pedidoId, bostamp, obrano, boano, ndos, decididoPor, cancellationToken);

        var final = mark.Pedido
            ?? await _store.ObterPorIdStaffAsync(pedidoId, incluirLinhas: false, cancellationToken)
            ?? throw new PortalBusinessException(
                "Dossier PHC criado mas falhou a actualização do pedido interno. Contacte suporte com o PedidoId.",
                statusCode: 503);

        if (!StaffPmPedidoRules.IsIntegradoCompleto(final.EstadoInterno, final.Bostamp))
        {
            _log.LogError(
                "Aprovação PedidoId={PedidoId}: BO {Bostamp} criado mas estado={Estado}.",
                pedidoId, bostamp, final.EstadoInterno);
            throw new PortalBusinessException(
                "Dossier PHC criado mas o pedido interno não ficou integrado. Tente aprovar novamente (operação idempotente).",
                statusCode: 503);
        }

        return ToAprovarResult(final, alreadyIntegrated: !mark.Updated, alreadyExistsBo);
    }

    private async Task<ClientePmPedidoPersistido> AssegurarClaimAprovacaoAsync(
        ClientePmPedidoPersistido pedido,
        CancellationToken cancellationToken)
    {
        if (StaffPmPedidoRules.CanContinueBo67(pedido.EstadoInterno, pedido.Bostamp))
            return pedido;

        if (!StaffPmPedidoRules.IsPendente(pedido.EstadoInterno, pedido.Bostamp))
        {
            throw new PortalBusinessException(
                "Pedido não está pendente de aprovação.",
                statusCode: 409);
        }

        var claim = await _store.TryClaimAprovacaoAsync(pedido.PedidoId, cancellationToken);
        if (claim.Updated && claim.Pedido is not null)
            return claim.Pedido;

        var actual = await _store.ObterPorIdStaffAsync(pedido.PedidoId, incluirLinhas: true, cancellationToken)
            ?? throw new PortalBusinessException("Pedido não encontrado.", statusCode: 404);

        if (StaffPmPedidoRules.IsBlockedFromApprove(actual.EstadoInterno))
        {
            throw new PortalBusinessException(
                "Pedido rejeitado ou cancelado — não pode ser aprovado.",
                statusCode: 409);
        }

        if (StaffPmPedidoRules.IsIntegradoCompleto(actual.EstadoInterno, actual.Bostamp)
            || StaffPmPedidoRules.NeedsReconcile(actual.EstadoInterno, actual.Bostamp)
            || StaffPmPedidoRules.CanContinueBo67(actual.EstadoInterno, actual.Bostamp))
            return actual;

        throw new PortalBusinessException(
            "O estado do pedido mudou — não foi possível iniciar a aprovação.",
            statusCode: 409);
    }

    public async Task<StaffPmRejeitarResultDto> RejeitarAsync(
        long pedidoId,
        string? motivo,
        string? decididoPor,
        CancellationToken cancellationToken)
    {
        if (pedidoId <= 0)
            throw new PortalBusinessException("Pedido inválido.");

        var pedido = await _store.ObterPorIdStaffAsync(pedidoId, incluirLinhas: false, cancellationToken)
            ?? throw new PortalBusinessException("Pedido não encontrado.", statusCode: 404);

        if (StaffPmPedidoRules.IsIntegradoCompleto(pedido.EstadoInterno, pedido.Bostamp)
            || StaffPmPedidoRules.NeedsReconcile(pedido.EstadoInterno, pedido.Bostamp))
        {
            throw new PortalBusinessException(
                "Pedido já tem dossier PHC — não pode ser rejeitado.",
                statusCode: 409);
        }

        if (StaffPmPedidoRules.IsEmAprovacao(pedido.EstadoInterno))
        {
            throw new PortalBusinessException(
                "Aprovação em curso — o pedido não pode ser rejeitado.",
                statusCode: 409);
        }

        if (StaffPmPedidoRules.NormalizeEstado(pedido.EstadoInterno) == StaffPmPedidoRules.EstadoRejeitado)
        {
            var (c0, e0, _) = ClientePedidoEstadoMapper.MapInterno(pedido.EstadoInterno);
            return new StaffPmRejeitarResultDto(
                pedido.PedidoId, pedido.NumeroInterno, pedido.EstadoInterno, c0, e0, pedido.MotivoRejeicao);
        }

        if (!StaffPmPedidoRules.CanReject(pedido.EstadoInterno, pedido.Bostamp))
        {
            throw new PortalBusinessException(
                "Pedido não está pendente de rejeição.",
                statusCode: 409);
        }

        var mark = await _store.TryRejeitarAsync(pedidoId, motivo, decididoPor, cancellationToken);
        var final = mark.Pedido
            ?? throw new PortalBusinessException("Não foi possível rejeitar o pedido.", statusCode: 409);

        if (StaffPmPedidoRules.NormalizeEstado(final.EstadoInterno) != StaffPmPedidoRules.EstadoRejeitado)
        {
            throw new PortalBusinessException(
                "O estado do pedido mudou — não foi rejeitado. Actualize e tente novamente.",
                statusCode: 409);
        }

        var (codigo, etiqueta, _) = ClientePedidoEstadoMapper.MapInterno(final.EstadoInterno);
        return new StaffPmRejeitarResultDto(
            final.PedidoId,
            final.NumeroInterno,
            final.EstadoInterno,
            codigo,
            etiqueta,
            final.MotivoRejeicao);
    }

    public async Task<StaffPmOperacaoResultDto> AvancarOperacaoAsync(
        long pedidoId,
        string? acao,
        string? decididoPor,
        CancellationToken cancellationToken)
    {
        if (pedidoId <= 0)
            throw new PortalBusinessException("Pedido inválido.");

        var a = (acao ?? "").Trim().ToLowerInvariant();
        var destino = a switch
        {
            "pronto_levantamento" or "pronto-levantamento" => StaffPmPedidoRules.EstadoProntoLevantamento,
            "concluir" or "concluido" => StaffPmPedidoRules.EstadoConcluido,
            _ => throw new PortalBusinessException(
                "Acção inválida. Use pronto_levantamento ou concluir.",
                statusCode: 400)
        };

        var pedido = await _store.ObterPorIdStaffAsync(pedidoId, incluirLinhas: false, cancellationToken)
            ?? throw new PortalBusinessException("Pedido não encontrado.", statusCode: 404);

        // Idempotente: já no destino
        if (StaffPmPedidoRules.NormalizeEstado(pedido.EstadoInterno) == destino)
        {
            var (c0, e0, _) = ClientePedidoEstadoMapper.MapInterno(pedido.EstadoInterno);
            return new StaffPmOperacaoResultDto(
                pedido.PedidoId, pedido.NumeroInterno, pedido.EstadoInterno, c0, e0);
        }

        if (destino == StaffPmPedidoRules.EstadoProntoLevantamento
            && !StaffPmPedidoRules.CanMarcarProntoLevantamento(pedido.EstadoInterno, pedido.Bostamp))
        {
            throw new PortalBusinessException(
                "Só pedidos em separação (com dossier PHC) podem passar a «Pronto para levantamento».",
                statusCode: 409);
        }

        if (destino == StaffPmPedidoRules.EstadoConcluido
            && !StaffPmPedidoRules.CanMarcarConcluido(pedido.EstadoInterno, pedido.Bostamp))
        {
            throw new PortalBusinessException(
                "Só pedidos «Pronto para levantamento» podem ser concluídos.",
                statusCode: 409);
        }

        var mark = await _store.TryAvancarEstadoOperacionalAsync(
            pedidoId, destino, decididoPor, cancellationToken);

        var final = mark.Pedido
            ?? throw new PortalBusinessException(
                "O estado do pedido mudou — actualize e tente novamente.",
                statusCode: 409);

        if (StaffPmPedidoRules.NormalizeEstado(final.EstadoInterno) != destino)
        {
            throw new PortalBusinessException(
                "O estado do pedido mudou — actualize e tente novamente.",
                statusCode: 409);
        }

        var (codigo, etiqueta, _) = ClientePedidoEstadoMapper.MapInterno(final.EstadoInterno);
        return new StaffPmOperacaoResultDto(
            final.PedidoId, final.NumeroInterno, final.EstadoInterno, codigo, etiqueta);
    }

    private static StaffPmPedidoListaItemDto ToLista(ClientePmPedidoPersistido p)
    {
        var (codigo, etiqueta, _) = ClientePedidoEstadoMapper.MapInterno(p.EstadoInterno);
        return new StaffPmPedidoListaItemDto(
            p.PedidoId,
            p.NumeroInterno,
            p.ClNo,
            p.ClEstab,
            p.ClienteNome?.Trim() ?? "",
            p.EstadoInterno,
            codigo,
            etiqueta,
            p.DataSubmissao,
            p.Etotaldeb,
            p.Bostamp,
            p.Obrano,
            p.Ndos,
            StaffPmPedidoRules.ShowApproveAction(p.EstadoInterno, p.Bostamp),
            StaffPmPedidoRules.CanReject(p.EstadoInterno, p.Bostamp),
            StaffPmPedidoRules.CanMarcarProntoLevantamento(p.EstadoInterno, p.Bostamp),
            StaffPmPedidoRules.CanMarcarConcluido(p.EstadoInterno, p.Bostamp));
    }

    private static StaffPmPedidoDetalheDto ToDetalhe(ClientePmPedidoPersistido p)
    {
        var (codigo, etiqueta, _) = ClientePedidoEstadoMapper.MapInterno(p.EstadoInterno);
        var linhas = (p.Linhas ?? Array.Empty<ClientePmLinhaPersistida>())
            .Select(l =>
            {
                var sub = l.PrecoSubmissao ?? l.PrecoUnitario;
                return new StaffPmPedidoLinhaDto(
                    l.LinhaOrd, l.Ref, l.Design, l.Cor, l.Qtt, sub, l.PrecoUnitario, l.TotalLinha);
            })
            .ToList();

        return new StaffPmPedidoDetalheDto(
            p.PedidoId,
            p.NumeroInterno,
            p.ClNo,
            p.ClEstab,
            p.ClienteNome?.Trim() ?? "",
            p.EstadoInterno,
            codigo,
            etiqueta,
            p.DataSubmissao,
            p.DataAlteracao,
            p.Etotaldeb,
            p.Bostamp,
            p.Obrano,
            p.Boano,
            p.Ndos,
            p.MotivoRejeicao,
            p.DecididoPor,
            p.DataDecisao,
            StaffPmPedidoRules.ShowApproveAction(p.EstadoInterno, p.Bostamp),
            StaffPmPedidoRules.CanReject(p.EstadoInterno, p.Bostamp),
            StaffPmPrecoRules.CanEditPrecos(p.EstadoInterno, p.Bostamp),
            StaffPmPedidoRules.CanMarcarProntoLevantamento(p.EstadoInterno, p.Bostamp),
            StaffPmPedidoRules.CanMarcarConcluido(p.EstadoInterno, p.Bostamp),
            linhas);
    }

    private static StaffPmAprovarResultDto ToAprovarResult(
        ClientePmPedidoPersistido p,
        bool alreadyIntegrated,
        bool alreadyExistsBo)
    {
        var (codigo, etiqueta, _) = ClientePedidoEstadoMapper.MapInterno(p.EstadoInterno);
        return new StaffPmAprovarResultDto(
            p.PedidoId,
            p.NumeroInterno,
            p.EstadoInterno,
            codigo,
            etiqueta,
            p.Bostamp ?? "",
            p.Obrano ?? 0,
            p.Boano ?? 0,
            p.Ndos ?? 0,
            alreadyIntegrated,
            alreadyExistsBo);
    }
}

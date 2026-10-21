namespace Portal.Application.Cliente;

/// <summary>Criação do dossier PHC ndos=67 (SP). Testável sem SQL Server.</summary>
public interface IStaffPmBo67Gateway
{
    Task<StaffPmBo67CreateResult> CriarAsync(
        ClientePmPedidoPersistido pedido,
        string usrinis,
        CancellationToken cancellationToken);
}

public sealed record StaffPmBo67CreateResult(
    bool AlreadyExists,
    string Bostamp,
    decimal Obrano,
    decimal Boano,
    decimal Ndos);

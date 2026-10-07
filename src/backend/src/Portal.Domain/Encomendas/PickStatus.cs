namespace Portal.Domain.Encomendas;

/// <summary>
/// Estado operacional de picking na encomenda (BO3.u_pickstat), série ndos=1.
/// </summary>
public enum PickStatus
{
    Open = 0,
    Ready = 1,
    InProgress = 2,
    Completed = 3
}

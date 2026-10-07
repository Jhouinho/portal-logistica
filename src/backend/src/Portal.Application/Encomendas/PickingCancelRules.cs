namespace Portal.Application.Encomendas;

/// <summary>
/// REGRA B — Cancelar/desmarcar Picking bloqueado se existir quantidade materializada em ndos=66.
/// </summary>
public static class PickingCancelRules
{
    /// <summary>
    /// UI lista Em Picking: Cancelar visível só sem qtt em 66 e sem pickingEmAndamento (Kapps).
    /// </summary>
    public static bool PodeCancelarNaUi(bool modoPicking, bool temQtt66, bool pickingEmAndamento)
        => modoPicking && !temQtt66 && !pickingEmAndamento;

    /// <summary>
    /// Desmarcar pronta / cancelar: bloqueado quando já há SUM(66.BI.qtt) &gt; 0.
    /// </summary>
    public static bool CancelamentoBloqueadoPorQtt66(bool temQtt66) => temQtt66;
}

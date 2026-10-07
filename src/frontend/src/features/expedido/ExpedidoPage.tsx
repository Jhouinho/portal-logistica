import { labels } from '../../shared/i18n/labels'
import { EncomendasListPage } from '../encomendas/EncomendasListPage'
import { etapaColors, EtapaPageHeader, EtapaPageShell } from '../centro/portalChrome'

/** Dossiers ndos=65 abertos — recolha/entrega feita no Syslog. */
export function ExpedidoPage() {
  return (
    <EtapaPageShell accent={etapaColors[5]}>
      <EtapaPageHeader
        etapa={5}
        title={labels.expedido}
        hint={labels.expedidoHint}
        accent={etapaColors[5]}
      />
      <EncomendasListPage hideHeader modoDossier="separacao" accentColor={etapaColors[5]} />
    </EtapaPageShell>
  )
}

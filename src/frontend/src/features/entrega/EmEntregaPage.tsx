import { labels } from '../../shared/i18n/labels'
import { EncomendasListPage } from '../encomendas/EncomendasListPage'
import { etapaColors, EtapaPageHeader, EtapaPageShell } from '../centro/portalChrome'

/** Dossiers ndos=66 com Check-in — progresso de recolha (Syslog/Kapps). */
export function EmEntregaPage() {
  return (
    <EtapaPageShell accent={etapaColors[4]}>
      <EtapaPageHeader
        etapa={4}
        title={labels.emEntrega}
        hint={labels.emEntregaHint}
        accent={etapaColors[4]}
      />
      <EncomendasListPage hideHeader modoDossier="emEntrega" accentColor={etapaColors[4]} />
    </EtapaPageShell>
  )
}

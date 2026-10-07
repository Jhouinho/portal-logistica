import { labels } from '../../shared/i18n/labels'
import { EncomendasListPage } from '../encomendas/EncomendasListPage'
import { etapaColors, EtapaPageHeader, EtapaPageShell } from '../centro/portalChrome'

/** Expedições fechadas (ndos=65) — saíram de Em Expedição. */
export function ConcluidasPage() {
  return (
    <EtapaPageShell accent={etapaColors[6]}>
      <EtapaPageHeader
        etapa={6}
        title={labels.concluidas}
        hint={labels.concluidasHint}
        accent={etapaColors[6]}
      />
      <EncomendasListPage hideHeader modoDossier="concluidas" accentColor={etapaColors[6]} />
    </EtapaPageShell>
  )
}

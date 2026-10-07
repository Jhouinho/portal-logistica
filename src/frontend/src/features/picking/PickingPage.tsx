import { labels } from '../../shared/i18n/labels'
import { EncomendasListPage } from '../encomendas/EncomendasListPage'
import { etapaColors, EtapaPageHeader, EtapaPageShell } from '../centro/portalChrome'

export function PickingPage() {
  return (
    <EtapaPageShell accent={etapaColors[2]}>
      <EtapaPageHeader
        etapa={2}
        title={labels.picking}
        hint={labels.pickingHint}
        accent={etapaColors[2]}
      />
      <EncomendasListPage hideHeader modoPicking accentColor={etapaColors[2]} />
    </EtapaPageShell>
  )
}

import { labels } from '../../shared/i18n/labels'
import { EncomendasListPage } from '../encomendas/EncomendasListPage'
import { etapaColors, EtapaPageHeader, EtapaPageShell } from '../centro/portalChrome'

/** Separado — ndos=66 abertos sem Check-in. */
export function ExpedicaoPage() {
  return (
    <EtapaPageShell accent={etapaColors[3]}>
      <EtapaPageHeader
        etapa={3}
        title={labels.expedicao}
        hint={labels.expedicaoHint}
        accent={etapaColors[3]}
      />
      <EncomendasListPage hideHeader modoDossier="expedicao" accentColor={etapaColors[3]} />
    </EtapaPageShell>
  )
}

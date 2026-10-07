import { Box, Tab, Tabs } from '@mui/material'
import { useSearchParams } from 'react-router-dom'
import type { SyntheticEvent } from 'react'
import { labels } from '../../shared/i18n/labels'
import { EncomendasListPage } from './EncomendasListPage'
import { ArtigosResumoPage } from '../artigos/ArtigosResumoPage'
import { etapaColors, EtapaPageHeader, EtapaPageShell } from '../centro/portalChrome'

export type EncomendasVista = 'encomenda' | 'referencia'

function parseVista(raw: string | null): EncomendasVista {
  return raw === 'referencia' ? 'referencia' : 'encomenda'
}

/** Hub Encomendas: vista por encomenda ou por referência (artigo). */
export function EncomendasHubPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const vista = parseVista(searchParams.get('vista'))

  function setVista(_: SyntheticEvent, next: EncomendasVista) {
    if (next === vista) return
    const params = new URLSearchParams(searchParams)
    if (next === 'encomenda') params.delete('vista')
    else params.set('vista', next)
    setSearchParams(params, { replace: true })
  }

  return (
    <EtapaPageShell accent={etapaColors[1]}>
      <EtapaPageHeader
        etapa={1}
        title={labels.encomendas}
        hint={
          vista === 'encomenda'
            ? labels.encomendasVistaEncomendaHint
            : labels.encomendasVistaReferenciaHint
        }
        accent={etapaColors[1]}
      />

      <Tabs
        value={vista}
        onChange={setVista}
        aria-label={labels.encomendasVista}
        sx={{
          mb: 2,
          minHeight: 40,
          flexShrink: 0,
          borderBottom: (theme) => `1px solid ${theme.palette.portal.border}`,
          '& .MuiTab-root': {
            minHeight: 40,
            textTransform: 'none',
            fontWeight: 700,
            letterSpacing: 0.15,
            color: 'text.secondary',
          },
          '& .Mui-selected': { color: `${etapaColors[1]} !important` },
          '& .MuiTabs-indicator': { bgcolor: etapaColors[1], height: 3 },
        }}
      >
        <Tab value="encomenda" label={labels.encomendasVistaEncomenda} />
        <Tab value="referencia" label={labels.encomendasVistaReferencia} />
      </Tabs>

      {vista === 'encomenda' ? (
        <EncomendasListPage hideHeader accentColor={etapaColors[1]} />
      ) : (
        <Box
          sx={{
            flex: 1,
            minHeight: 0,
            overflow: 'auto',
            bgcolor: (theme) => theme.palette.portal.mutedFill,
            border: (theme) => `1px solid ${theme.palette.portal.border}`,
            borderRadius: 1.5,
            p: { xs: 1.5, md: 2 },
          }}
        >
          <ArtigosResumoPage hideHeader />
        </Box>
      )}
    </EtapaPageShell>
  )
}

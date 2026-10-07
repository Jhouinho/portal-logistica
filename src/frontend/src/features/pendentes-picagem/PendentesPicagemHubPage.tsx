import { Box, Tab, Tabs } from '@mui/material'
import { useSearchParams } from 'react-router-dom'
import type { SyntheticEvent } from 'react'
import { labels } from '../../shared/i18n/labels'
import { etapaColors, EtapaPageHeader, EtapaPageShell } from '../centro/portalChrome'
import { PendentesPicagemEncomendaPanel } from './PendentesPicagemEncomendaPanel'
import { PendentesPicagemReferenciaPanel } from './PendentesPicagemReferenciaPanel'

export type PendentesPicagemVista = 'encomenda' | 'referencia'

function parseVista(raw: string | null): PendentesPicagemVista {
  return raw === 'referencia' ? 'referencia' : 'encomenda'
}

/** Hub: Quantidades Pendentes de Picagens — Por Encomenda / Por Referência. */
export function PendentesPicagemHubPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const vista = parseVista(searchParams.get('vista'))
  const accent = etapaColors[2]

  function setVista(_: SyntheticEvent, next: PendentesPicagemVista) {
    if (next === vista) return
    const params = new URLSearchParams(searchParams)
    if (next === 'encomenda') params.delete('vista')
    else params.set('vista', next)
    setSearchParams(params, { replace: true })
  }

  return (
    <EtapaPageShell accent={accent}>
      <EtapaPageHeader
        etapa={2}
        title={labels.pendentesPicagem}
        hint={
          vista === 'encomenda'
            ? labels.pendentesPicagemVistaEncomendaHint
            : labels.pendentesPicagemVistaReferenciaHint
        }
        accent={accent}
      />

      <Tabs
        value={vista}
        onChange={setVista}
        aria-label={labels.pendentesPicagemVista}
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
          '& .Mui-selected': { color: `${accent} !important` },
          '& .MuiTabs-indicator': { bgcolor: accent, height: 3 },
        }}
      >
        <Tab value="encomenda" label={labels.encomendasVistaEncomenda} />
        <Tab value="referencia" label={labels.encomendasVistaReferencia} />
      </Tabs>

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
        {vista === 'encomenda' ? (
          <PendentesPicagemEncomendaPanel hideHeader />
        ) : (
          <PendentesPicagemReferenciaPanel hideHeader />
        )}
      </Box>
    </EtapaPageShell>
  )
}

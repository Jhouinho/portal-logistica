import type { ReactNode } from 'react'
import { Box, Chip, Typography } from '@mui/material'

/** Badge de estado alinhado ao mockup «Dashboard Pedidos Mobile» (azul escuro). */
export function operadorEstadoChipSx(codigo: string): {
  labelColor: string
  bg: string
} {
  switch (codigo) {
    case 'em_separacao':
    case 'em_analise':
    case 'recebido':
      return { bg: 'rgba(255, 176, 32, 0.95)', labelColor: '#0B1220' }
    case 'pronto_levantamento':
      return { bg: 'rgba(61, 178, 255, 0.95)', labelColor: '#0B1220' }
    case 'concluido':
      return { bg: 'rgba(61, 220, 151, 0.95)', labelColor: '#0B1220' }
    case 'rejeitado':
    case 'cancelado':
      return { bg: 'rgba(255, 92, 92, 0.95)', labelColor: '#FFFFFF' }
    default:
      return { bg: 'rgba(255, 176, 32, 0.95)', labelColor: '#0B1220' }
  }
}

export function OperadorEstadoBadge({
  codigo,
  etiqueta,
}: {
  codigo: string
  etiqueta: string
}) {
  const s = operadorEstadoChipSx(codigo)
  return (
    <Chip
      size="small"
      label={etiqueta}
      sx={{
        height: 26,
        fontWeight: 700,
        fontSize: 12,
        bgcolor: s.bg,
        color: s.labelColor,
        '& .MuiChip-label': { px: 1.25 },
      }}
    />
  )
}

export function fmtEuro(valor: number): string {
  return (
    valor.toLocaleString('pt-PT', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }) + ' €'
  )
}

export function fmtDataHora(iso: string): string {
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  return d.toLocaleString('pt-PT', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function OperadorPageShell({ children }: { children: ReactNode }) {
  return (
    <Box
      minHeight="100dvh"
      display="flex"
      flexDirection="column"
      bgcolor="background.default"
      sx={{ backgroundImage: (t) => t.palette.portal.pageGradient }}
    >
      {children}
    </Box>
  )
}

export function OperadorSectionTitle({
  title,
  subtitle,
}: {
  title: string
  subtitle?: string
}) {
  return (
    <Box minWidth={0}>
      <Typography variant="h6" fontWeight={800} color="text.primary" lineHeight={1.2} noWrap>
        {title}
      </Typography>
      {subtitle && (
        <Typography variant="caption" color="text.secondary" display="block" noWrap>
          {subtitle}
        </Typography>
      )}
    </Box>
  )
}

export type OperadorDossierInfo = {
  bostamp?: string | null
  obrano?: number | null
  boano?: number | null
  ndos?: number | null
  motivoRejeicao?: string | null
  decididoPor?: string | null
  dataDecisao?: string | null
}

/** Linha curta: «Pedido Mobile (PHC): 12» */
export function OperadorInfoAdicional({
  info,
}: {
  info: OperadorDossierInfo
  /** @deprecated ignorado — sempre compacto */
  compact?: boolean
}) {
  const valor =
    info.obrano != null && info.obrano > 0
      ? String(Math.trunc(info.obrano))
      : info.bostamp?.trim()
        ? info.bostamp.trim()
        : '—'

  return (
    <Typography variant="caption" color="text.secondary" display="block" mb={1} noWrap>
      Pedido Mobile (PHC): {valor}
    </Typography>
  )
}

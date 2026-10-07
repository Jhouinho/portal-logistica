import { useEffect, useState, type ElementType, type ReactNode } from 'react'
import { Box, Typography } from '@mui/material'
import WifiIcon from '@mui/icons-material/Wifi'
import WarehouseOutlinedIcon from '@mui/icons-material/WarehouseOutlined'
import type { SvgIconComponent } from '@mui/icons-material'
import {
  StatusBadge,
  centroPageBg,
  etapaColors,
  estadoSemantic,
  hexToRgba,
  portalSurface,
} from './portalChrome'
import { useTheme } from '@mui/material/styles'

export { centroPageBg }

/**
 * Paleta de superfície + aliases legados.
 * Preferir `etapaColors` / `estadoSemantic` para estágio e estado.
 * panel/border vêm do tema activo (useCentroColors).
 */
export function useCentroColors() {
  const theme = useTheme()
  const p = theme.palette.portal
  return {
    cyan: etapaColors[2],
    yellow: etapaColors[1],
    pink: etapaColors[3],
    green: etapaColors[6],
    panel: p.panel,
    border: p.border,
    radius: p.radius,
  }
}

/** @deprecated Prefer useCentroColors() — valores no momento do acesso (getters). */
export const centroColors = {
  cyan: etapaColors[2],
  yellow: etapaColors[1],
  pink: etapaColors[3],
  green: etapaColors[6],
  get panel() {
    return portalSurface.panel
  },
  get border() {
    return portalSurface.border
  },
  get radius() {
    return portalSurface.radius
  },
}
type ClockValue = {
  date: string
  time: string
}

type KpiItem = {
  label: string
  value: number
  color: string
  icon?: ElementType
  /** % de encomendas lógicas (distribuicaoLogica) — secundária ao COUNT operacional. */
  percent?: number
}

function fmtPct(p: number): string {
  const n = Number(p)
  if (!Number.isFinite(n)) return '0%'
  return Number.isInteger(n) ? `${n}%` : `${n.toFixed(1)}%`
}

export { fmtPct }

export function useClock() {
  const [now, setNow] = useState(() => new Date())
  useEffect(() => {
    const id = window.setInterval(() => setNow(new Date()), 1000)
    return () => window.clearInterval(id)
  }, [])
  const locale = 'pt-PT'
  return {
    date: now.toLocaleDateString(locale),
    time: now.toLocaleTimeString(locale, { hour: '2-digit', minute: '2-digit', second: '2-digit' }),
  } satisfies ClockValue
}

export function CentroHeader({
  armazem,
  dense,
  endActions,
}: {
  armazem: string
  dense?: boolean
  /** Ex.: toggle dia/noite na Vista TV (à esquerda de Sistema online / relógio). */
  endActions?: ReactNode
}) {
  const clock = useClock()
  return (
    <Box
      display="flex"
      justifyContent="space-between"
      alignItems="flex-start"
      mb={dense ? 2 : 3}
      flexWrap="wrap"
      gap={2}
    >
      <Box display="flex" gap={1.5} alignItems="center">
        <WarehouseOutlinedIcon sx={{ color: etapaColors[2], fontSize: dense ? 28 : 36 }} />
        <Box>
          <Typography
            variant={dense ? 'h6' : 'h5'}
            fontWeight={800}
            sx={{ letterSpacing: 0.15 }}
          >
            Centro de Operações Logísticas
          </Typography>
          <Typography variant="caption" color="text.secondary" sx={{ letterSpacing: 0.2 }}>
            {armazem}
          </Typography>
        </Box>
      </Box>
      <Box display="flex" alignItems="center" gap={2}>
        {endActions}
        {/* Indicador visual estático; não reflete health/status real do sistema. */}
        <StatusBadge
          tone="concluido"
          label="Sistema online"
          icon={<WifiIcon sx={{ fontSize: '16px !important' }} />}
        />
        <Box textAlign="right">
          <Typography variant="caption" color="text.secondary" sx={{ letterSpacing: 0.2 }}>
            {clock.date}
          </Typography>
          <Typography variant="h5" fontWeight={700} sx={{ fontVariantNumeric: 'tabular-nums', lineHeight: 1.1 }}>
            {clock.time}
          </Typography>
        </Box>
      </Box>
    </Box>
  )
}

/** Cards KPI do Centro: tamanho intermédio — legíveis, sem roubar espaço aos painéis. */
export function KpiStrip({ items }: { items: KpiItem[] }) {
  return (
    <Box
      display="grid"
      gap={1.5}
      gridTemplateColumns={{
        xs: '1fr 1fr',
        sm: items.length >= 5 ? 'repeat(3, 1fr)' : `repeat(${Math.min(items.length, 3)}, 1fr)`,
        lg: `repeat(${Math.min(items.length, 5)}, 1fr)`,
      }}
    >
      {items.map((k) => {
        const Icon = k.icon
        return (
          <Box
            key={k.label}
            sx={(theme) => {
              const p = theme.palette.portal
              return {
                bgcolor: p.panel,
                border: `1px solid ${p.border}`,
                borderRadius: p.radius,
                px: 2,
                py: 2,
                position: 'relative',
                overflow: 'hidden',
                minHeight: 132,
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'center',
                boxShadow: `inset 3px 0 0 ${k.color}`,
              }
            }}
          >
            {Icon ? (
              <Box
                sx={{
                  position: 'absolute',
                  right: 10,
                  top: 10,
                  width: 40,
                  height: 40,
                  borderRadius: '50%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  bgcolor: hexToRgba(k.color, 0.14),
                }}
              >
                <Icon sx={{ fontSize: 22, color: k.color }} />
              </Box>
            ) : null}
            <Typography
              color="text.secondary"
              fontWeight={700}
              mb={0.5}
              sx={{
                fontSize: '0.95rem',
                letterSpacing: 0.12,
                lineHeight: 1.2,
                pr: Icon ? 5.5 : 0,
              }}
            >
              {k.label}
            </Typography>
            <Typography
              fontWeight={900}
              sx={{
                color: k.color,
                fontSize: '2.35rem',
                lineHeight: 1,
                fontVariantNumeric: 'tabular-nums',
              }}
            >
              {k.value}
            </Typography>
            <Typography
              color="text.secondary"
              fontWeight={600}
              sx={{ fontSize: '0.78rem', lineHeight: 1.2, mt: 0.35, letterSpacing: 0.08 }}
            >
              dossiers
              {k.percent != null ? ` · ${fmtPct(k.percent)} encomendas` : ''}
            </Typography>
          </Box>
        )
      })}
    </Box>
  )
}

export function MiniStat({
  label,
  value,
  color,
  Icon,
}: {
  label: string
  value: number
  color: string
  Icon: SvgIconComponent
}) {
  const theme = useTheme()
  const p = theme.palette.portal
  return (
    <Box
      sx={{
        bgcolor: p.mutedFill,
        border: `1px solid ${p.border}`,
        borderRadius: 1.25,
        px: 2,
        py: 1.35,
        display: 'flex',
        alignItems: 'center',
        gap: 1.25,
        minWidth: 0,
      }}
    >
      <Box
        sx={{
          width: 36,
          height: 36,
          borderRadius: '50%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          bgcolor: hexToRgba(color, 0.14),
          flexShrink: 0,
        }}
      >
        <Icon sx={{ color, fontSize: 22 }} />
      </Box>
      <Box minWidth={0}>
        <Typography
          fontWeight={900}
          sx={{ color, fontSize: '1.5rem', lineHeight: 1, fontVariantNumeric: 'tabular-nums' }}
        >
          {value}
        </Typography>
        <Typography color="text.secondary" fontWeight={600} noWrap sx={{ fontSize: '0.85rem' }}>
          {label}
        </Typography>
      </Box>
    </Box>
  )
}

/** Indicação discreta de anomalia (só quando > 0). */
export function NaoClassificadasHint({ count }: { count: number }) {
  if (count <= 0) return null
  return (
    <Typography variant="caption" color="warning.main" fontWeight={700} display="block">
      Não classificadas (diagnóstico): {count}
    </Typography>
  )
}

export function ProgressBar({
  value,
  urgent,
  color: colorProp,
  label,
  caption,
}: {
  value: number
  urgent?: boolean
  color?: string
  /** Texto acima da barra (ex.: «12 de 16 recolhidas»). */
  label?: string
  /** Texto abaixo sem repetir a % (ex.: «do fluxo»). */
  caption?: string
}) {
  const color =
    colorProp ?? (urgent ? estadoSemantic.urgente.color : estadoSemantic.emCurso.color)
  const pct = Math.max(0, Math.min(100, Math.round(value)))
  return (
    <Box minWidth={0} width="100%" sx={{ boxSizing: 'border-box' }}>
      {label ? (
        <Typography
          variant="caption"
          color="text.secondary"
          display="block"
          sx={{ lineHeight: 1.15, mb: 0.35, fontVariantNumeric: 'tabular-nums' }}
        >
          {label}
        </Typography>
      ) : null}
      <Box display="flex" alignItems="center" gap={0.75} minWidth={0} width="100%">
        <Box
          flex={1}
          height={8}
          borderRadius={1}
          overflow="hidden"
          sx={{ minWidth: 0, bgcolor: (t) => t.palette.portal.mutedFill }}
        >
          <Box width={`${pct}%`} height="100%" bgcolor={color} />
        </Box>
        <Typography
          variant="caption"
          fontWeight={700}
          sx={{ color, minWidth: 28, flexShrink: 0, fontVariantNumeric: 'tabular-nums' }}
        >
          {pct}%
        </Typography>
      </Box>
      {caption ? (
        <Typography
          color="text.secondary"
          fontWeight={600}
          sx={{ fontSize: '0.85rem', mt: 0.35, lineHeight: 1.2 }}
        >
          {caption}
        </Typography>
      ) : null}
    </Box>
  )
}

/** Compat: delega no StatusBadge semântico. */
export function UrgenteBadge() {
  return <StatusBadge tone="urgente" label="Urgente" />
}

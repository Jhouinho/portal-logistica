import type { ReactNode } from 'react'
import { Box, Button, Chip, Typography, type ButtonProps, type ChipProps } from '@mui/material'
import { Link as RouterLink } from 'react-router-dom'
import type { PaletteMode, Theme } from '@mui/material/styles'
import { portalTokensByMode, type PortalSurfaceTokens } from '../../shared/theme'

let portalMode: PaletteMode = 'dark'

/** Actualizado pelo ColorModeProvider em cada render. */
export function setPortalColorMode(mode: PaletteMode) {
  portalMode = mode
}

function tokens(): PortalSurfaceTokens {
  return portalTokensByMode[portalMode]
}

/**
 * Superfície operacional — valores dinâmicos via getters (modo claro/escuro).
 * Preferir `etapaColors` / `estadoSemantic` para estágio e estado.
 */
export const portalSurface = {
  get panel() {
    return tokens().panel
  },
  get border() {
    return tokens().border
  },
  get radius() {
    return tokens().radius
  },
  get pageBg() {
    return tokens().pageBg
  },
  get pageGradient() {
    return tokens().pageGradient
  },
  get rowBorder() {
    return tokens().rowBorder
  },
  get mutedFill() {
    return tokens().mutedFill
  },
  get shadow() {
    return tokens().shadow
  },
}

/** Scrollbar fino alinhado ao tema (Firefox + WebKit). */
export function getPortalScrollbarStyles(mode: PaletteMode = portalMode) {
  const thumb =
    mode === 'light' ? 'rgba(43, 127, 212, 0.35)' : 'rgba(91, 147, 255, 0.35)'
  const thumbHover =
    mode === 'light' ? 'rgba(43, 127, 212, 0.55)' : 'rgba(91, 147, 255, 0.48)'
  return {
    scrollbarWidth: 'thin' as const,
    scrollbarColor: `${thumb} transparent`,
    '&::-webkit-scrollbar': {
      width: 8,
      height: 8,
    },
    '&::-webkit-scrollbar-track': {
      background: 'transparent',
    },
    '&::-webkit-scrollbar-thumb': {
      backgroundColor: mode === 'light' ? 'rgba(43, 127, 212, 0.28)' : 'rgba(91, 147, 255, 0.28)',
      borderRadius: 999,
      border: '2px solid transparent',
      backgroundClip: 'padding-box',
    },
    '&::-webkit-scrollbar-thumb:hover': {
      backgroundColor: thumbHover,
    },
    '&::-webkit-scrollbar-corner': {
      background: 'transparent',
    },
  } as const
}

export const portalScrollbarStyles = getPortalScrollbarStyles('dark')

/** Regras globais equivalentes (GlobalStyles) — passar o modo actual. */
export function getPortalScrollbarGlobalCss(mode: PaletteMode = portalMode) {
  const thumb =
    mode === 'light' ? 'rgba(43, 127, 212, 0.35)' : 'rgba(91, 147, 255, 0.35)'
  const thumbFill =
    mode === 'light' ? 'rgba(43, 127, 212, 0.28)' : 'rgba(91, 147, 255, 0.28)'
  const thumbHover =
    mode === 'light' ? 'rgba(43, 127, 212, 0.55)' : 'rgba(91, 147, 255, 0.48)'
  return {
    '*': {
      scrollbarWidth: 'thin',
      scrollbarColor: `${thumb} transparent`,
    },
    '*::-webkit-scrollbar': {
      width: 8,
      height: 8,
    },
    '*::-webkit-scrollbar-track': {
      background: 'transparent',
    },
    '*::-webkit-scrollbar-thumb': {
      backgroundColor: thumbFill,
      borderRadius: 999,
      border: '2px solid transparent',
      backgroundClip: 'padding-box',
    },
    '*::-webkit-scrollbar-thumb:hover': {
      backgroundColor: thumbHover,
    },
    '*::-webkit-scrollbar-corner': {
      background: 'transparent',
    },
  } as const
}

/** @deprecated Prefer getPortalScrollbarGlobalCss(mode) */
export const portalScrollbarGlobalCss = getPortalScrollbarGlobalCss('dark')

/**
 * Fundo de página — passar directamente a `sx={centroPageBg}` (callback de tema).
 * Assim o Emotion invalida o cache quando o modo muda.
 */
export function centroPageBg(theme: Theme) {
  const p = theme.palette.portal
  return {
    bgcolor: p.pageBg,
    background: p.pageGradient,
  }
}

/** Cores das etapas do fluxo — partilhadas menu, KPI e ecrãs. */
export const etapaColors = {
  1: '#F5A623', // Encomendas
  2: '#5B93FF', // Em picking
  3: '#EC6FBD', // Separado
  4: '#9B7BFF', // A preparar entrega
  5: '#2DD4C8', // Em Expedição
  6: '#34D399', // Concluídas
  checkIn: '#34D399',
} as const

export type EtapaId = keyof typeof etapaColors

/** Cores semânticas de estado (eixo distinto das etapas). */
export const estadoSemantic = {
  pendente: { color: '#94A3B8', bg: 'rgba(148,163,184,0.16)' },
  urgente: { color: '#F2495C', bg: 'rgba(242,73,92,0.14)' },
  atrasado: { color: '#F5A623', bg: 'rgba(245,166,35,0.14)' }, // Após limite
  emCurso: { color: '#5B93FF', bg: 'rgba(91,147,255,0.14)' },
  concluido: { color: '#34D399', bg: 'rgba(52,211,153,0.14)' },
} as const

export type EstadoTone = keyof typeof estadoSemantic

export function hexToRgba(hex: string, alpha: number): string {
  const h = hex.replace('#', '')
  const full = h.length === 3 ? h.split('').map((c) => c + c).join('') : h
  const n = Number.parseInt(full, 16)
  const r = (n >> 16) & 255
  const g = (n >> 8) & 255
  const b = n & 255
  return `rgba(${r},${g},${b},${alpha})`
}

/** Painel padrão — `sx={portalPanelSx}` (callback de tema). */
export function portalPanelSx(theme: Theme) {
  const p = theme.palette.portal
  return {
    bgcolor: p.panel,
    border: `1px solid ${p.border}`,
    borderRadius: p.radius,
    overflow: 'hidden' as const,
    boxShadow: p.shadow,
  }
}

export const portalRowPy = 0.65
export const portalSectionGap = 1.5

/** Headers de coluna — `sx={portalColHeaderSx}` ou `sx={[portalColHeaderSx, { width }]}`. */
export function portalColHeaderSx(theme: Theme) {
  const p = theme.palette.portal
  return {
    color: 'text.secondary' as const,
    fontWeight: 700,
    fontSize: '0.75rem',
    letterSpacing: 0.2,
    borderBottom: `1px solid ${p.border}`,
    bgcolor: p.mutedFill,
    py: 1,
  }
}

/** CTA primário (Check-in, acções principais). */
export const portalPrimaryCtaSx = {
  fontWeight: 800,
  letterSpacing: 0.2,
  textTransform: 'none' as const,
  bgcolor: etapaColors.checkIn,
  color: '#0B1220',
  boxShadow: '0 4px 16px rgba(52,211,153,0.25)',
  '&:hover': { bgcolor: '#2bc48a', boxShadow: '0 0 20px rgba(52,211,153,0.35)' },
  '&.Mui-disabled': {
    bgcolor: 'rgba(52,211,153,0.15)',
    color: 'text.disabled',
  },
}

/** Botões de acção em linha (listas). */
export const portalActionBtnSx = {
  textTransform: 'none' as const,
  height: 30,
  borderRadius: 1,
  px: 1.25,
  fontWeight: 700,
  fontSize: '0.8125rem',
  boxShadow: 'none',
}

/** Destaque urgente — barra lateral + fundo tintado. */
export function urgenteRowSx(urgente: boolean, accent = estadoSemantic.urgente.color) {
  if (!urgente) return {}
  return {
    bgcolor: hexToRgba(accent, 0.08),
    '& > .MuiTableCell-root:first-of-type': {
      boxShadow: `inset 3px 0 0 ${accent}`,
    },
  }
}

/** Shell de página de etapa — preenche a área útil; scroll interno só se `bodyScroll`. */
export function EtapaPageShell({
  children,
  accent,
  bodyScroll = false,
}: {
  children: ReactNode
  accent?: string
  /** Quando true, o corpo da página faz scroll (ex.: Check-in). Listas usam scroll só nas linhas. */
  bodyScroll?: boolean
}) {
  return (
    <Box
      sx={(theme) => ({
        ...centroPageBg(theme),
        flex: 1,
        minHeight: 0,
        alignSelf: 'stretch',
        width: '100%',
        maxWidth: '100%',
        boxSizing: 'border-box',
        overflow: 'hidden',
        display: 'flex',
        flexDirection: 'column',
        px: { xs: 1.5, sm: 2, md: 3 },
        pt: 2,
        pb: { xs: 1.5, sm: 2, md: 2 },
        borderTop: accent ? `3px solid ${accent}` : undefined,
      })}
    >
      <Box
        sx={{
          width: '100%',
          maxWidth: '100%',
          minWidth: 0,
          minHeight: 0,
          flex: 1,
          display: 'flex',
          flexDirection: 'column',
          overflow: bodyScroll ? 'auto' : 'hidden',
          boxSizing: 'border-box',
        }}
      >
        {children}
      </Box>
    </Box>
  )
}

/** Padding + scroll de página para ecrãs fora do EtapaPageShell (admin, detalhe, etc.). */
export const portalPageScrollSx = {
  flex: 1,
  minHeight: 0,
  alignSelf: 'stretch',
  overflow: 'auto',
  boxSizing: 'border-box' as const,
  width: '100%',
  maxWidth: '100%',
  px: { xs: 1.5, sm: 2, md: 3 },
  py: { xs: 1.5, sm: 2, md: 3 },
}

/** Contentor de scroll para tabelas (horizontal; vertical quando `fill`). */
export function PortalTableScroll({
  children,
  fill = false,
}: {
  children: ReactNode
  /** Preenche a altura restante e faz scroll vertical das linhas (thead sticky). */
  fill?: boolean
}) {
  return (
    <Box
      sx={{
        width: '100%',
        maxWidth: '100%',
        minWidth: 0,
        ...(fill
          ? { flex: 1, minHeight: 0, overflow: 'auto' }
          : { overflowX: 'auto' }),
        WebkitOverflowScrolling: 'touch',
        boxSizing: 'border-box',
      }}
    >
      {children}
    </Box>
  )
}

/** Cabeçalho uniforme das etapas — sentence case. */
export function EtapaPageHeader({
  title,
  hint,
  accent,
  etapa,
  actions,
}: {
  title: string
  hint?: string
  accent?: string
  etapa?: number
  actions?: ReactNode
}) {
  const color = accent ?? etapaColors[2]
  return (
    <Box
      display="flex"
      justifyContent="space-between"
      alignItems={{ xs: 'stretch', md: 'flex-start' }}
      gap={2}
      flexDirection={{ xs: 'column', md: 'row' }}
      mb={2}
      flexShrink={0}
    >
      <Box display="flex" alignItems="flex-start" gap={1.25} minWidth={0}>
        {etapa != null ? (
          <Box
            sx={{
              width: 28,
              height: 28,
              mt: 0.15,
              borderRadius: '50%',
              flexShrink: 0,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              bgcolor: hexToRgba(color, 0.14),
              border: `1px solid ${hexToRgba(color, 0.45)}`,
              color,
              fontWeight: 800,
              fontSize: '0.8rem',
            }}
          >
            {etapa}
          </Box>
        ) : null}
        <Box minWidth={0}>
          <Typography
            fontWeight={800}
            sx={{
              fontSize: '1.2rem',
              letterSpacing: 0.15,
              color,
              lineHeight: 1.25,
            }}
          >
            {title}
          </Typography>
          {hint ? (
            <Typography variant="body2" color="text.secondary" sx={{ mt: 0.35 }}>
              {hint}
            </Typography>
          ) : null}
        </Box>
      </Box>
      {actions ? <Box flexShrink={0}>{actions}</Box> : null}
    </Box>
  )
}

export function PortalEmptyState({ message }: { message: string }) {
  return (
    <Box
      py={4}
      px={2}
      textAlign="center"
      sx={(theme) => ({
        border: `1px dashed ${theme.palette.portal.border}`,
        borderRadius: 1.25,
        bgcolor: theme.palette.portal.mutedFill,
      })}
    >
      <Typography variant="body2" color="text.secondary" fontWeight={600}>
        {message}
      </Typography>
    </Box>
  )
}

export function PortalPrimaryButton(props: ButtonProps & { to?: string }) {
  const { to, sx, ...rest } = props
  return (
    <Button
      variant="contained"
      component={to ? RouterLink : 'button'}
      to={to}
      sx={{ ...portalPrimaryCtaSx, ...((sx as object) ?? {}) }}
      {...rest}
    />
  )
}

const statusBadgeBaseSx = {
  height: 22,
  fontWeight: 700,
  fontSize: '0.7rem',
  letterSpacing: 0.15,
  textTransform: 'none' as const,
  borderRadius: 999,
  border: 'none',
  '& .MuiChip-label': { px: 1 },
}

/** Badge/pill único para estados semânticos (e cor custom via `color`/`bg`). */
export function StatusBadge({
  tone,
  label,
  color,
  bg,
  ...chipProps
}: {
  tone?: EstadoTone
  label: string
  /** Cor sólida (quando não usa `tone`). */
  color?: string
  /** Fundo tintado (quando não usa `tone`). */
  bg?: string
} & Omit<ChipProps, 'color' | 'label'>) {
  const semantic = tone ? estadoSemantic[tone] : null
  const solid = color ?? semantic?.color ?? estadoSemantic.pendente.color
  const tint = bg ?? semantic?.bg ?? estadoSemantic.pendente.bg
  return (
    <Chip
      size="small"
      label={label}
      {...chipProps}
      sx={{
        ...statusBadgeBaseSx,
        bgcolor: tint,
        color: solid,
        ...((chipProps.sx as object) ?? {}),
      }}
    />
  )
}

/** @deprecated Preferir StatusBadge — mantido para migração gradual. */
export function estadoChipSx(color: string) {
  return {
    ...statusBadgeBaseSx,
    bgcolor: hexToRgba(color, 0.14),
    color,
  }
}

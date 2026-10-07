import { Box, Tooltip, Typography } from '@mui/material'
import { labelDossier, type EncomendaListaItem, type KappsPickingDetalhe } from '../../shared/api'
import { labels } from '../../shared/i18n/labels'
import { fmtDocNo } from '../../shared/format'
import { ClienteNomeDisplay, clienteNomeTitle } from '../../shared/ui/ClienteNomeDisplay'
import { ProgressBar, UrgenteBadge } from './centroUi'
import {
  StatusBadge,
  estadoSemantic,
  etapaColors,
  type EstadoTone,
} from './portalChrome'
import { kappsTotais } from '../encomendas/kappsProgresso'

const panelSxFn = (theme: { palette: { portal: { panel: string; border: string; radius: number; rowBorder: string } } }) => ({
  bgcolor: theme.palette.portal.panel,
  border: `1px solid ${theme.palette.portal.border}`,
  borderRadius: theme.palette.portal.radius,
  p: 0,
  overflow: 'hidden' as const,
  boxSizing: 'border-box' as const,
  minWidth: 0,
  minHeight: 0,
  height: '100%',
  display: 'flex' as const,
  flexDirection: 'column' as const,
})

const panelBodySx = {
  flex: 1,
  minHeight: 0,
  display: 'flex' as const,
  flexDirection: 'column' as const,
  px: 2,
  pt: 1.25,
  pb: 2,
  overflow: 'hidden' as const,
}

/** Encomenda ≈42% · A trabalhar ≈20% · Estado ≈24% · Hora ≈14% (fr respeita gap). */
const COLS_TRABALHO = {
  template: 'minmax(0, 42fr) minmax(0, 20fr) minmax(0, 24fr) minmax(0, 14fr)',
  cols: ['Encomenda', 'A trabalhar', 'Estado', 'Hora'],
} as const

const rowGridSx = {
  display: 'grid',
  gridTemplateColumns: { xs: '1fr', md: COLS_TRABALHO.template },
  gap: 1.25,
  alignItems: 'center',
  boxSizing: 'border-box',
  minWidth: 0,
  width: '100%',
  '& > *': {
    minWidth: 0,
    overflow: 'hidden',
    boxSizing: 'border-box',
  },
} as const

/**
 * Cabeçalho do card: título + colunas (Encomenda | A trabalhar | …).
 * Faixa vertical esquerda na cor da etapa cobre ambos.
 */
function PainelCabecalho({
  title,
  accent,
  cols,
  template,
}: {
  title: string
  accent: string
  cols: readonly string[]
  template: string
}) {
  return (
    <Box
      flexShrink={0}
      sx={{
        px: 2,
        pt: 2.1,
        pb: 0.5,
        boxShadow: `inset 3px 0 0 ${accent}`,
      }}
    >
      <Typography
        fontWeight={800}
        mb={1.25}
        sx={{ fontSize: '1.1rem', letterSpacing: 0.15, lineHeight: 1.25 }}
      >
        {title}
      </Typography>
      <HeaderRow template={template} cols={cols} />
    </Box>
  )
}

export type KappsByStamp = Record<string, KappsPickingDetalhe | null>

export type KappsVisual =
  | { kind: 'espera'; pct: number; picked: number; total: number }
  | { kind: 'curso'; pct: number; picked: number; total: number }
  | { kind: 'concluido'; pct: number; picked: number; total: number }

export function kappsVisual(kapps: KappsPickingDetalhe | null | undefined): KappsVisual {
  const { total, recolhido, concluido, emCurso } = kappsTotais(kapps)
  const pct =
    total > 0 ? Math.max(0, Math.min(100, Math.round((recolhido / total) * 100))) : 0

  if (concluido) return { kind: 'concluido', pct: 100, picked: recolhido || total, total }
  if (emCurso) return { kind: 'curso', pct, picked: recolhido, total }
  return { kind: 'espera', pct, picked: recolhido, total }
}

export function isEmEsperaKapps(kapps: KappsPickingDetalhe | null | undefined): boolean {
  return kappsVisual(kapps).kind === 'espera'
}

/** Picagem parcial — mesmo sem terminal (alinhado Vista TV). */
export function isEmProgressoKapps(kapps: KappsPickingDetalhe | null | undefined): boolean {
  return kappsVisual(kapps).kind === 'curso'
}

export function byPrioridadeCentro(a: EncomendaListaItem, b: EncomendaListaItem): number {
  if (a.urgente !== b.urgente) return a.urgente ? -1 : 1
  const acA = a.estadoPlaneamentoCodigo === 'AC'
  const acB = b.estadoPlaneamentoCodigo === 'AC'
  if (acA !== acB) return acA ? -1 : 1
  return a.numeroEncomenda - b.numeroEncomenda
}

export function filtrarEmProgresso(
  rows: EncomendaListaItem[],
  kappsByStamp: KappsByStamp,
  maxRows = 16,
): EncomendaListaItem[] {
  return rows
    .filter((r) => isEmProgressoKapps(kappsByStamp[r.boStamp]))
    .sort(byPrioridadeCentro)
    .slice(0, maxRows)
}

/** População do bloco «Separado — em progresso»: 66 abertos com/sem check-in, sem duplicar bostamp. */
export function populacaoProgressoSeparacao(
  rowsSeparacao: EncomendaListaItem[],
  rowsEmEntrega: EncomendaListaItem[],
): EncomendaListaItem[] {
  const seen = new Set<string>()
  const out: EncomendaListaItem[] = []
  for (const r of rowsSeparacao) {
    const k = r.boStamp.trim()
    if (!k || seen.has(k)) continue
    seen.add(k)
    out.push(r)
  }
  for (const r of rowsEmEntrega) {
    const k = r.boStamp.trim()
    if (!k || seen.has(k)) continue
    seen.add(k)
    out.push(r)
  }
  return out
}

function fmtHoraLimite(hora: string): string {
  const t = hora?.trim() ?? ''
  if (!t) return '—'
  const m = t.match(/^(\d{1,2}:\d{2})/)
  return m ? m[1] : t
}

function estadoTone(kind: KappsVisual['kind']): EstadoTone {
  if (kind === 'curso') return 'emCurso'
  if (kind === 'concluido') return 'concluido'
  return 'pendente'
}

function estadoLabel(kind: KappsVisual['kind'], modoSeparacao: boolean): string {
  if (kind === 'curso') return modoSeparacao ? 'Em separação' : 'Em curso'
  if (kind === 'concluido') return labels.pickStatusCompleted
  return 'Pendente'
}

/** Quem está a trabalhar: terminal Kapps (preferido), senão user Kapps. */
function labelATrabalhar(
  kapps: KappsPickingDetalhe | null | undefined,
  visual: KappsVisual,
): string | null {
  if (visual.kind === 'espera') return null
  const terminal = kapps?.activeTerminalLabel?.trim()
  if (terminal) return terminal
  if (kapps?.activeTerminalId != null && kapps.activeTerminalId > 0) {
    return `Terminal ${kapps.activeTerminalId}`
  }
  const userKap = kapps?.activeUserId?.trim()
  if (userKap) return userKap
  return null
}

function HeaderRow({ cols, template }: { cols: readonly string[]; template: string }) {
  return (
    <Box
      display={{ xs: 'none', md: 'grid' }}
      gridTemplateColumns={template}
      gap={1.25}
      pb={1}
      mb={0.5}
      flexShrink={0}
      sx={(theme) => ({
        borderBottom: `1px solid ${theme.palette.portal.border}`,
        boxSizing: 'border-box',
        minWidth: 0,
        width: '100%',
        '& > *': { minWidth: 0, overflow: 'hidden', boxSizing: 'border-box' },
      })}
    >
      {cols.map((h) => (
        <Typography
          key={h}
          variant="caption"
          color="text.secondary"
          fontWeight={700}
          textAlign={h === 'Hora' ? 'right' : 'left'}
          sx={{
            letterSpacing: 0.15,
            whiteSpace: h === 'A trabalhar' || h === 'Hora' ? 'nowrap' : undefined,
            px: h === 'Hora' ? { md: 1.25 } : undefined,
          }}
        >
          {h}
        </Typography>
      ))}
    </Box>
  )
}

/** Zona/dossier — linha secundária na célula Encomenda (omitida em Separado). */
function zonaLabel(r: EncomendaListaItem, emSeparacao?: boolean): string | null {
  if (emSeparacao) return null
  if (r.numeroDossier != null || r.nomeDossier) return labelDossier(r)
  return null
}

function EncomendaCell({
  r,
  modoSeparacao,
}: {
  r: EncomendaListaItem
  modoSeparacao?: boolean
}) {
  const clienteTitle = clienteNomeTitle(r.clienteNome, r.clienteNome2)
  const zona = zonaLabel(r, !!modoSeparacao)
  return (
    <Box sx={{ minWidth: 0 }}>
      <Box display="flex" alignItems="center" gap={0.8} flexWrap="wrap" sx={{ minWidth: 0 }}>
        <Typography fontWeight={800} sx={{ letterSpacing: 0.15 }}>
          {fmtDocNo(r.numeroEncomenda)}
        </Typography>
        {r.urgente ? <UrgenteBadge /> : null}
      </Box>
      {zona ? (
        <Typography variant="caption" color="text.secondary" title={zona}>
          {zona}
        </Typography>
      ) : null}
      <Tooltip
        title={clienteTitle}
        arrow
        disableHoverListener={!clienteTitle || clienteTitle.length < 28}
      >
        <Box sx={{ minWidth: 0 }}>
          <ClienteNomeDisplay nome={r.clienteNome} nome2={r.clienteNome2} dense />
        </Box>
      </Tooltip>
    </Box>
  )
}

function LinhaTrabalho({
  r,
  kapps,
  modoSeparacao,
}: {
  r: EncomendaListaItem
  kapps?: KappsPickingDetalhe | null
  modoSeparacao?: boolean
}) {
  const visual = kappsVisual(kapps)
  const tone = estadoTone(visual.kind)
  const cor = estadoSemantic[tone].color
  const operador = labelATrabalhar(kapps, visual)
  const linhasTxt =
    visual.total > 0
      ? `${visual.picked}/${visual.total} linhas`
      : `${r.totalLinhas} linhas`

  return (
    <Box
      sx={(theme) => ({
        ...rowGridSx,
        py: 0.65,
        borderBottom: `1px solid ${theme.palette.portal.rowBorder}`,
      })}
    >
      <EncomendaCell r={r} modoSeparacao={modoSeparacao} />

      <Typography
        variant="body2"
        fontWeight={700}
        noWrap
        title={operador ?? 'Sem atribuição'}
        sx={{ color: operador ? 'text.primary' : estadoSemantic.pendente.color }}
      >
        {operador ?? 'Sem atribuição'}
      </Typography>

      <Box sx={{ minWidth: 0, overflow: 'hidden', maxWidth: { md: 160 } }}>
        {visual.kind === 'curso' ? (
          <ProgressBar
            value={visual.pct}
            color={cor}
            urgent={r.urgente}
            caption={linhasTxt}
          />
        ) : (
          <Box>
            <StatusBadge tone={tone} label={estadoLabel(visual.kind, !!modoSeparacao)} />
            <Typography
              variant="caption"
              color="text.secondary"
              display="block"
              sx={{ mt: 0.35, fontVariantNumeric: 'tabular-nums' }}
            >
              {linhasTxt}
            </Typography>
          </Box>
        )}
      </Box>

      <Typography
        variant="body2"
        fontWeight={800}
        textAlign={{ md: 'right' }}
        sx={{
          fontVariantNumeric: 'tabular-nums',
          whiteSpace: 'nowrap',
          px: { md: 1.25 },
          overflow: 'hidden',
          minWidth: 0,
        }}
      >
        {fmtHoraLimite(r.hora)}
      </Typography>
    </Box>
  )
}

function PainelTrabalho({
  title,
  accent,
  rows,
  kappsByStamp,
  modoSeparacao,
  emptyMessage = 'Sem registos para apresentar.',
}: {
  title: string
  accent: string
  rows: EncomendaListaItem[]
  kappsByStamp: KappsByStamp
  modoSeparacao?: boolean
  emptyMessage?: string
}) {
  return (
    <Box sx={panelSxFn}>
      <PainelCabecalho
        title={title}
        accent={accent}
        template={COLS_TRABALHO.template}
        cols={COLS_TRABALHO.cols}
      />
      <Box sx={panelBodySx}>
        <Box
          sx={{
            flex: 1,
            minHeight: 0,
            overflow: 'auto',
            WebkitOverflowScrolling: 'touch',
          }}
        >
          {rows.length === 0 ? (
            <Typography variant="body2" color="text.secondary" py={1.5}>
              {emptyMessage}
            </Typography>
          ) : (
            rows.map((r) => (
              <LinhaTrabalho
                key={r.boStamp}
                r={r}
                kapps={kappsByStamp[r.boStamp]}
                modoSeparacao={modoSeparacao}
              />
            ))
          )}
        </Box>
      </Box>
    </Box>
  )
}

/** Check-in: DD/MM, HH:MM */
function fmtCheckInEm(iso: string | null | undefined): string {
  if (!iso) return '—'
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return '—'
  const dd = String(d.getDate()).padStart(2, '0')
  const mm = String(d.getMonth() + 1).padStart(2, '0')
  const hh = String(d.getHours()).padStart(2, '0')
  const mi = String(d.getMinutes()).padStart(2, '0')
  return `${dd}/${mm}, ${hh}:${mi}`
}

const COLS_CHECKIN = {
  template: 'minmax(0, 1.6fr) minmax(0, 0.9fr)',
  cols: ['Cliente', 'Check-in'],
} as const

function LinhaCheckIn({ r }: { r: EncomendaListaItem }) {
  return (
    <Box
      sx={{
        ...rowGridSx,
        gridTemplateColumns: { xs: '1fr', md: COLS_CHECKIN.template },
        py: 1.1,
        borderBottom: (theme) => `1px solid ${theme.palette.portal.rowBorder}`,
      }}
    >
      <Box sx={{ minWidth: 0 }}>
        <ClienteNomeDisplay nome={r.clienteNome} nome2={r.clienteNome2} dense />
      </Box>
      <Typography
        fontWeight={700}
        noWrap
        textAlign={{ md: 'right' }}
        sx={{ fontVariantNumeric: 'tabular-nums', px: { md: 1.25 } }}
      >
        {fmtCheckInEm(r.checkInEm)}
      </Typography>
    </Box>
  )
}

function PainelCheckIn({
  title,
  accent,
  rows,
  emptyMessage,
}: {
  title: string
  accent: string
  rows: EncomendaListaItem[]
  emptyMessage: string
}) {
  return (
    <Box sx={panelSxFn}>
      <PainelCabecalho
        title={title}
        accent={accent}
        template={COLS_CHECKIN.template}
        cols={COLS_CHECKIN.cols}
      />
      <Box sx={panelBodySx}>
        <Box
          sx={{
            flex: 1,
            minHeight: 0,
            overflow: 'auto',
            WebkitOverflowScrolling: 'touch',
          }}
        >
          {rows.length === 0 ? (
            <Typography variant="body2" color="text.secondary" py={1.5}>
              {emptyMessage}
            </Typography>
          ) : (
            rows.map((r) => <LinhaCheckIn key={r.boStamp} r={r} />)
          )}
        </Box>
      </Box>
    </Box>
  )
}

export function GeralView({
  rowsPicking,
  rowsSeparacao,
  rowsEmEntrega,
  kappsPicking,
  kappsSeparacao,
}: {
  rowsPicking: EncomendaListaItem[]
  rowsSeparacao: EncomendaListaItem[]
  rowsEmEntrega: EncomendaListaItem[]
  kappsPicking: KappsByStamp
  kappsSeparacao: KappsByStamp
}) {
  const pickingProgresso = filtrarEmProgresso(rowsPicking, kappsPicking)
  const separacaoProgresso = filtrarEmProgresso(
    populacaoProgressoSeparacao(rowsSeparacao, rowsEmEntrega),
    kappsSeparacao,
  )

  return (
    <Box
      display="grid"
      gap={2}
      flex={1}
      minHeight={0}
      height="100%"
      gridTemplateColumns={{ xs: '1fr', lg: '1fr 1fr', xl: '1fr 1fr 1fr' }}
      gridTemplateRows={{ xs: 'repeat(3, minmax(0, 1fr))', lg: 'minmax(0, 1fr)' }}
      alignItems="stretch"
    >
      <PainelTrabalho
        title={`${labels.picking} — em progresso`}
        accent={etapaColors[2]}
        rows={pickingProgresso}
        kappsByStamp={kappsPicking}
        emptyMessage="Ninguém a picagem neste momento."
      />
      <PainelTrabalho
        title={`${labels.expedicao} — em progresso`}
        accent={etapaColors[4]}
        rows={separacaoProgresso}
        kappsByStamp={kappsSeparacao}
        modoSeparacao
        emptyMessage="Nenhuma separação activa."
      />
      <PainelCheckIn
        title="Check-in — à espera do material"
        accent={etapaColors.checkIn}
        rows={rowsEmEntrega.slice(0, 16)}
        emptyMessage="Nenhum cliente em Check-in."
      />
    </Box>
  )
}

export function EmPickingView({
  rows,
  kappsByStamp,
}: {
  rows: EncomendaListaItem[]
  kappsByStamp: KappsByStamp
}) {
  return (
    <Box flex={1} minHeight={0} height="100%">
      <PainelTrabalho
        title={`${labels.picking} — em progresso`}
        accent={etapaColors[2]}
        rows={filtrarEmProgresso(rows, kappsByStamp, 50)}
        kappsByStamp={kappsByStamp}
        emptyMessage="Ninguém a picagem neste momento."
      />
    </Box>
  )
}

export function EmSeparacaoView({
  rows,
  rowsEmEntrega = [],
  kappsByStamp,
}: {
  rows: EncomendaListaItem[]
  /** A Preparar Entrega (u_chkin=1) — só para o bloco de progresso Kapps. */
  rowsEmEntrega?: EncomendaListaItem[]
  kappsByStamp: KappsByStamp
}) {
  return (
    <Box flex={1} minHeight={0} height="100%">
      <PainelTrabalho
        title={`${labels.expedicao} — em progresso`}
        accent={etapaColors[4]}
        rows={filtrarEmProgresso(
          populacaoProgressoSeparacao(rows, rowsEmEntrega),
          kappsByStamp,
          50,
        )}
        kappsByStamp={kappsByStamp}
        modoSeparacao
        emptyMessage="Nenhuma separação activa."
      />
    </Box>
  )
}

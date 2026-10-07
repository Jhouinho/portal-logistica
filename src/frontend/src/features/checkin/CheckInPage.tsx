import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  Alert,
  Box,
  Button,
  Checkbox,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  InputAdornment,
  MenuItem,
  TextField,
  Typography,
} from '@mui/material'
import HowToRegIcon from '@mui/icons-material/HowToReg'
import ArrowBackIcon from '@mui/icons-material/ArrowBack'
import SearchIcon from '@mui/icons-material/Search'
import Inventory2OutlinedIcon from '@mui/icons-material/Inventory2Outlined'
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline'
import HourglassTopIcon from '@mui/icons-material/HourglassTop'
import { Link as RouterLink } from 'react-router-dom'
import { api, labelDossier, type EncomendaListaItem } from '../../shared/api'
import { labels } from '../../shared/i18n/labels'
import {
  FILTRO_METODO_OPCOES,
  coincideMetodoExpedicao,
  type FiltroMetodoExpedicao,
} from '../../shared/metodoExpedicaoFiltro'
import { fmtDocNo, fmtMetodoExpedicao } from '../../shared/format'
import { ClienteNomeDisplay } from '../../shared/ui/ClienteNomeDisplay'
import { DossierInfoButton } from '../../shared/ui/DossierInfoButton'
import {
  MiniStat,
  UrgenteBadge,
  centroColors,
} from '../centro/centroUi'
import {
  etapaColors,
  EtapaPageHeader,
  EtapaPageShell,
  portalPanelSx,
  portalPrimaryCtaSx,
  PortalEmptyState,
} from '../centro/portalChrome'
import { useOperacoesHub } from '../../shared/signalr'

function useDebouncedValue<T>(value: T, delayMs: number): T {
  const [debounced, setDebounced] = useState(value)
  useEffect(() => {
    const id = window.setTimeout(() => setDebounced(value), delayMs)
    return () => window.clearTimeout(id)
  }, [value, delayMs])
  return debounced
}

function fmtHora(hora: string): string {
  const t = hora?.trim() ?? ''
  if (!t) return '—'
  const m = t.match(/^(\d{1,2}:\d{2})/)
  return m ? m[1] : t
}

function fmtData(data: string): string {
  const m = data?.trim().match(/^(\d{4})-(\d{2})-(\d{2})/)
  if (!m) return data?.trim() || '—'
  return `${m[3]}/${m[2]}/${m[1]}`
}

export function CheckInPage() {
  const [clienteNome, setClienteNome] = useState('')
  const clienteDebounced = useDebouncedValue(clienteNome.trim(), 300)
  const [filtroMetodo, setFiltroMetodo] = useState<FiltroMetodoExpedicao>('todos')
  const [items, setItems] = useState<EncomendaListaItem[]>([])
  const [selected, setSelected] = useState<Record<string, boolean>>({})
  const [loading, setLoading] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [erro, setErro] = useState<string | null>(null)
  const [sucesso, setSucesso] = useState<string | null>(null)
  const [confirmarAberto, setConfirmarAberto] = useState(false)
  const submitLock = useRef(false)

  const carregar = useCallback(async () => {
    setLoading(true)
    setErro(null)
    try {
      const res = await api.pickingDossiers({
        fechada: false,
        checkIn: false,
        clienteNomeContem: clienteDebounced || undefined,
        page: 1,
        pageSize: 200,
      })
      setItems(res.items)
      setSelected({})
    } catch (e) {
      setErro(e instanceof Error ? e.message : labels.erroGenerico)
      setItems([])
    } finally {
      setLoading(false)
    }
  }, [clienteDebounced])

  useEffect(() => {
    void carregar()
  }, [carregar])

  useOperacoesHub(true, { onDossier66Alterado: () => void carregar() })

  const itemsVisiveis = useMemo(
    () => items.filter((i) => coincideMetodoExpedicao(i.metodoExpedicao, filtroMetodo)),
    [items, filtroMetodo],
  )

  useEffect(() => {
    setSelected((prev) => {
      const visivel = new Set(itemsVisiveis.map((i) => i.boStamp))
      let mudou = false
      const next: Record<string, boolean> = {}
      for (const [stamp, on] of Object.entries(prev)) {
        if (on && visivel.has(stamp)) next[stamp] = true
        else if (on) mudou = true
      }
      return mudou || Object.keys(next).length !== Object.keys(prev).length ? next : prev
    })
  }, [itemsVisiveis])

  const seleccionados = useMemo(
    () => itemsVisiveis.filter((i) => selected[i.boStamp]),
    [itemsVisiveis, selected],
  )

  const todosSeleccionados =
    itemsVisiveis.length > 0 && itemsVisiveis.every((i) => selected[i.boStamp])

  function toggleTodos() {
    if (todosSeleccionados) {
      setSelected({})
      return
    }
    const next: Record<string, boolean> = {}
    for (const i of itemsVisiveis) next[i.boStamp] = true
    setSelected(next)
  }

  function toggleOne(boStamp: string) {
    setSelected((prev) => ({ ...prev, [boStamp]: !prev[boStamp] }))
  }

  function onFiltroMetodoChange(value: string) {
    const ok = FILTRO_METODO_OPCOES.some((o) => o.value === value)
    setFiltroMetodo(ok ? (value as FiltroMetodoExpedicao) : 'todos')
  }

  async function executarCheckIn() {
    if (submitLock.current || submitting) return
    if (seleccionados.length === 0) {
      setErro(labels.checkInNenhum)
      setConfirmarAberto(false)
      return
    }

    submitLock.current = true
    setSubmitting(true)
    setErro(null)
    setSucesso(null)
    setConfirmarAberto(false)

    try {
      const stamps = seleccionados.map((s) => s.boStamp)
      const result = await api.marcarCheckIn(stamps)

      if (result.falha === 0) {
        setSucesso(
          labels.checkInOk
            .replace('{ok}', String(result.sucesso))
            .replace('{total}', String(result.total)),
        )
      } else {
        const falhas = result.resultados
          .filter((r) => !r.ok)
          .map((r) => r.erro ?? r.boStamp)
          .slice(0, 3)
          .join('; ')
        setErro(
          `${labels.checkInParcial
            .replace('{ok}', String(result.sucesso))
            .replace('{fail}', String(result.falha))}${falhas ? ` — ${falhas}` : ''}`,
        )
        if (result.sucesso > 0) {
          setSucesso(
            labels.checkInOk
              .replace('{ok}', String(result.sucesso))
              .replace('{total}', String(result.total)),
          )
        }
      }

      await carregar()
      if (result.sucesso > 0) {
        window.dispatchEvent(new Event('portal:contagens-refresh'))
      }
    } catch (e) {
      setErro(e instanceof Error ? e.message : labels.erroGenerico)
    } finally {
      setSubmitting(false)
      submitLock.current = false
    }
  }

  return (
    <EtapaPageShell accent={etapaColors.checkIn} bodyScroll>
      <Box mb={1}>
        <Button
          component={RouterLink}
          to="/"
          size="small"
          startIcon={<ArrowBackIcon />}
          sx={{ color: centroColors.cyan, textTransform: 'none', fontWeight: 700 }}
        >
          {labels.painel}
        </Button>
      </Box>

      <EtapaPageHeader
        title={labels.checkIn}
        hint={labels.checkInHint}
        accent={etapaColors.checkIn}
      />

      <Box
        display="grid"
        gap={2}
        mb={2.5}
        gridTemplateColumns={{ xs: '1fr 1fr', md: 'repeat(3, 1fr)' }}
      >
        <MiniStat
          label="Elegíveis"
          value={itemsVisiveis.length}
          color={centroColors.cyan}
          Icon={Inventory2OutlinedIcon}
        />
        <MiniStat
          label="Seleccionados"
          value={seleccionados.length}
          color={centroColors.green}
          Icon={CheckCircleOutlineIcon}
        />
        <Box sx={{ display: { xs: 'none', md: 'block' } }}>
          <MiniStat
            label="À espera de Check-in"
            value={itemsVisiveis.filter((i) => !i.checkIn).length}
            color={centroColors.yellow}
            Icon={HourglassTopIcon}
          />
        </Box>
      </Box>

      {erro ? (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setErro(null)}>
          {erro}
        </Alert>
      ) : null}
      {sucesso ? (
        <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSucesso(null)}>
          {sucesso}
        </Alert>
      ) : null}

      <Box sx={[portalPanelSx, { borderTop: `2px solid ${etapaColors.checkIn}` }]}>
        {/* Toolbar compacta: procura + acção */}
        <Box
          sx={{
            px: { xs: 1.5, md: 2 },
            py: 1.25,
            borderBottom: (theme) => `1px solid ${theme.palette.portal.border}`,
            background: (theme) =>
              theme.palette.mode === 'light'
                ? 'linear-gradient(180deg, rgba(61,220,151,0.10) 0%, rgba(255,255,255,0) 100%)'
                : 'linear-gradient(180deg, rgba(61,220,151,0.08) 0%, rgba(18,26,43,0) 100%)',
          }}
        >
          <Box
            display="flex"
            gap={1.25}
            alignItems="center"
            flexWrap="wrap"
          >
            <TextField
              placeholder={`${labels.checkInProcurarCliente}…`}
              value={clienteNome}
              onChange={(e) => setClienteNome(e.target.value)}
              size="small"
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <SearchIcon sx={{ color: centroColors.cyan, fontSize: 18 }} />
                  </InputAdornment>
                ),
              }}
              sx={{
                flex: '1 1 220px',
                maxWidth: 360,
                '& .MuiOutlinedInput-root': {
                  bgcolor: (theme) =>
                    theme.palette.mode === 'light'
                      ? theme.palette.portal.mutedFill
                      : 'rgba(11,18,32,0.65)',
                  height: 36,
                  fontSize: '0.875rem',
                  fontWeight: 600,
                  '& fieldset': { borderColor: 'rgba(61,178,255,0.35)' },
                  '&:hover fieldset': { borderColor: centroColors.cyan },
                  '&.Mui-focused fieldset': { borderColor: centroColors.cyan },
                },
              }}
            />
            <TextField
              select
              size="small"
              label={labels.filtroMetodoExpedicao}
              value={filtroMetodo}
              onChange={(e) => onFiltroMetodoChange(e.target.value)}
              sx={{
                flex: '1 1 200px',
                maxWidth: 280,
                '& .MuiOutlinedInput-root': {
                  bgcolor: (theme) =>
                    theme.palette.mode === 'light'
                      ? theme.palette.portal.mutedFill
                      : 'rgba(11,18,32,0.65)',
                  height: 36,
                  fontSize: '0.875rem',
                  fontWeight: 600,
                  '& fieldset': { borderColor: 'rgba(61,178,255,0.35)' },
                  '&:hover fieldset': { borderColor: centroColors.cyan },
                  '&.Mui-focused fieldset': { borderColor: centroColors.cyan },
                },
                '& .MuiInputLabel-root': { fontWeight: 700, fontSize: '0.8rem' },
              }}
            >
              {FILTRO_METODO_OPCOES.map((o) => (
                <MenuItem key={o.value} value={o.value} sx={{ fontWeight: 600 }}>
                  {o.label()}
                </MenuItem>
              ))}
            </TextField>
            <Button
              variant="contained"
              size="small"
              disabled={seleccionados.length === 0 || submitting}
              onClick={() => setConfirmarAberto(true)}
              startIcon={
                submitting ? (
                  <CircularProgress size={14} color="inherit" />
                ) : (
                  <HowToRegIcon sx={{ fontSize: 18 }} />
                )
              }
              sx={{
                ...portalPrimaryCtaSx,
                height: 36,
                px: 1.75,
              }}
            >
              {labels.checkIn} ({seleccionados.length})
            </Button>
          </Box>
        </Box>

        {/* List header */}
        <Box
          display="flex"
          justifyContent="space-between"
          alignItems="center"
          px={{ xs: 1.5, md: 2 }}
          py={0.75}
          sx={{ bgcolor: (theme) => theme.palette.portal.mutedFill }}
        >
          <Box display="flex" alignItems="center" gap={0.75}>
            <Checkbox
              size="small"
              checked={todosSeleccionados}
              indeterminate={seleccionados.length > 0 && !todosSeleccionados}
              onChange={toggleTodos}
              disabled={itemsVisiveis.length === 0 || loading}
              sx={{
                p: 0.25,
                color: centroColors.cyan,
                '&.Mui-checked': { color: centroColors.green },
                '&.MuiCheckbox-indeterminate': { color: centroColors.cyan },
              }}
              inputProps={{ 'aria-label': labels.checkInSeleccionar }}
            />
            <Typography
              fontWeight={800}
              sx={{ fontSize: '0.75rem', letterSpacing: 0.15, fontWeight: 700 }}
            >
              Dossiers elegíveis
            </Typography>
          </Box>
          <Typography variant="caption" color="text.secondary" fontWeight={700}>
            {loading ? 'A carregar…' : `${itemsVisiveis.length} registo(s)`}
          </Typography>
        </Box>

        {/* Rows */}
        <Box px={{ xs: 1, md: 1.5 }} pb={1.5} pt={0.5}>
          {loading ? (
            <Box display="flex" justifyContent="center" py={4}>
              <CircularProgress size={28} sx={{ color: centroColors.cyan }} />
            </Box>
          ) : itemsVisiveis.length === 0 ? (
            <PortalEmptyState message={labels.checkInVazio} />
          ) : (
            <Box display="flex" flexDirection="column" gap={0.65}>
              {itemsVisiveis.map((e) => (
                <DossierCard
                  key={e.boStamp}
                  item={e}
                  selected={!!selected[e.boStamp]}
                  onToggle={() => toggleOne(e.boStamp)}
                />
              ))}
            </Box>
          )}
        </Box>
      </Box>

      <Dialog
        open={confirmarAberto}
        onClose={() => !submitting && setConfirmarAberto(false)}
        PaperProps={{
          sx: {
            bgcolor: (theme) => theme.palette.portal.panel,
            border: (theme) => `1px solid ${theme.palette.portal.border}`,
            borderRadius: 2,
            minWidth: { xs: '90%', sm: 420 },
          },
        }}
      >
        <DialogTitle sx={{ fontWeight: 900, letterSpacing: 0.4 }}>
          {labels.checkInConfirmarTitulo}
        </DialogTitle>
        <DialogContent>
          <DialogContentText color="text.secondary">
            {labels.checkInConfirmarMsg.replace('{n}', String(seleccionados.length))}
          </DialogContentText>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2.5, gap: 1 }}>
          <Button onClick={() => setConfirmarAberto(false)} disabled={submitting}>
            {labels.cancelar}
          </Button>
          <Button
            variant="contained"
            onClick={() => void executarCheckIn()}
            disabled={submitting}
            autoFocus
            sx={portalPrimaryCtaSx}
          >
            {labels.confirmar}
          </Button>
        </DialogActions>
      </Dialog>
    </EtapaPageShell>
  )
}

function DossierCard({
  item,
  selected,
  onToggle,
}: {
  item: EncomendaListaItem
  selected: boolean
  onToggle: () => void
}) {
  return (
    <Box
      role="button"
      tabIndex={0}
      onClick={onToggle}
      onKeyDown={(ev) => {
        if (ev.key === 'Enter' || ev.key === ' ') {
          ev.preventDefault()
          onToggle()
        }
      }}
      sx={{
        display: 'grid',
        gridTemplateColumns: {
          xs: 'auto 1fr auto',
          md: 'auto minmax(0, 1.6fr) 1fr 0.9fr 0.7fr 0.55fr',
        },
        gap: { xs: 1, md: 1.5 },
        alignItems: 'center',
        px: { xs: 0.75, md: 1 },
        py: 0.55,
        borderRadius: 1.25,
        cursor: 'pointer',
        bgcolor: selected ? 'rgba(61,220,151,0.10)' : (theme) => theme.palette.portal.mutedFill,
        border: selected
          ? '1px solid rgba(61,220,151,0.5)'
          : (theme) => `1px solid ${theme.palette.portal.border}`,
        boxShadow: selected ? 'inset 3px 0 0 #3DDC97' : 'inset 3px 0 0 transparent',
        transition: 'border-color 0.12s ease, background-color 0.12s ease',
        '&:hover': {
          bgcolor: selected ? 'rgba(61,220,151,0.14)' : 'rgba(61,178,255,0.07)',
          borderColor: selected ? 'rgba(61,220,151,0.65)' : 'rgba(61,178,255,0.35)',
        },
      }}
    >
      <Checkbox
        size="small"
        checked={selected}
        onClick={(ev) => ev.stopPropagation()}
        onChange={onToggle}
        sx={{
          p: 0.35,
          color: centroColors.cyan,
          '&.Mui-checked': { color: centroColors.green },
        }}
      />

      <Box minWidth={0} display="flex" flexDirection="column" gap={0.15}>
        <Box display="flex" alignItems="center" gap={0.75} minWidth={0}>
          <Box minWidth={0} flex={1} display="flex" alignItems="center" gap={0.75}>
            <ClienteNomeDisplay nome={item.clienteNome} nome2={item.clienteNome2} />
            {item.urgente ? <UrgenteBadge /> : null}
            <Typography
              variant="caption"
              color="text.secondary"
              noWrap
              sx={{ display: { xs: 'none', sm: 'inline' }, fontVariantNumeric: 'tabular-nums' }}
            >
              · {item.clienteNo} · {item.totalLinhas} lin.
            </Typography>
          </Box>
          <DossierInfoButton
            clienteNome={item.clienteNome}
            clienteNome2={item.clienteNome2}
            moradaEntrega={item.moradaEntrega}
            metodoExpedicao={item.metodoExpedicao}
            showMetodoExpedicao
          />
        </Box>
        <Typography variant="caption" color="text.secondary" noWrap>
          {labels.colMetodoExpedicao}: {fmtMetodoExpedicao(item.metodoExpedicao)}
        </Typography>
      </Box>

      <Typography
        variant="body2"
        fontWeight={600}
        noWrap
        title={labelDossier(item)}
        sx={{ display: { xs: 'none', md: 'block' } }}
      >
        {labelDossier(item)}
      </Typography>

      <Typography
        variant="body2"
        fontWeight={700}
        sx={{ display: { xs: 'none', md: 'block' }, fontVariantNumeric: 'tabular-nums' }}
      >
        {fmtDocNo(item.numeroEncomenda)}
      </Typography>

      <Typography
        variant="body2"
        fontWeight={600}
        noWrap
        sx={{ display: { xs: 'none', md: 'block' }, fontVariantNumeric: 'tabular-nums' }}
      >
        {fmtData(item.data)} {fmtHora(item.hora)}
      </Typography>

      <Typography
        variant="body2"
        fontWeight={800}
        textAlign="right"
        sx={{
          color: centroColors.cyan,
          fontVariantNumeric: 'tabular-nums',
          fontSize: { xs: '0.95rem', md: '1rem' },
        }}
      >
        {item.quantidadeTotal}
      </Typography>
    </Box>
  )
}

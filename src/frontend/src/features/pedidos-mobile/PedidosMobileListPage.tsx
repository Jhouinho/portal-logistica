import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  IconButton,
  InputAdornment,
  Menu,
  MenuItem,
  Stack,
  Tab,
  Tabs,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material'
import SmartphoneIcon from '@mui/icons-material/Smartphone'
import SearchIcon from '@mui/icons-material/Search'
import TuneIcon from '@mui/icons-material/Tune'
import VisibilityOutlinedIcon from '@mui/icons-material/VisibilityOutlined'
import PersonOutlineIcon from '@mui/icons-material/PersonOutline'
import CalendarTodayOutlinedIcon from '@mui/icons-material/CalendarTodayOutlined'
import { Link as RouterLink } from 'react-router-dom'
import { api, type StaffPmPedidoListaItem } from '../../shared/api'
import { labels } from '../../shared/i18n/labels'
import { portalPageScrollSx, portalPanelSx } from '../centro/portalChrome'
import {
  OperadorEstadoBadge,
  OperadorInfoAdicional,
  fmtDataHora,
  fmtEuro,
} from '../operador/operadorUi'

type Filtro = 'pendentes' | 'integrados' | 'rejeitados' | 'todos'

const FILTROS_PRINCIPAIS: { value: Filtro; label: string }[] = [
  { value: 'pendentes', label: 'Pendentes' },
  { value: 'integrados', label: 'Validados' },
]

function fmtData(iso: string): string {
  return fmtDataHora(iso)
}

function estadoColor(codigo: string): 'default' | 'warning' | 'success' | 'error' | 'info' {
  switch (codigo) {
    case 'validado':
      return 'success'
    case 'rejeitado':
    case 'cancelado':
      return 'error'
    case 'em_analise':
      return 'info'
    default:
      return 'warning'
  }
}

type Props = {
  /** Prefixo da lista (Logística: /pedidos-mobile; Operador: /operador/pedidos-mobile). */
  listBasePath?: string
}

export function PedidosMobileListPage({ listBasePath = '/pedidos-mobile' }: Props) {
  const base = listBasePath.replace(/\/$/, '') || '/pedidos-mobile'
  const isOperador = base.startsWith('/operador')
  const [filtro, setFiltro] = useState<Filtro>('pendentes')
  const [items, setItems] = useState<StaffPmPedidoListaItem[]>([])
  const [counts, setCounts] = useState<Partial<Record<Filtro, number>>>({})
  const [pesquisa, setPesquisa] = useState('')
  const [loading, setLoading] = useState(true)
  const [erro, setErro] = useState<string | null>(null)
  const [menuEl, setMenuEl] = useState<null | HTMLElement>(null)

  const carregar = useCallback(async () => {
    setLoading(true)
    setErro(null)
    try {
      setItems(await api.staffPmPedidos({ filtro, top: 100 }))
    } catch (e) {
      setErro(e instanceof Error ? e.message : labels.erroGenerico)
      setItems([])
    } finally {
      setLoading(false)
    }
  }, [filtro])

  const carregarContagens = useCallback(async () => {
    if (!isOperador) return
    try {
      const pares = await Promise.all(
        FILTROS_PRINCIPAIS.map(async (f) => {
          const list = await api.staffPmPedidos({ filtro: f.value, top: 100 })
          return [f.value, list.length] as const
        }),
      )
      setCounts(Object.fromEntries(pares))
    } catch {
      /* contagens são decorativas — a lista principal trata o erro */
    }
  }, [isOperador])

  useEffect(() => {
    void carregar()
  }, [carregar])

  useEffect(() => {
    void carregarContagens()
  }, [carregarContagens])

  const filtrados = useMemo(() => {
    const q = pesquisa.trim().toLowerCase()
    if (!q) return items
    return items.filter((p) => {
      const blob = `${p.numeroInterno} ${p.clienteNome} ${p.clNo} ${p.obrano ?? ''}`.toLowerCase()
      return blob.includes(q)
    })
  }, [items, pesquisa])

  if (isOperador) {
    return (
      <Box>
        <Stack direction="row" spacing={1} alignItems="center" mb={1.75}>
          <TextField
            fullWidth
            size="small"
            placeholder="Pesquisar pedido ou cliente"
            value={pesquisa}
            onChange={(e) => setPesquisa(e.target.value)}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <SearchIcon fontSize="small" color="primary" />
                </InputAdornment>
              ),
            }}
            sx={{
              '& .MuiOutlinedInput-root': {
                borderRadius: 2,
                bgcolor: 'background.paper',
                minHeight: 48,
              },
            }}
          />
          <IconButton
            aria-label="Mais filtros"
            onClick={(e) => setMenuEl(e.currentTarget)}
            sx={{
              width: 48,
              height: 48,
              borderRadius: 2,
              border: 1,
              borderColor: 'portal.border',
              bgcolor: 'background.paper',
              color: 'primary.main',
            }}
          >
            <TuneIcon />
          </IconButton>
          <Menu anchorEl={menuEl} open={!!menuEl} onClose={() => setMenuEl(null)}>
            <MenuItem
              selected={filtro === 'rejeitados'}
              onClick={() => {
                setFiltro('rejeitados')
                setMenuEl(null)
              }}
            >
              Rejeitados
            </MenuItem>
            <MenuItem
              selected={filtro === 'todos'}
              onClick={() => {
                setFiltro('todos')
                setMenuEl(null)
              }}
            >
              Todos
            </MenuItem>
          </Menu>
        </Stack>

        <Stack
          direction="row"
          spacing={1}
          mb={2}
          sx={{ overflowX: 'auto', pb: 0.5, mx: -0.5, px: 0.5 }}
        >
          {FILTROS_PRINCIPAIS.map((f) => {
            const active = filtro === f.value
            const n = counts[f.value]
            const label = n != null ? `${f.label} ${n}` : f.label
            return (
              <Chip
                key={f.value}
                label={label}
                onClick={() => setFiltro(f.value)}
                sx={{
                  flexShrink: 0,
                  height: 36,
                  fontWeight: 700,
                  borderRadius: 999,
                  bgcolor: active ? 'primary.main' : 'transparent',
                  color: active ? '#0B1220' : 'text.secondary',
                  border: 1.5,
                  borderColor: active ? 'primary.main' : 'portal.border',
                  '&:hover': {
                    bgcolor: active ? 'primary.main' : 'rgba(61, 178, 255, 0.08)',
                  },
                }}
              />
            )
          })}
        </Stack>

        {erro && (
          <Alert severity="error" sx={{ mb: 2 }} onClose={() => setErro(null)}>
            {erro}
          </Alert>
        )}

        {loading ? (
          <Box display="flex" justifyContent="center" py={6}>
            <CircularProgress size={32} />
          </Box>
        ) : filtrados.length === 0 ? (
          <Typography color="text.secondary" py={4} textAlign="center">
            Nenhum pedido neste filtro.
          </Typography>
        ) : (
          <Stack spacing={1.75}>
            {filtrados.map((p) => (
              <Box
                key={p.pedidoId}
                sx={{
                  bgcolor: 'background.paper',
                  borderRadius: 2.5,
                  border: 1,
                  borderColor: 'portal.border',
                  boxShadow: (t) => t.palette.portal.shadow,
                  p: 2,
                }}
              >
                <Stack direction="row" alignItems="flex-start" justifyContent="space-between" mb={1.25}>
                  <Stack direction="row" spacing={0.75} alignItems="center" minWidth={0}>
                    <SmartphoneIcon sx={{ fontSize: 18, color: 'primary.main' }} />
                    <Typography fontWeight={800} noWrap>
                      {p.numeroInterno}
                    </Typography>
                  </Stack>
                  <OperadorEstadoBadge codigo={p.estadoCodigo} etiqueta={p.estadoEtiqueta} />
                </Stack>

                <Stack direction="row" spacing={0.75} alignItems="flex-start" mb={0.75}>
                  <PersonOutlineIcon sx={{ fontSize: 16, color: 'text.secondary', mt: '2px' }} />
                  <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.35 }}>
                    {p.clienteNome || '—'} ({p.clNo}
                    {p.clEstab ? `/${p.clEstab}` : ''})
                  </Typography>
                </Stack>

                <OperadorInfoAdicional
                  compact
                  info={{
                    bostamp: p.bostamp,
                    obrano: p.obrano,
                    ndos: p.ndos,
                  }}
                />

                <Stack
                  direction="row"
                  alignItems="center"
                  justifyContent="space-between"
                  spacing={1}
                  mb={1.75}
                >
                  <Stack direction="row" spacing={0.75} alignItems="center">
                    <CalendarTodayOutlinedIcon sx={{ fontSize: 15, color: 'text.secondary' }} />
                    <Typography variant="caption" color="text.secondary">
                      {fmtDataHora(p.dataSubmissao)}
                    </Typography>
                  </Stack>
                  <Typography fontWeight={800} color="primary.main" fontSize="1.15rem">
                    {fmtEuro(p.etotaldeb)}
                  </Typography>
                </Stack>

                <Button
                  component={RouterLink}
                  to={`${base}/${p.pedidoId}`}
                  fullWidth
                  variant="outlined"
                  color="primary"
                  startIcon={<VisibilityOutlinedIcon />}
                  sx={{
                    minHeight: 44,
                    fontWeight: 700,
                    textTransform: 'none',
                    borderRadius: 2,
                    borderWidth: 1.5,
                  }}
                >
                  Ver pedido
                </Button>
              </Box>
            ))}
          </Stack>
        )}
      </Box>
    )
  }

  return (
    <Box sx={portalPageScrollSx}>
      <Stack direction="row" alignItems="center" spacing={1.5} mb={1}>
        <SmartphoneIcon color="primary" />
        <Typography variant="h5" fontWeight={700}>
          {labels.pedidosMobile}
        </Typography>
      </Stack>
      <Typography variant="body2" color="text.secondary" mb={2}>
        Validação no balcão: conferir artigos, preços e criar o dossier PHC. A faturação faz-se no PHC.
      </Typography>

      <Tabs
        value={filtro}
        onChange={(_, v: Filtro) => setFiltro(v)}
        sx={{ mb: 2 }}
        variant="scrollable"
        allowScrollButtonsMobile
      >
        <Tab value="pendentes" label="Pendentes" />
        <Tab value="integrados" label="Validados" />
        <Tab value="rejeitados" label="Rejeitados" />
        <Tab value="todos" label="Todos" />
      </Tabs>

      {erro && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setErro(null)}>
          {erro}
        </Alert>
      )}

      <Box sx={{ ...portalPanelSx, overflow: 'auto' }}>
        {loading ? (
          <Box display="flex" justifyContent="center" py={4}>
            <CircularProgress size={32} />
          </Box>
        ) : items.length === 0 ? (
          <Typography color="text.secondary" py={3} textAlign="center">
            Nenhum pedido neste filtro.
          </Typography>
        ) : (
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Nº interno</TableCell>
                <TableCell>Nº dossier</TableCell>
                <TableCell>Cliente</TableCell>
                <TableCell>Data</TableCell>
                <TableCell>Estado</TableCell>
                <TableCell align="right">Total</TableCell>
                <TableCell align="right" />
              </TableRow>
            </TableHead>
            <TableBody>
              {items.map((p) => (
                <TableRow key={p.pedidoId} hover>
                  <TableCell>
                    <Typography fontWeight={700}>{p.numeroInterno}</Typography>
                  </TableCell>
                  <TableCell>
                    {p.obrano != null && p.obrano > 0 ? (
                      <Typography fontWeight={700}>{Math.trunc(p.obrano)}</Typography>
                    ) : (
                      <Typography color="text.secondary">—</Typography>
                    )}
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2">
                      {p.clienteNome || '—'}{' '}
                      <Typography component="span" color="text.secondary" variant="caption">
                        ({p.clNo}
                        {p.clEstab ? `/${p.clEstab}` : ''})
                      </Typography>
                    </Typography>
                  </TableCell>
                  <TableCell>{fmtData(p.dataSubmissao)}</TableCell>
                  <TableCell>
                    <Chip size="small" label={p.estadoEtiqueta} color={estadoColor(p.estadoCodigo)} />
                  </TableCell>
                  <TableCell align="right">{p.etotaldeb.toFixed(2)} €</TableCell>
                  <TableCell align="right">
                    <Button
                      component={RouterLink}
                      to={`${base}/${p.pedidoId}`}
                      size="small"
                      variant="outlined"
                    >
                      Abrir
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </Box>
    </Box>
  )
}

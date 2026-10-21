import { useCallback, useEffect, useState } from 'react'
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Stack,
  Tab,
  Tabs,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material'
import SmartphoneIcon from '@mui/icons-material/Smartphone'
import { Link as RouterLink } from 'react-router-dom'
import { api, type StaffPmPedidoListaItem } from '../../shared/api'
import { labels } from '../../shared/i18n/labels'
import { portalPageScrollSx, portalPanelSx } from '../centro/portalChrome'

type Filtro = 'pendentes' | 'integrados' | 'rejeitados' | 'todos'

function fmtData(iso: string): string {
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

function estadoColor(codigo: string): 'default' | 'warning' | 'success' | 'error' | 'info' {
  switch (codigo) {
    case 'aprovado':
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

export function PedidosMobileListPage() {
  const [filtro, setFiltro] = useState<Filtro>('pendentes')
  const [items, setItems] = useState<StaffPmPedidoListaItem[]>([])
  const [loading, setLoading] = useState(true)
  const [erro, setErro] = useState<string | null>(null)

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

  useEffect(() => {
    void carregar()
  }, [carregar])

  return (
    <Box sx={portalPageScrollSx}>
      <Stack direction="row" alignItems="center" spacing={1.5} mb={1}>
        <SmartphoneIcon color="primary" />
        <Typography variant="h5" fontWeight={700}>
          {labels.pedidosMobile}
        </Typography>
      </Stack>
      <Typography variant="body2" color="text.secondary" mb={2}>
        Análise, aprovação e rejeição de pedidos internos do Portal Mobile (antes da picagem /
        expedição). Não faz parte do circuito semanal de encomendas.
      </Typography>

      <Tabs
        value={filtro}
        onChange={(_, v: Filtro) => setFiltro(v)}
        sx={{ mb: 2 }}
        variant="scrollable"
      >
        <Tab value="pendentes" label="Pendentes" />
        <Tab value="integrados" label="Aprovados" />
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
                    <Chip
                      size="small"
                      label={p.estadoEtiqueta}
                      color={estadoColor(p.estadoCodigo)}
                    />
                  </TableCell>
                  <TableCell align="right">{p.etotaldeb.toFixed(2)} €</TableCell>
                  <TableCell align="right">
                    <Button
                      component={RouterLink}
                      to={`/pedidos-mobile/${p.pedidoId}`}
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

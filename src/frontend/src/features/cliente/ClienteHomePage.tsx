import { useEffect, useState } from 'react'
import { Box, CardActionArea, CircularProgress, Stack, Typography } from '@mui/material'
import { Link as RouterLink, useLocation } from 'react-router-dom'
import {
  clienteApi,
  clientePedidoNumeroLabel,
  clientePedidoRouteId,
  type ClientePedidoLista,
} from './clienteApi'
import { useClienteAuth } from './ClienteAuthContext'
import {
  ClienteAlert,
  ClienteEstadoBadge,
  ClientePanel,
  ClientePrimaryButton,
  ClienteSecondaryButton,
} from './clienteUi'

export function ClienteHomePage() {
  const { cliente } = useClienteAuth()
  const location = useLocation()
  const [pedidos, setPedidos] = useState<ClientePedidoLista[]>([])
  const [loading, setLoading] = useState(true)
  const [erro, setErro] = useState<string | null>(null)

  useEffect(() => {
    clienteApi
      .pedidos(10)
      .then(setPedidos)
      .catch((e) => setErro(e instanceof Error ? e.message : 'Erro'))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => {
    if (location.hash !== '#pedidos') return
    const id = window.setTimeout(() => {
      document.getElementById('pedidos')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
    }, 80)
    return () => window.clearTimeout(id)
  }, [location.hash, loading, pedidos.length])

  const primeiroNome = (cliente?.nome ?? '').split(/\s+/)[0] || 'Cliente'

  return (
    <Stack spacing={2.5}>
      <Box>
        <Typography
          variant="subtitle1"
          fontWeight={700}
          color="text.primary"
          sx={{ fontSize: 16, lineHeight: 1.35 }}
        >
          Olá, {primeiroNome}
        </Typography>
        <Typography variant="body2" color="text.secondary" mt={0.5} sx={{ fontSize: 13 }}>
          Crie um pedido ou consulte o histórico recente.
        </Typography>
      </Box>

      <ClientePrimaryButton component={RouterLink} to="/cliente/novo">
        Novo pedido
      </ClientePrimaryButton>
      <ClienteSecondaryButton component={RouterLink} to="/cliente/carrinho">
        Ver carrinho
      </ClienteSecondaryButton>

      <Typography
        id="pedidos"
        variant="subtitle1"
        fontWeight={700}
        color="text.primary"
        pt={0.5}
        sx={{ scrollMarginTop: 72 }}
      >
        Últimos pedidos
      </Typography>

      {loading && (
        <Box display="flex" justifyContent="center" py={3}>
          <CircularProgress size={32} />
        </Box>
      )}
      {erro && <ClienteAlert severity="error">{erro}</ClienteAlert>}
      {!loading && !erro && pedidos.length === 0 && (
        <ClientePanel>
          <Typography color="text.secondary" textAlign="center" py={1}>
            Ainda não tem pedidos.
          </Typography>
        </ClientePanel>
      )}
      {pedidos.map((p) => (
        <ClientePanel
          key={`${p.origem}-${clientePedidoRouteId(p)}`}
          sx={{ p: 0, overflow: 'hidden' }}
        >
          <CardActionArea
            component={RouterLink}
            to={`/cliente/pedidos/${encodeURIComponent(clientePedidoRouteId(p))}`}
            sx={{ p: 2 }}
          >
            <Stack direction="row" justifyContent="space-between" alignItems="flex-start" gap={1}>
              <Box minWidth={0}>
                <Typography fontWeight={700} color="text.primary">
                  Pedido nº {clientePedidoNumeroLabel(p)}
                </Typography>
                <Typography variant="body2" color="text.secondary" mt={0.5}>
                  {new Date(p.dataObra).toLocaleDateString('pt-PT')}
                  {p.hora ? ` · ${p.hora}` : ''}
                </Typography>
              </Box>
              <ClienteEstadoBadge codigo={p.estadoCodigo} etiqueta={p.estadoEtiqueta} />
            </Stack>
            <Typography fontWeight={700} color="primary.main" mt={1.5}>
              {p.etotaldeb.toFixed(2)} €
            </Typography>
          </CardActionArea>
        </ClientePanel>
      ))}
    </Stack>
  )
}

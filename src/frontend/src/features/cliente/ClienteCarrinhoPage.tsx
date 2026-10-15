import { useMemo, useState } from 'react'
import {
  Alert,
  Box,
  Button,
  IconButton,
  TextField,
  Typography,
} from '@mui/material'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import { Link as RouterLink, useNavigate } from 'react-router-dom'
import { clienteApi } from './clienteApi'
import { useClienteAuth } from './ClienteAuthContext'
import {
  clearCarrinho,
  loadCarrinho,
  saveCarrinho,
  type CarrinhoLinha,
} from './carrinhoStorage'

function newIdempotencyKey(): string {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID()
  return `mob-${Date.now()}-${Math.random().toString(16).slice(2)}`
}

export function ClienteCarrinhoPage() {
  const { cliente } = useClienteAuth()
  const navigate = useNavigate()
  const [linhas, setLinhas] = useState<CarrinhoLinha[]>(() =>
    cliente ? loadCarrinho(cliente.no, cliente.estab) : [],
  )
  const [busy, setBusy] = useState(false)
  const [erro, setErro] = useState<string | null>(null)
  const [okMsg, setOkMsg] = useState<string | null>(null)

  const total = useMemo(
    () => linhas.reduce((s, l) => s + l.qtt * l.precoUnitario, 0),
    [linhas],
  )

  function persist(next: CarrinhoLinha[]) {
    if (!cliente) return
    setLinhas(next)
    saveCarrinho(cliente.no, cliente.estab, next)
  }

  async function submeter() {
    if (!cliente || linhas.length === 0) return
    setErro(null)
    setOkMsg(null)
    setBusy(true)
    const key = newIdempotencyKey()
    try {
      const payload = linhas.map((l, i) => ({
        linhaOrd: i + 1,
        ref: l.ref,
        qtt: l.qtt,
        cor: l.cor || '',
      }))
      const res = await clienteApi.criarPedido(key, payload)
      clearCarrinho(cliente.no, cliente.estab)
      setLinhas([])
      setOkMsg(
        res.alreadyExists
          ? `Pedido já registado (nº ${res.obrano}).`
          : `Pedido nº ${res.obrano} submetido com sucesso.`,
      )
      setTimeout(() => navigate('/cliente', { replace: true }), 1200)
    } catch (err) {
      setErro(err instanceof Error ? err.message : 'Falha na submissão. O carrinho foi mantido.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Box display="flex" flexDirection="column" gap={2}>
      <Typography variant="h5">Carrinho</Typography>
      {erro && <Alert severity="error">{erro}</Alert>}
      {okMsg && <Alert severity="success">{okMsg}</Alert>}
      {linhas.length === 0 && !okMsg && (
        <Typography color="text.secondary">Carrinho vazio.</Typography>
      )}
      {linhas.map((l, idx) => (
        <Box key={`${l.ref}|${l.cor}|${idx}`} bgcolor="white" p={2} borderRadius={1}>
          <Typography fontWeight={600}>{l.design}</Typography>
          <Typography variant="body2">
            {l.ref}
            {l.cor ? ` · ${l.cor}` : ''}
          </Typography>
          <Box display="flex" alignItems="center" gap={1} mt={1}>
            <TextField
              type="number"
              size="small"
              label="Qtd"
              value={l.qtt}
              onChange={(e) => {
                const q = Number(e.target.value)
                if (!Number.isInteger(q) || q < 1) return
                const next = [...linhas]
                next[idx] = { ...l, qtt: q }
                persist(next)
              }}
              inputProps={{ min: 1, step: 1 }}
              sx={{ width: 100 }}
            />
            <Typography sx={{ flex: 1 }}>{(l.qtt * l.precoUnitario).toFixed(2)} €</Typography>
            <IconButton
              aria-label="Remover"
              onClick={() => persist(linhas.filter((_, i) => i !== idx))}
            >
              <DeleteOutlineIcon />
            </IconButton>
          </Box>
        </Box>
      ))}
      {linhas.length > 0 && (
        <>
          <Typography variant="h6">Total estimado: {total.toFixed(2)} €</Typography>
          <Button variant="contained" size="large" disabled={busy} onClick={submeter}>
            Submeter pedido
          </Button>
        </>
      )}
      <Button component={RouterLink} to="/cliente/novo">
        Adicionar artigos
      </Button>
      <Button component={RouterLink} to="/cliente">
        Página inicial
      </Button>
    </Box>
  )
}

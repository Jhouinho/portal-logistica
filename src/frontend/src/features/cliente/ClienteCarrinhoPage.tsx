import { useMemo, useRef, useState } from 'react'
import {
  Box,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  IconButton,
  Stack,
  Typography,
} from '@mui/material'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import ShoppingCartOutlinedIcon from '@mui/icons-material/ShoppingCartOutlined'
import { useNavigate } from 'react-router-dom'
import { clienteApi, clientePedidoNumeroLabel } from './clienteApi'
import { useClienteAuth } from './ClienteAuthContext'
import {
  clearCarrinho,
  loadCarrinho,
  saveCarrinho,
  type CarrinhoLinha,
} from './carrinhoStorage'
import {
  ClienteArtigoThumb,
  ClienteErrorPanel,
  ClientePageTitle,
  ClientePanel,
  ClientePrimaryButton,
  ClienteQtyStepper,
  ClienteSecondaryButton,
  ClienteSuccessPanel,
} from './clienteUi'

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
  const [sucessoLabel, setSucessoLabel] = useState<string | null>(null)
  const [jaExistia, setJaExistia] = useState(false)
  const [confirmOpen, setConfirmOpen] = useState(false)
  /** Reutilizada em retries / duplo clique da mesma submissão. */
  const submitKeyRef = useRef<string | null>(null)

  const total = useMemo(
    () => linhas.reduce((s, l) => s + l.qtt * l.precoUnitario, 0),
    [linhas],
  )

  function persist(next: CarrinhoLinha[]) {
    if (!cliente) return
    setLinhas(next)
    saveCarrinho(cliente.no, cliente.estab, next)
    submitKeyRef.current = null
  }

  async function submeterConfirmado() {
    if (!cliente || linhas.length === 0) return
    setConfirmOpen(false)
    setErro(null)
    setBusy(true)
    if (!submitKeyRef.current) submitKeyRef.current = newIdempotencyKey()
    const key = submitKeyRef.current
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
      submitKeyRef.current = null
      setJaExistia(!!res.alreadyExists)
      setSucessoLabel(clientePedidoNumeroLabel(res))
    } catch (err) {
      setErro(err instanceof Error ? err.message : 'Falha na submissão. O carrinho foi mantido.')
    } finally {
      setBusy(false)
    }
  }

  if (sucessoLabel != null) {
    return (
      <Stack spacing={2.5}>
        <ClienteSuccessPanel
          title="Pedido submetido com sucesso!"
          detail={
            jaExistia
              ? `Pedido já registado (nº ${sucessoLabel}).`
              : `Pedido nº ${sucessoLabel} registado.`
          }
          highlight="A nossa equipa irá analisar o pedido. Os preços e quantidades poderão sofrer ajustes."
        >
          <ClientePrimaryButton onClick={() => navigate('/cliente', { replace: true })}>
            Voltar à homepage
          </ClientePrimaryButton>
        </ClienteSuccessPanel>
      </Stack>
    )
  }

  return (
    <Stack spacing={2.5}>
      <ClientePageTitle title="Carrinho" />

      {erro && (
        <ClienteErrorPanel title="Erro ao submeter o pedido" detail={erro}>
          <ClientePrimaryButton disabled={busy || linhas.length === 0} onClick={submeterConfirmado}>
            Tentar novamente
          </ClientePrimaryButton>
        </ClienteErrorPanel>
      )}

      {linhas.length === 0 && !erro && (
        <ClientePanel>
          <Stack alignItems="center" spacing={1.5} py={3} textAlign="center">
            <ShoppingCartOutlinedIcon sx={{ fontSize: 56, color: 'text.secondary' }} />
            <Typography fontWeight={700} color="text.primary">
              Carrinho vazio
            </Typography>
            <Typography color="text.secondary" variant="body2">
              Adicione artigos para preparar o seu pedido.
            </Typography>
            <ClientePrimaryButton onClick={() => navigate('/cliente/novo')}>
              Novo pedido
            </ClientePrimaryButton>
          </Stack>
        </ClientePanel>
      )}

      {linhas.map((l, idx) => (
        <ClientePanel key={`${l.ref}|${l.cor}|${idx}`}>
          <Stack direction="row" spacing={1.5} alignItems="flex-start">
            <ClienteArtigoThumb refCode={l.ref} alt={l.design} />
            <Box flex={1} minWidth={0}>
              <Typography fontWeight={700} color="text.primary">
                {l.design}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                {l.ref}
                {l.cor ? ` · ${l.cor}` : ''}
              </Typography>
              <Stack
                direction="row"
                alignItems="center"
                justifyContent="space-between"
                mt={1.5}
                gap={1}
              >
                <ClienteQtyStepper
                  value={l.qtt}
                  onChange={(q) => {
                    const next = [...linhas]
                    next[idx] = { ...l, qtt: q }
                    persist(next)
                  }}
                />
                <Typography fontWeight={700} color="primary.main" whiteSpace="nowrap">
                  {(l.qtt * l.precoUnitario).toFixed(2)} €
                </Typography>
              </Stack>
            </Box>
            <IconButton
              aria-label="Remover"
              onClick={() => persist(linhas.filter((_, i) => i !== idx))}
              sx={{ color: 'text.secondary' }}
            >
              <DeleteOutlineIcon />
            </IconButton>
          </Stack>
        </ClientePanel>
      ))}

      {linhas.length > 0 && (
        <>
          {!erro && (
            <ClientePanel>
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography color="text.secondary">Total estimado</Typography>
                <Typography variant="h6" fontWeight={800} color="text.primary">
                  {total.toFixed(2)} €
                </Typography>
              </Stack>
            </ClientePanel>
          )}
          {!erro && (
            <ClientePrimaryButton disabled={busy} onClick={() => setConfirmOpen(true)}>
              Submeter pedido
            </ClientePrimaryButton>
          )}
          <ClienteSecondaryButton onClick={() => navigate('/cliente/novo')}>
            Adicionar artigos
          </ClienteSecondaryButton>
        </>
      )}

      <Dialog open={confirmOpen} onClose={() => setConfirmOpen(false)}>
        <DialogTitle>Confirmar submissão</DialogTitle>
        <DialogContent>
          <DialogContentText>
            Confirma a submissão do pedido? Após a submissão, não poderás cancelar o pedido. Os
            preços e as quantidades poderão sofrer alterações durante a análise e o processamento
            pela nossa equipa. Pretendes continuar?
          </DialogContentText>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2, gap: 1, flexDirection: 'column' }}>
          <ClientePrimaryButton disabled={busy} onClick={submeterConfirmado}>
            Sim, submeter
          </ClientePrimaryButton>
          <ClienteSecondaryButton onClick={() => setConfirmOpen(false)}>Não</ClienteSecondaryButton>
        </DialogActions>
      </Dialog>
    </Stack>
  )
}

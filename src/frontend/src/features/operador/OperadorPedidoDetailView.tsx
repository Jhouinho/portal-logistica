import { useEffect, useMemo, useRef, useState } from 'react'
import {
  Alert,
  Box,
  Button,
  Dialog,
  DialogContent,
  IconButton,
  InputAdornment,
  Stack,
  TextField,
  Typography,
} from '@mui/material'
import AddIcon from '@mui/icons-material/Add'
import BusinessOutlinedIcon from '@mui/icons-material/BusinessOutlined'
import CalendarTodayOutlinedIcon from '@mui/icons-material/CalendarTodayOutlined'
import CheckIcon from '@mui/icons-material/Check'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import EditOutlinedIcon from '@mui/icons-material/EditOutlined'
import RemoveIcon from '@mui/icons-material/Remove'
import SearchIcon from '@mui/icons-material/Search'
import {
  api,
  type ArtigoSugestao,
  type StaffPmPedidoDetalhe,
  type StaffPmPedidoLinha,
} from '../../shared/api'
import { labels } from '../../shared/i18n/labels'
import { OperadorEstadoBadge, OperadorInfoAdicional, fmtDataHora, fmtEuro } from './operadorUi'

type DraftLinha = {
  key: string
  /** Ordem original no servidor (preserva PrecoSubmissao); null = nova. */
  linhaOrdOrigem: number | null
  ref: string
  design: string
  cor: string
  qtt: number
  precoSubmissao: number
  precoUnitario: number
}

function newKey(): string {
  return `L-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`
}

function fromServer(linhas: StaffPmPedidoLinha[]): DraftLinha[] {
  return linhas.map((l) => ({
    key: newKey(),
    linhaOrdOrigem: l.linhaOrd,
    ref: l.ref,
    design: l.design,
    cor: l.cor,
    qtt: l.qtt,
    precoSubmissao: l.precoSubmissao,
    precoUnitario: l.precoUnitario,
  }))
}

type Props = {
  item: StaffPmPedidoDetalhe
  busy: boolean
  erro: string | null
  sucesso: string | null
  onClearErro: () => void
  onClearSucesso: () => void
  onSaved: (d: StaffPmPedidoDetalhe) => void
  onAprovar: () => void
  onRejeitarOpen: () => void
  onError: (msg: string) => void
  onBusy: (v: boolean) => void
}

export function OperadorPedidoDetailView({
  item,
  busy,
  erro,
  sucesso,
  onClearErro,
  onClearSucesso,
  onSaved,
  onAprovar,
  onRejeitarOpen,
  onError,
  onBusy,
}: Props) {
  const [draft, setDraft] = useState<DraftLinha[]>(() => fromServer(item.linhas))
  const [editKey, setEditKey] = useState<string | null>(null)
  const [editQtt, setEditQtt] = useState(1)
  const [editPreco, setEditPreco] = useState('0')
  const [addOpen, setAddOpen] = useState(false)
  const [addQ, setAddQ] = useState('')
  const [sugestoes, setSugestoes] = useState<ArtigoSugestao[]>([])
  const [addBusy, setAddBusy] = useState(false)
  const [delKey, setDelKey] = useState<string | null>(null)
  const actionLock = useRef(false)

  useEffect(() => {
    setDraft(fromServer(item.linhas))
  }, [item.pedidoId, item.dataAlteracao, item.linhas])

  const totalDraft = useMemo(
    () =>
      Math.round(
        draft.reduce((s, l) => s + l.qtt * l.precoUnitario, 0) * 1e6,
      ) / 1e6,
    [draft],
  )

  const editLinha = draft.find((l) => l.key === editKey) ?? null
  const delLinha = draft.find((l) => l.key === delKey) ?? null
  const podeEditar = item.podeEditarPrecos
  const dirty =
    JSON.stringify(
      draft.map((l) => [l.linhaOrdOrigem, l.ref, l.cor, l.qtt, l.precoUnitario]),
    ) !==
    JSON.stringify(
      item.linhas.map((l) => [l.linhaOrd, l.ref, l.cor, l.qtt, l.precoUnitario]),
    )

  function openEdit(l: DraftLinha) {
    setEditKey(l.key)
    setEditQtt(l.qtt)
    setEditPreco(String(l.precoUnitario))
  }

  function applyEdit() {
    if (!editKey) return
    const preco = Number(String(editPreco).replace(',', '.'))
    if (!Number.isFinite(preco) || preco < 0) {
      onError('Preço operador inválido.')
      return
    }
    if (!Number.isInteger(editQtt) || editQtt <= 0) {
      onError('A quantidade deve ser um inteiro positivo.')
      return
    }
    setDraft((prev) =>
      prev.map((l) =>
        l.key === editKey ? { ...l, qtt: editQtt, precoUnitario: preco } : l,
      ),
    )
    setEditKey(null)
  }

  async function searchArtigos(q: string) {
    setAddQ(q)
    if (q.trim().length < 2) {
      setSugestoes([])
      return
    }
    setAddBusy(true)
    try {
      setSugestoes(await api.artigoSugestoes(q.trim(), 20))
    } catch {
      setSugestoes([])
    } finally {
      setAddBusy(false)
    }
  }

  function addArtigo(s: ArtigoSugestao) {
    setDraft((prev) => [
      ...prev,
      {
        key: newKey(),
        linhaOrdOrigem: null,
        ref: s.ref,
        design: s.design,
        cor: s.cor || '',
        qtt: 1,
        precoSubmissao: 0,
        precoUnitario: 0,
      },
    ])
    setAddOpen(false)
    setAddQ('')
    setSugestoes([])
  }

  function confirmDelete() {
    if (!delKey) return
    setDraft((prev) => prev.filter((l) => l.key !== delKey))
    setDelKey(null)
  }

  async function guardarAlteracoes() {
    if (actionLock.current || !podeEditar) return
    if (draft.length === 0) {
      onError('É obrigatória pelo menos uma linha.')
      return
    }
    actionLock.current = true
    onBusy(true)
    onClearErro()
    onClearSucesso()
    try {
      const d = await api.staffPmGuardarLinhas(
        item.pedidoId,
        draft.map((l) => ({
          linhaOrd: l.linhaOrdOrigem,
          ref: l.ref,
          design: l.design,
          cor: l.cor,
          qtt: l.qtt,
          precoUnitario: l.precoUnitario,
        })),
      )
      onSaved(d)
    } catch (e) {
      onError(e instanceof Error ? e.message : labels.erroGenerico)
    } finally {
      onBusy(false)
      actionLock.current = false
    }
  }

  return (
    <Box>
      <Stack direction="row" justifyContent="space-between" alignItems="flex-start" mb={2} gap={1}>
        <Box minWidth={0}>
          <Typography variant="h6" fontWeight={800} noWrap>
            {item.numeroInterno}
          </Typography>
          <OperadorEstadoBadge codigo={item.estadoCodigo} etiqueta={item.estadoEtiqueta} />
        </Box>
      </Stack>

      <Box
        sx={{
          bgcolor: 'background.paper',
          borderRadius: 2.5,
          border: 1,
          borderColor: 'portal.border',
          p: 2,
          mb: 2,
        }}
      >
        <Stack spacing={1}>
          <Stack direction="row" spacing={1} alignItems="flex-start">
            <BusinessOutlinedIcon sx={{ fontSize: 18, color: 'text.secondary', mt: '2px' }} />
            <Typography variant="body2" color="text.secondary">
              {item.clienteNome || '—'} ({item.clNo}
              {item.clEstab ? `/${item.clEstab}` : ''})
            </Typography>
          </Stack>
          <Stack direction="row" justifyContent="space-between" alignItems="center">
            <Stack direction="row" spacing={0.75} alignItems="center">
              <CalendarTodayOutlinedIcon sx={{ fontSize: 15, color: 'text.secondary' }} />
              <Typography variant="caption" color="text.secondary">
                {fmtDataHora(item.dataSubmissao)}
              </Typography>
            </Stack>
            <Typography fontWeight={800} color="primary.main" fontSize="1.2rem">
              {fmtEuro(podeEditar ? totalDraft : item.etotaldeb)}
            </Typography>
          </Stack>
        </Stack>
      </Box>

      <OperadorInfoAdicional
        info={{
          bostamp: item.bostamp,
          obrano: item.obrano,
          boano: item.boano,
          ndos: item.ndos,
          motivoRejeicao: item.motivoRejeicao,
          decididoPor: item.decididoPor,
          dataDecisao: item.dataDecisao,
        }}
      />

      {erro && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={onClearErro}>
          {erro}
        </Alert>
      )}
      {sucesso && (
        <Alert severity="success" sx={{ mb: 2 }} onClose={onClearSucesso}>
          {sucesso}
        </Alert>
      )}

      <Typography variant="subtitle2" fontWeight={800} mb={1.25}>
        Artigos do pedido
      </Typography>

      <Stack spacing={1.5} mb={2}>
        {draft.map((l, idx) => (
          <Box
            key={l.key}
            sx={{
              bgcolor: 'background.paper',
              borderRadius: 2.5,
              border: 1,
              borderColor: 'portal.border',
              p: 1.75,
            }}
          >
            <Stack direction="row" justifyContent="space-between" alignItems="flex-start" mb={1}>
              <Typography fontWeight={800} fontSize="0.95rem" pr={1}>
                {idx + 1}. Ref. {l.ref} {l.design}
              </Typography>
              {podeEditar && (
                <IconButton
                  size="small"
                  color="error"
                  aria-label="Eliminar artigo"
                  onClick={() => setDelKey(l.key)}
                  disabled={busy}
                >
                  <DeleteOutlineIcon fontSize="small" />
                </IconButton>
              )}
            </Stack>
            <Typography variant="body2" color="text.secondary" mb={0.5}>
              Cor: {l.cor || '—'}
            </Typography>
            <Typography variant="body2" color="text.secondary" mb={0.5}>
              Quantidade: {l.qtt}
            </Typography>
            <Typography variant="body2" color="text.secondary" mb={0.5}>
              Preço submetido: {fmtEuro(l.precoSubmissao)}
            </Typography>
            <Stack direction="row" alignItems="center" justifyContent="space-between">
              <Typography variant="body2" fontWeight={700} color="primary.main">
                Preço operador: {fmtEuro(l.precoUnitario)}
              </Typography>
              {podeEditar && (
                <IconButton
                  size="small"
                  color="primary"
                  aria-label="Editar artigo"
                  onClick={() => openEdit(l)}
                  disabled={busy}
                >
                  <EditOutlinedIcon fontSize="small" />
                </IconButton>
              )}
            </Stack>
          </Box>
        ))}
      </Stack>

      {podeEditar && (
        <Button
          fullWidth
          variant="outlined"
          color="primary"
          startIcon={<AddIcon />}
          onClick={() => setAddOpen(true)}
          disabled={busy}
          sx={{
            mb: 2,
            minHeight: 48,
            fontWeight: 700,
            textTransform: 'none',
            borderRadius: 2,
            borderWidth: 1.5,
            borderStyle: 'dashed',
          }}
        >
          Adicionar artigo
        </Button>
      )}

      <Stack spacing={1.25}>
        {podeEditar && (
          <Button
            fullWidth
            variant="outlined"
            color="primary"
            disabled={busy || !dirty}
            onClick={() => void guardarAlteracoes()}
            sx={{ minHeight: 48, fontWeight: 700, textTransform: 'none', borderRadius: 2 }}
          >
            Guardar alterações
          </Button>
        )}
        {item.podeAprovar && (
          <Button
            fullWidth
            variant="contained"
            color="success"
            disabled={busy || dirty}
            startIcon={<CheckIcon />}
            onClick={onAprovar}
            sx={{ minHeight: 48, fontWeight: 700, textTransform: 'none', borderRadius: 2 }}
          >
            {busy ? 'A processar…' : 'Validar no balcão e criar dossier PHC'}
          </Button>
        )}
        {item.podeRejeitar && (
          <Button
            fullWidth
            variant="outlined"
            color="error"
            disabled={busy || dirty}
            onClick={onRejeitarOpen}
            sx={{ minHeight: 48, fontWeight: 700, textTransform: 'none', borderRadius: 2 }}
          >
            Rejeitar
          </Button>
        )}
        {dirty && podeEditar && (
          <Typography variant="caption" color="warning.main" textAlign="center">
            Guarde as alterações antes de aprovar ou rejeitar.
          </Typography>
        )}
      </Stack>

      {/* Editar quantidade / preço */}
      <Dialog open={!!editLinha} onClose={() => !busy && setEditKey(null)} fullWidth maxWidth="xs">
        <DialogContent sx={{ pt: 3, pb: 2.5 }}>
          {editLinha && (
            <Stack spacing={2}>
              <Typography fontWeight={800}>
                Ref. {editLinha.ref} {editLinha.design}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Cor: {editLinha.cor || '—'}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Preço submetido: {fmtEuro(editLinha.precoSubmissao)}
              </Typography>
              <TextField
                label="Preço operador"
                value={editPreco}
                onChange={(e) => setEditPreco(e.target.value)}
                inputProps={{ inputMode: 'decimal' }}
                fullWidth
              />
              <Typography variant="body2" fontWeight={700}>
                Quantidade
              </Typography>
              <Stack direction="row" alignItems="center" justifyContent="center" spacing={2}>
                <IconButton
                  color="primary"
                  onClick={() => setEditQtt((q) => Math.max(1, q - 1))}
                  sx={{ border: 1, borderColor: 'portal.border' }}
                >
                  <RemoveIcon />
                </IconButton>
                <Typography fontWeight={800} fontSize="1.4rem" minWidth={48} textAlign="center">
                  {editQtt}
                </Typography>
                <IconButton
                  color="primary"
                  onClick={() => setEditQtt((q) => q + 1)}
                  sx={{ border: 1, borderColor: 'portal.border' }}
                >
                  <AddIcon />
                </IconButton>
              </Stack>
              <Button
                fullWidth
                variant="contained"
                onClick={applyEdit}
                sx={{ minHeight: 48, fontWeight: 700, textTransform: 'none' }}
              >
                Guardar
              </Button>
              <Button fullWidth onClick={() => setEditKey(null)} sx={{ textTransform: 'none' }}>
                Cancelar
              </Button>
            </Stack>
          )}
        </DialogContent>
      </Dialog>

      {/* Adicionar artigo */}
      <Dialog open={addOpen} onClose={() => !busy && setAddOpen(false)} fullWidth maxWidth="sm">
        <DialogContent sx={{ pt: 3, pb: 2.5 }}>
          <Typography fontWeight={800} mb={2}>
            Adicionar artigo
          </Typography>
          <TextField
            fullWidth
            placeholder="Pesquisar por referência ou nome"
            value={addQ}
            onChange={(e) => void searchArtigos(e.target.value)}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <SearchIcon color="primary" />
                </InputAdornment>
              ),
            }}
            sx={{ mb: 2 }}
          />
          <Stack spacing={1} maxHeight={360} overflow="auto">
            {addBusy && (
              <Typography variant="body2" color="text.secondary" textAlign="center">
                A procurar…
              </Typography>
            )}
            {!addBusy && addQ.trim().length >= 2 && sugestoes.length === 0 && (
              <Typography variant="body2" color="text.secondary" textAlign="center">
                Sem resultados.
              </Typography>
            )}
            {sugestoes.map((s) => (
              <Stack
                key={`${s.ref}|${s.cor}|${s.design}`}
                direction="row"
                alignItems="center"
                spacing={1}
                sx={{
                  p: 1.25,
                  borderRadius: 2,
                  border: 1,
                  borderColor: 'portal.border',
                  bgcolor: 'background.paper',
                }}
              >
                <Box flex={1} minWidth={0}>
                  <Typography fontWeight={700} noWrap>
                    Ref. {s.ref}
                  </Typography>
                  <Typography variant="body2" color="text.secondary" noWrap>
                    {s.design}
                    {s.cor ? ` · ${s.cor}` : ''}
                  </Typography>
                </Box>
                <IconButton color="primary" onClick={() => addArtigo(s)} aria-label="Adicionar">
                  <AddIcon />
                </IconButton>
              </Stack>
            ))}
          </Stack>
          <Button fullWidth sx={{ mt: 2, textTransform: 'none' }} onClick={() => setAddOpen(false)}>
            Fechar
          </Button>
        </DialogContent>
      </Dialog>

      {/* Eliminar */}
      <Dialog open={!!delLinha} onClose={() => setDelKey(null)} fullWidth maxWidth="xs">
        <DialogContent sx={{ pt: 3, pb: 2.5, textAlign: 'center' }}>
          <Box
            mx="auto"
            mb={2}
            width={64}
            height={64}
            borderRadius="50%"
            display="flex"
            alignItems="center"
            justifyContent="center"
            bgcolor="rgba(255,92,92,0.15)"
            color="error.main"
          >
            <DeleteOutlineIcon fontSize="large" />
          </Box>
          <Typography fontWeight={800} mb={1}>
            Eliminar artigo
          </Typography>
          <Typography variant="body2" color="text.secondary" mb={2}>
            Tem a certeza que pretende eliminar este artigo do pedido?
          </Typography>
          {delLinha && (
            <Typography variant="body2" fontWeight={700} mb={2.5}>
              Ref. {delLinha.ref} {delLinha.design}
            </Typography>
          )}
          <Button
            fullWidth
            variant="contained"
            color="error"
            onClick={confirmDelete}
            sx={{ minHeight: 48, fontWeight: 700, textTransform: 'none', mb: 1 }}
          >
            Eliminar
          </Button>
          <Button fullWidth onClick={() => setDelKey(null)} sx={{ textTransform: 'none' }}>
            Cancelar
          </Button>
        </DialogContent>
      </Dialog>
    </Box>
  )
}

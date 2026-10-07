import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  Alert,
  Autocomplete,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  IconButton,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import ArrowBackIcon from '@mui/icons-material/ArrowBack'
import InfoOutlinedIcon from '@mui/icons-material/InfoOutlined'
import {
  api,
  type PrevisaoArtigoSugestao,
  type PrevisaoEntradaDetalhe,
  type PrevisaoEntradaListaItem,
} from '../../shared/api'
import { labels } from '../../shared/i18n/labels'
import { DateFilterField } from '../../shared/ui/DateFilterField'
import { PortalEmptyState } from '../centro/portalChrome'

function fmtPeriodo(de: string, ate: string) {
  const f = (s: string) => {
    const [y, m, d] = s.split('-')
    return y && m && d ? `${d}/${m}/${y}` : s
  }
  return `${f(de)} → ${f(ate)}`
}

function fmtQty(n: number) {
  return new Intl.NumberFormat('pt-PT', { maximumFractionDigits: 2 }).format(n)
}

function labelSugestao(a: PrevisaoArtigoSugestao) {
  return [a.ref.trim(), a.design.trim()].filter(Boolean).join(' · ')
}

function chipEstado(fechada: boolean) {
  return fechada ? (
    <Chip size="small" label={labels.previsaoEstadoFechada} color="default" variant="outlined" />
  ) : (
    <Chip size="small" label={labels.previsaoEstadoAberta} color="success" variant="outlined" />
  )
}

type LinhaDraft = {
  key: string
  ref: string
  cor: string
  design: string
  quantidadePrevista: string
  quantidadeAlocada: number
  quantidadeDisponivel: number
}

export function PrevisoesEntradaPanel() {
  const [lista, setLista] = useState<PrevisaoEntradaListaItem[]>([])
  const [loading, setLoading] = useState(true)
  const [erro, setErro] = useState<string | null>(null)
  const [ok, setOk] = useState<string | null>(null)

  const [criarOpen, setCriarOpen] = useState(false)
  const [dataInicio, setDataInicio] = useState('')
  const [dataFim, setDataFim] = useState('')
  const [criando, setCriando] = useState(false)

  const [detalheId, setDetalheId] = useState<string | null>(null)
  const [cabecalho, setCabecalho] = useState<PrevisaoEntradaDetalhe | null>(null)
  const [editDataInicio, setEditDataInicio] = useState('')
  const [editDataFim, setEditDataFim] = useState('')
  const [linhas, setLinhas] = useState<LinhaDraft[]>([])
  const [loadingDetalhe, setLoadingDetalhe] = useState(false)
  const [guardando, setGuardando] = useState(false)
  const [dirty, setDirty] = useState(false)
  const [fecharOpen, setFecharOpen] = useState(false)
  const [fechando, setFechando] = useState(false)
  const [atualizandoLinhas, setAtualizandoLinhas] = useState(false)

  const [artigoInput, setArtigoInput] = useState('')
  const [sugestoes, setSugestoes] = useState<PrevisaoArtigoSugestao[]>([])
  const [loadingSug, setLoadingSug] = useState(false)
  const [coresPorRef, setCoresPorRef] = useState<Record<string, string[]>>({})

  const temAberta = useMemo(() => lista.some((p) => !p.fechada), [lista])
  const soLeitura = cabecalho?.fechada === true

  const carregarCores = useCallback(async (ref: string) => {
    const r = ref.trim()
    if (!r) return
    setCoresPorRef((prev) => {
      if (prev[r]) return prev
      return prev
    })
    try {
      const items = await api.previsoesEntradaSugestoesCores(r)
      setCoresPorRef((prev) => {
        if (prev[r]) return prev
        return { ...prev, [r]: items.map((i) => i.cor) }
      })
    } catch {
      /* sugestões opcionais */
    }
  }, [])
  const carregarLista = useCallback(async () => {
    setLoading(true)
    setErro(null)
    try {
      setLista(await api.previsoesEntradaListar())
    } catch (e) {
      setErro(e instanceof Error ? e.message : labels.erroGenerico)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void carregarLista()
  }, [carregarLista])

  useEffect(() => {
    const q = artigoInput.trim()
    if (q.length < 1 || soLeitura) {
      setSugestoes([])
      return
    }
    let cancelled = false
    const t = window.setTimeout(() => {
      setLoadingSug(true)
      void api
        .previsoesEntradaSugestoes(q)
        .then((items) => {
          if (!cancelled) setSugestoes(items)
        })
        .catch(() => {
          if (!cancelled) setSugestoes([])
        })
        .finally(() => {
          if (!cancelled) setLoadingSug(false)
        })
    }, 250)
    return () => {
      cancelled = true
      window.clearTimeout(t)
    }
  }, [artigoInput, soLeitura])

  async function abrir(id: string) {
    setErro(null)
    setOk(null)
    setLoadingDetalhe(true)
    setDetalheId(id)
    try {
      const d = await api.previsoesEntradaObter(id)
      setCabecalho(d)
      setEditDataInicio(d.dataInicio)
      setEditDataFim(d.dataFim)
      setLinhas(
        d.linhas.map((l, i) => ({
          key: `${l.ref}|${l.cor}|${i}`,
          ref: l.ref,
          cor: l.cor ?? '',
          design: l.design,
          quantidadePrevista: String(l.quantidadePrevista),
          quantidadeAlocada: l.quantidadeAlocada,
          quantidadeDisponivel: l.quantidadeDisponivel,
        })),
      )
      setDirty(false)
      for (const l of d.linhas) {
        void carregarCores(l.ref)
      }
    } catch (e) {
      setErro(e instanceof Error ? e.message : labels.erroGenerico)
      setDetalheId(null)
      setCabecalho(null)
    } finally {
      setLoadingDetalhe(false)
    }
  }

  function voltarLista() {
    setDetalheId(null)
    setCabecalho(null)
    setLinhas([])
    setDirty(false)
    setArtigoInput('')
    setEditDataInicio('')
    setEditDataFim('')
    void carregarLista()
  }

  async function criar() {
    if (!dataInicio || !dataFim) {
      setErro(labels.previsaoDatasObrigatorias)
      return
    }
    if (dataInicio > dataFim) {
      setErro(labels.previsaoDatasInvalidas)
      return
    }
    setCriando(true)
    setErro(null)
    try {
      const created = await api.previsoesEntradaCriar({ dataInicio, dataFim })
      setCriarOpen(false)
      setDataInicio('')
      setDataFim('')
      const n = created.linhas?.length ?? 0
      setOk(
        n > 0
          ? labels.previsaoCriadaComLinhasOk.replace('{n}', String(n))
          : labels.previsaoCriadaOk,
      )
      await abrir(created.id)
    } catch (e) {
      setErro(e instanceof Error ? e.message : labels.erroGenerico)
    } finally {
      setCriando(false)
    }
  }

  function adicionarArtigo(a: PrevisaoArtigoSugestao | null) {
    if (soLeitura) return
    if (!a?.ref.trim()) return
    const ref = a.ref.trim()
    // Nova linha começa com Cor='' (combinação válida e distinta).
    if (linhas.some((l) => l.ref.toLowerCase() === ref.toLowerCase() && l.cor === '')) {
      setErro(labels.previsaoArtigoDuplicado)
      return
    }
    setErro(null)
    setLinhas((prev) => [
      ...prev,
      {
        key: `${ref}||${Date.now()}`,
        ref,
        cor: '',
        design: a.design.trim(),
        quantidadePrevista: '0',
        quantidadeAlocada: 0,
        quantidadeDisponivel: 0,
      },
    ])
    setDirty(true)
    setArtigoInput('')
    setSugestoes([])
    void carregarCores(ref)
  }

  function removerLinha(key: string) {
    if (soLeitura) return
    setLinhas((prev) => prev.filter((l) => l.key !== key))
    setDirty(true)
  }

  function setQty(key: string, value: string) {
    if (soLeitura) return
    setLinhas((prev) =>
      prev.map((l) => (l.key === key ? { ...l, quantidadePrevista: value } : l)),
    )
    setDirty(true)
  }

  function setCor(key: string, value: string) {
    if (soLeitura) return
    setLinhas((prev) => {
      const target = prev.find((l) => l.key === key)
      if (!target) return prev
      const cor = value // sem TRIM — semântica BI.u_cor
      const duplicada = prev.some(
        (l) =>
          l.key !== key &&
          l.ref.toLowerCase() === target.ref.toLowerCase() &&
          l.cor === cor,
      )
      if (duplicada) {
        setErro(labels.previsaoArtigoDuplicado)
        return prev
      }
      setErro(null)
      return prev.map((l) => (l.key === key ? { ...l, cor } : l))
    })
    setDirty(true)
  }

  async function guardar() {
    if (!detalheId || soLeitura) return
    if (!editDataInicio || !editDataFim) {
      setErro(labels.previsaoDatasObrigatorias)
      return
    }
    if (editDataInicio > editDataFim) {
      setErro(labels.previsaoDatasInvalidas)
      return
    }
    const keys = new Set<string>()
    for (const l of linhas) {
      const k = `${l.ref.toLowerCase()}|${l.cor}`
      if (keys.has(k)) {
        setErro(labels.previsaoArtigoDuplicado)
        return
      }
      keys.add(k)
    }
    setGuardando(true)
    setErro(null)
    setOk(null)
    try {
      const payload = linhas.map((l) => {
        const n = Number(String(l.quantidadePrevista).replace(',', '.'))
        return {
          ref: l.ref,
          cor: l.cor,
          quantidadePrevista: Number.isFinite(n) && n >= 0 ? n : 0,
        }
      })
      const saved = await api.previsoesEntradaGuardar(detalheId, {
        dataInicio: editDataInicio,
        dataFim: editDataFim,
        linhas: payload,
      })
      setCabecalho(saved)
      setEditDataInicio(saved.dataInicio)
      setEditDataFim(saved.dataFim)
      setLinhas(
        saved.linhas.map((l, i) => ({
          key: `${l.ref}|${l.cor}|${i}`,
          ref: l.ref,
          cor: l.cor ?? '',
          design: l.design,
          quantidadePrevista: String(l.quantidadePrevista),
          quantidadeAlocada: l.quantidadeAlocada,
          quantidadeDisponivel: l.quantidadeDisponivel,
        })),
      )
      setDirty(false)
      setOk(labels.previsaoGuardadaOk)
    } catch (e) {
      setErro(e instanceof Error ? e.message : labels.erroGenerico)
    } finally {
      setGuardando(false)
    }
  }

  async function fecharPrevisao() {
    if (!detalheId || soLeitura || dirty) return
    setFechando(true)
    setErro(null)
    setOk(null)
    try {
      const closed = await api.previsoesEntradaFechar(detalheId)
      setCabecalho(closed)
      setEditDataInicio(closed.dataInicio)
      setEditDataFim(closed.dataFim)
      setLinhas(
        closed.linhas.map((l, i) => ({
          key: `${l.ref}|${l.cor}|${i}`,
          ref: l.ref,
          cor: l.cor ?? '',
          design: l.design,
          quantidadePrevista: String(l.quantidadePrevista),
          quantidadeAlocada: l.quantidadeAlocada,
          quantidadeDisponivel: l.quantidadeDisponivel,
        })),
      )
      setDirty(false)
      setFecharOpen(false)
      setOk(labels.previsaoFechadaOk)
      void carregarLista()
    } catch (e) {
      setErro(e instanceof Error ? e.message : labels.erroGenerico)
    } finally {
      setFechando(false)
    }
  }

  async function atualizarLinhasDeEncomendas() {
    if (!detalheId || soLeitura || dirty) return
    setAtualizandoLinhas(true)
    setErro(null)
    setOk(null)
    try {
      const res = await api.previsoesEntradaAtualizarLinhas(detalheId)
      const d = res.detalhe
      setCabecalho(d)
      setEditDataInicio(d.dataInicio)
      setEditDataFim(d.dataFim)
      setLinhas(
        d.linhas.map((l, i) => ({
          key: `${l.ref}|${l.cor}|${i}`,
          ref: l.ref,
          cor: l.cor ?? '',
          design: l.design,
          quantidadePrevista: String(l.quantidadePrevista),
          quantidadeAlocada: l.quantidadeAlocada,
          quantidadeDisponivel: l.quantidadeDisponivel,
        })),
      )
      setDirty(false)
      setOk(
        res.linhasAdicionadas > 0
          ? labels.previsaoAtualizarLinhasOk.replace('{n}', String(res.linhasAdicionadas))
          : labels.previsaoAtualizarLinhasNenhuma,
      )
    } catch (e) {
      setErro(e instanceof Error ? e.message : labels.erroGenerico)
    } finally {
      setAtualizandoLinhas(false)
    }
  }

  if (detalheId) {
    return (
      <Box>
        <Button
          startIcon={<ArrowBackIcon />}
          onClick={voltarLista}
          sx={{ mb: 2 }}
          size="small"
        >
          {labels.previsaoVoltarLista}
        </Button>

        {erro && (
          <Alert severity="error" sx={{ mb: 2 }} onClose={() => setErro(null)}>
            {erro}
          </Alert>
        )}
        {ok && (
          <Alert severity="success" sx={{ mb: 2 }} onClose={() => setOk(null)}>
            {ok}
          </Alert>
        )}

        {loadingDetalhe || !cabecalho ? (
          <Box display="flex" justifyContent="center" py={6}>
            <CircularProgress />
          </Box>
        ) : (
          <>
            <Box display="flex" alignItems="center" gap={1.5} mb={1} flexWrap="wrap">
              <Typography variant="h6" fontWeight={700}>
                {labels.previsoesEntrada}
              </Typography>
              {chipEstado(cabecalho.fechada)}
            </Box>

            {soLeitura ? (
              <Alert severity="info" sx={{ mb: 2 }}>
                {labels.previsaoFechadaSoLeitura}
                {cabecalho.fechadaPor || cabecalho.fechadaEm
                  ? ` (${[
                      cabecalho.fechadaPor,
                      cabecalho.fechadaEm
                        ? new Date(cabecalho.fechadaEm).toLocaleString('pt-PT')
                        : null,
                    ]
                      .filter(Boolean)
                      .join(' · ')})`
                  : ''}
              </Alert>
            ) : null}

            <Box display="flex" gap={2} mb={2} flexWrap="wrap" alignItems="flex-end">
              <DateFilterField
                label={labels.previsaoDataInicio}
                value={editDataInicio}
                disabled={soLeitura}
                onChange={(v) => {
                  if (soLeitura) return
                  setEditDataInicio(v)
                  setDirty(true)
                }}
                width={200}
              />
              <DateFilterField
                label={labels.previsaoDataFim}
                value={editDataFim}
                disabled={soLeitura}
                onChange={(v) => {
                  if (soLeitura) return
                  setEditDataFim(v)
                  setDirty(true)
                }}
                width={200}
              />
            </Box>

            <Box display="flex" gap={2} mb={2} flexWrap="wrap" alignItems="center">
              <Autocomplete
                sx={{ minWidth: 320, flex: 1 }}
                disabled={soLeitura}
                options={sugestoes}
                loading={loadingSug}
                inputValue={artigoInput}
                onInputChange={(_, v) => setArtigoInput(v)}
                onChange={(_, v) => adicionarArtigo(v)}
                getOptionLabel={labelSugestao}
                isOptionEqualToValue={(a, b) => a.ref === b.ref}
                noOptionsText={
                  artigoInput.trim()
                    ? labels.previsaoSemSugestoes
                    : labels.previsaoEscreverPesquisa
                }
                renderInput={(params) => (
                  <TextField
                    {...params}
                    size="small"
                    label={labels.previsaoAdicionarArtigo}
                    placeholder="Referência ou designação…"
                  />
                )}
              />
              <Button
                variant="contained"
                onClick={() => void guardar()}
                disabled={soLeitura || guardando || !dirty}
              >
                {labels.previsaoGuardar}
              </Button>
              {!soLeitura ? (
                <Tooltip title={labels.previsaoAtualizarLinhasHint}>
                  <span>
                    <Button
                      variant="outlined"
                      onClick={() => void atualizarLinhasDeEncomendas()}
                      disabled={guardando || fechando || atualizandoLinhas || dirty}
                    >
                      {atualizandoLinhas ? (
                        <CircularProgress size={18} color="inherit" />
                      ) : (
                        labels.previsaoAtualizarLinhas
                      )}
                    </Button>
                  </span>
                </Tooltip>
              ) : null}
              {!soLeitura ? (
                <Button
                  variant="outlined"
                  color="warning"
                  onClick={() => setFecharOpen(true)}
                  disabled={guardando || fechando || atualizandoLinhas || dirty}
                  title={dirty ? labels.previsaoGuardar : undefined}
                >
                  {labels.previsaoFechar}
                </Button>
              ) : null}
            </Box>

            <Dialog
              open={fecharOpen}
              onClose={() => !fechando && setFecharOpen(false)}
              maxWidth="xs"
              fullWidth
            >
              <DialogTitle>{labels.previsaoFecharTitulo}</DialogTitle>
              <DialogContent>
                <DialogContentText>{labels.previsaoFecharMsg}</DialogContentText>
              </DialogContent>
              <DialogActions>
                <Button onClick={() => setFecharOpen(false)} disabled={fechando}>
                  {labels.cancelar}
                </Button>
                <Button
                  variant="contained"
                  color="warning"
                  onClick={() => void fecharPrevisao()}
                  disabled={fechando}
                >
                  {fechando ? <CircularProgress size={18} color="inherit" /> : labels.previsaoFechar}
                </Button>
              </DialogActions>
            </Dialog>

            <Paper>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>{labels.previsaoColRef}</TableCell>
                    <TableCell sx={{ width: 160 }}>{labels.previsaoColCor}</TableCell>
                    <TableCell>{labels.previsaoColDesign}</TableCell>
                    <TableCell align="right" sx={{ width: 140 }}>
                      {labels.previsaoColQty}
                    </TableCell>
                    <TableCell align="right" sx={{ width: 120 }}>
                      <Box
                        component="span"
                        display="inline-flex"
                        alignItems="center"
                        justifyContent="flex-end"
                        gap={0.5}
                      >
                        {labels.previsaoColAlocado}
                        <Tooltip title={labels.previsaoAlocadoTooltip}>
                          <InfoOutlinedIcon
                            fontSize="inherit"
                            sx={{ fontSize: 14, color: 'text.secondary' }}
                            aria-label={labels.previsaoAlocadoTooltip}
                          />
                        </Tooltip>
                      </Box>
                    </TableCell>
                    <TableCell align="right" sx={{ width: 120 }}>
                      {labels.previsaoColDisponivel}
                    </TableCell>
                    <TableCell align="right" sx={{ width: 56 }} />
                  </TableRow>
                </TableHead>
                <TableBody>
                  {linhas.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={7}>
                        <PortalEmptyState message={labels.previsaoSemLinhas} />
                      </TableCell>
                    </TableRow>
                  ) : (
                    linhas.map((l) => {
                      const corOpts = coresPorRef[l.ref] ?? []
                      const options =
                        l.cor && !corOpts.includes(l.cor)
                          ? [...corOpts, l.cor]
                          : corOpts
                      return (
                        <TableRow key={l.key} hover>
                          <TableCell>{l.ref}</TableCell>
                          <TableCell>
                            <Autocomplete
                              size="small"
                              freeSolo
                              disabled={soLeitura}
                              options={options}
                              value={l.cor}
                              onOpen={() => void carregarCores(l.ref)}
                              onChange={(_, v) => setCor(l.key, v ?? '')}
                              onInputChange={(_, v, reason) => {
                                if (reason === 'input') setCor(l.key, v)
                              }}
                              getOptionLabel={(o) =>
                                o === '' ? labels.previsaoCorPlaceholder : o
                              }
                              renderOption={(props, option) => (
                                <li {...props} key={option === '' ? '__blank__' : option}>
                                  {option === ''
                                    ? labels.previsaoCorPlaceholder
                                    : option}
                                </li>
                              )}
                              renderInput={(params) => (
                                <TextField
                                  {...params}
                                  placeholder={labels.previsaoCorPlaceholder}
                                />
                              )}
                              sx={{ minWidth: 140 }}
                            />
                          </TableCell>
                          <TableCell>{l.design || '—'}</TableCell>
                          <TableCell align="right">
                            <TextField
                              size="small"
                              value={l.quantidadePrevista}
                              onChange={(e) => setQty(l.key, e.target.value)}
                              disabled={soLeitura}
                              inputProps={{
                                inputMode: 'decimal',
                                style: { textAlign: 'right' },
                                readOnly: soLeitura,
                              }}
                              sx={{ width: 120 }}
                            />
                          </TableCell>
                          <TableCell align="right">{fmtQty(l.quantidadeAlocada)}</TableCell>
                          <TableCell align="right">{fmtQty(l.quantidadeDisponivel)}</TableCell>
                          <TableCell align="right">
                            <IconButton
                              size="small"
                              aria-label={labels.previsaoRemover}
                              onClick={() => removerLinha(l.key)}
                              disabled={soLeitura}
                            >
                              <DeleteOutlineIcon fontSize="small" />
                            </IconButton>
                          </TableCell>
                        </TableRow>
                      )
                    })
                  )}
                </TableBody>
              </Table>
            </Paper>
          </>
        )}
      </Box>
    )
  }

  return (
    <Box>
      {erro && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setErro(null)}>
          {erro}
        </Alert>
      )}
      {ok && (
        <Alert severity="success" sx={{ mb: 2 }} onClose={() => setOk(null)}>
          {ok}
        </Alert>
      )}

      <Box
        display="flex"
        alignItems="center"
        gap={2}
        mb={2}
        flexWrap="wrap"
        justifyContent="space-between"
      >
        {temAberta ? (
          <Alert severity="info" sx={{ flex: 1, minWidth: 240, py: 0.5 }}>
            {labels.previsaoJaExisteAberta}
          </Alert>
        ) : (
          <Box sx={{ flex: 1 }} />
        )}
        <Button
          variant="contained"
          onClick={() => setCriarOpen(true)}
          disabled={temAberta}
          title={temAberta ? labels.previsaoJaExisteAberta : undefined}
          sx={{ flexShrink: 0 }}
        >
          {labels.previsaoNova}
        </Button>
      </Box>

      {loading ? (
        <Box display="flex" justifyContent="center" py={6}>
          <CircularProgress />
        </Box>
      ) : lista.length === 0 ? (
        <PortalEmptyState message={labels.previsaoListaVazia} />
      ) : (
        <Paper>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>{labels.previsaoColPeriodo}</TableCell>
                <TableCell>{labels.previsaoColEstado}</TableCell>
                <TableCell align="right">{labels.previsaoColArtigos}</TableCell>
                <TableCell align="right">{labels.previsaoColQtyTotal}</TableCell>
                <TableCell align="right" />
              </TableRow>
            </TableHead>
            <TableBody>
              {lista.map((p) => (
                <TableRow key={p.id} hover>
                  <TableCell>{fmtPeriodo(p.dataInicio, p.dataFim)}</TableCell>
                  <TableCell>{chipEstado(p.fechada)}</TableCell>
                  <TableCell align="right">{p.totalLinhas}</TableCell>
                  <TableCell align="right">{fmtQty(p.quantidadeTotal)}</TableCell>
                  <TableCell align="right">
                    <Button size="small" onClick={() => void abrir(p.id)}>
                      {labels.previsaoAbrir}
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </Paper>
      )}

      <Dialog open={criarOpen} onClose={() => !criando && setCriarOpen(false)} maxWidth="xs" fullWidth>
        <DialogTitle>{labels.previsaoNova}</DialogTitle>
        <DialogContent>
          <Box display="flex" flexDirection="column" gap={2} pt={1}>
            <Typography variant="body2" color="text.secondary">
              {labels.previsaoCriarHint}
            </Typography>
            <DateFilterField
              label={labels.previsaoDataInicio}
              value={dataInicio}
              onChange={setDataInicio}
              width={280}
            />
            <DateFilterField
              label={labels.previsaoDataFim}
              value={dataFim}
              onChange={setDataFim}
              width={280}
            />
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setCriarOpen(false)} disabled={criando}>
            {labels.cancelar}
          </Button>
          <Button variant="contained" onClick={() => void criar()} disabled={criando || temAberta}>
            {labels.previsaoCriar}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  )
}

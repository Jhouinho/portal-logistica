import { useEffect, useRef, useState } from 'react'
import {
  Alert,
  Box,
  CircularProgress,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material'
import { api, type KappsPickingDetalhe, type KappsPickingLinha } from '../../shared/api'
import { labels } from '../../shared/i18n/labels'
import type { GravacaoSnack } from './GravacaoSnackbar'
import { linhasTableSx } from './linhasTableLayout'
import { PortalTableScroll } from '../centro/portalChrome'
import { kappsPendenteLinha, kappsRecolhidoLinha } from './kappsProgresso'

function fmtQty(n: number) {
  return new Intl.NumberFormat('pt-PT', { maximumFractionDigits: 2 }).format(n)
}

type Props = {
  loading: boolean
  erro: string | null
  /** null = resposta 204 (sem picking ainda); undefined = ainda não pedido */
  data: KappsPickingDetalhe | null | undefined
  /** Em Picking: editar Quantity enquanto picagem ainda não iniciou. */
  podeEditarQuantidade?: boolean
  /**
   * `separacao` = labels de Separado / A Preparar Entrega (ndos=66).
   * `picking` = Em Picking (ndos=1). Só nomenclatura.
   */
  variante?: 'picking' | 'separacao'
  onNotify?: (snack: GravacaoSnack) => void
  onQuantidadeAlterada?: (pickingLineKey: string, quantidade: number) => void
}

/** Célula de quantidade Kapps — grava BI.qtt via PickingLineKey (= bistamp). */
function KappsQuantidadeCell({
  linha,
  readOnly,
  onNotify,
  onSaved,
}: {
  linha: KappsPickingLinha
  readOnly: boolean
  onNotify?: (snack: GravacaoSnack) => void
  onSaved: (quantidade: number) => void
}) {
  const [valor, setValor] = useState(String(linha.quantity))
  const [saving, setSaving] = useState(false)
  const [invalido, setInvalido] = useState(false)
  const dirtyRef = useRef(false)
  const focusedRef = useRef(false)

  useEffect(() => {
    if (focusedRef.current || dirtyRef.current || saving) return
    setValor(String(linha.quantity))
    setInvalido(false)
  }, [linha.pickingLineKey, linha.quantity, saving])

  async function gravar() {
    if (readOnly || saving) return

    if (!dirtyRef.current) {
      setValor(String(linha.quantity))
      setInvalido(false)
      return
    }

    const raw = String(valor).trim()
    if (raw === '') {
      setInvalido(true)
      onNotify?.({ message: 'Valor inválido na quantidade.', severity: 'error' })
      setValor(String(linha.quantity))
      dirtyRef.current = false
      return
    }

    const parsed = Number(raw.replace(',', '.'))
    if (Number.isNaN(parsed) || parsed < 0) {
      setInvalido(true)
      onNotify?.({ message: 'Valor inválido na quantidade.', severity: 'error' })
      setValor(String(linha.quantity))
      dirtyRef.current = false
      return
    }
    if (parsed === linha.quantity) {
      dirtyRef.current = false
      setInvalido(false)
      return
    }

    setSaving(true)
    setInvalido(false)
    try {
      const res = await api.atualizarLinha(linha.pickingLineKey, {
        quantidade: parsed,
        quantidadeAnteriorEsperada: linha.quantity,
      })
      dirtyRef.current = false
      onSaved(res.quantidade)
      setValor(String(res.quantidade))
      onNotify?.({ message: 'Quantidade actualizada.', severity: 'success' })
    } catch (e) {
      setInvalido(true)
      onNotify?.({
        message: e instanceof Error ? e.message : 'Falha ao gravar quantidade.',
        severity: 'error',
      })
      setValor(String(linha.quantity))
      dirtyRef.current = false
    } finally {
      setSaving(false)
    }
  }

  if (readOnly) {
    return (
      <Typography component="span" sx={{ fontVariantNumeric: 'tabular-nums' }}>
        {fmtQty(linha.quantity)}
      </Typography>
    )
  }

  return (
    <Box
      onClick={(e) => e.stopPropagation()}
      sx={{ width: '100%', display: 'flex', justifyContent: 'flex-end' }}
    >
      <TextField
        size="small"
        type="number"
        value={valor}
        disabled={saving}
        inputProps={{
          min: 0,
          step: 'any',
          style: { textAlign: 'right', padding: '4px 6px' },
        }}
        onFocus={() => {
          focusedRef.current = true
        }}
        onChange={(e) => {
          dirtyRef.current = true
          setValor(e.target.value)
          setInvalido(false)
        }}
        onBlur={() => {
          focusedRef.current = false
          void gravar()
        }}
        onKeyDown={(e) => {
          if (e.key === 'Enter') {
            e.preventDefault()
            ;(e.target as HTMLInputElement).blur()
          }
        }}
        error={invalido}
        sx={{
          width: 96,
          '& .MuiInputBase-root': { height: 30 },
        }}
      />
    </Box>
  )
}

/** Resumo de estado Kapps (único conteúdo do expand em Em Picking / Em Separação). */
export function KappsPickingPanel({
  loading,
  erro,
  data,
  podeEditarQuantidade = false,
  variante = 'picking',
  onNotify,
  onQuantidadeAlterada,
}: Props) {
  const colQtd =
    variante === 'separacao'
      ? labels.pickingKappsQuantidadeSeparacao
      : labels.pickingKappsQuantidade
  const colRecolhido =
    variante === 'separacao'
      ? labels.pickingKappsRecolhidoSeparacao
      : labels.pickingKappsRecolhido
  const colPendente =
    variante === 'separacao'
      ? labels.pickingKappsPendenteSeparacao
      : labels.pickingKappsPendente

  // Sem picking Kapps (204): nada no expand — o badge da lista já indica «Em espera».
  if (!loading && !erro && (data === null || data === undefined)) {
    return null
  }

  return (
    <Box sx={{ px: 0.5 }}>
      {loading && (
        <Box display="flex" alignItems="center" gap={1} py={1}>
          <CircularProgress size={18} />
          <Typography variant="body2" color="text.secondary">
            {labels.pickingKappsACarregar}
          </Typography>
        </Box>
      )}

      {!loading && erro && (
        <Alert severity="error" sx={{ py: 0.5 }}>
          {erro}
        </Alert>
      )}

      {!loading && !erro && data && (
        <PortalTableScroll>
        <Table size="small" sx={linhasTableSx}>
          <colgroup>
            <col style={{ width: '14%' }} />
            <col style={{ width: '38%' }} />
            <col style={{ width: '16%' }} />
            <col style={{ width: '16%' }} />
            <col style={{ width: '16%' }} />
          </colgroup>
          <TableHead>
            <TableRow>
              <TableCell>Artigo</TableCell>
              <TableCell>Descrição</TableCell>
              <TableCell align="right">{colQtd}</TableCell>
              <TableCell align="right">{colRecolhido}</TableCell>
              <TableCell align="right">{colPendente}</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {data.lines.length === 0 ? (
              <TableRow>
                <TableCell colSpan={5}>
                  <Typography variant="body2" color="text.secondary">
                    Sem linhas no picking Kapps.
                  </Typography>
                </TableCell>
              </TableRow>
            ) : (
              data.lines.map((l) => (
                <TableRow key={l.pickingLineKey}>
                  <TableCell>{l.article}</TableCell>
                  <TableCell>{l.description}</TableCell>
                  <TableCell align="right" sx={{ fontVariantNumeric: 'tabular-nums' }}>
                    <KappsQuantidadeCell
                      linha={l}
                      readOnly={!podeEditarQuantidade}
                      onNotify={onNotify}
                      onSaved={(quantidade) =>
                        onQuantidadeAlterada?.(l.pickingLineKey, quantidade)
                      }
                    />
                  </TableCell>
                  <TableCell align="right" sx={{ fontVariantNumeric: 'tabular-nums' }}>
                    {fmtQty(kappsRecolhidoLinha(l))}
                  </TableCell>
                  <TableCell align="right" sx={{ fontVariantNumeric: 'tabular-nums' }}>
                    {fmtQty(kappsPendenteLinha(l))}
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
        </PortalTableScroll>
      )}
    </Box>
  )
}

import { useEffect, useRef, useState } from 'react'
import { Box, TextField } from '@mui/material'
import { api, type EncomendaLinha, type LinhaAtualizada } from '../../shared/api'
import type { GravacaoSnack } from './GravacaoSnackbar'

function applyLinhaUpdate(linha: EncomendaLinha, res: LinhaAtualizada): EncomendaLinha {
  const qtt = res.quantidade
  const original = res.quantidadeOriginalPortal
  return {
    ...linha,
    quantidade: qtt,
    qtt,
    quantidadeOriginalPortal: original,
    quantidadePorSatisfazer: Math.max(0, original - linha.qtt2),
    precoUnitario: res.precoUnitario,
    precoUnitarioOriginal: res.precoUnitarioOriginal,
    usrinis: res.usrinis,
    usrdata: res.usrdata,
    usrhora: res.usrhora,
  }
}

/** Edição de quantidade actual (qtt) — RN-020. */
export function LinhaQuantidadeCell({
  linha,
  onSaved,
  onNotify,
  readOnly = false,
}: {
  linha: EncomendaLinha
  onSaved: (next: EncomendaLinha) => void
  onNotify?: (snack: GravacaoSnack) => void
  readOnly?: boolean
}) {
  const [valor, setValor] = useState(String(linha.qtt))
  const [saving, setSaving] = useState(false)
  const [invalido, setInvalido] = useState(false)
  const dirtyRef = useRef(false)
  const focusedRef = useRef(false)

  useEffect(() => {
    // Se a 1.ª autorização (ou outro fluxo) alterou qtt, sincronizar o input
    // sem gravar o valor antigo que ainda estava no estado local.
    if (focusedRef.current || dirtyRef.current || saving) return
    setValor(String(linha.qtt))
    setInvalido(false)
  }, [linha.biStamp, linha.qtt, saving])

  async function gravar() {
    if (readOnly || saving) return

    if (!dirtyRef.current) {
      setValor(String(linha.qtt))
      setInvalido(false)
      return
    }

    const raw = String(valor).trim()
    if (raw === '') {
      setInvalido(true)
      onNotify?.({ message: 'Valor inválido na quantidade.', severity: 'error' })
      setValor(String(linha.qtt))
      dirtyRef.current = false
      return
    }

    const parsed = Number(raw.replace(',', '.'))
    if (Number.isNaN(parsed) || parsed < 0) {
      setInvalido(true)
      onNotify?.({ message: 'Valor inválido na quantidade.', severity: 'error' })
      setValor(String(linha.qtt))
      dirtyRef.current = false
      return
    }
    if (parsed === linha.qtt) {
      dirtyRef.current = false
      setInvalido(false)
      return
    }

    setSaving(true)
    setInvalido(false)
    try {
      const res = await api.atualizarLinha(linha.biStamp, {
        quantidade: parsed,
        quantidadeAnteriorEsperada: linha.qtt,
      })
      dirtyRef.current = false
      onSaved(applyLinhaUpdate(linha, res))
      setValor(String(res.quantidade))
      onNotify?.({ message: 'Quantidade actualizada.', severity: 'success' })
    } catch (e) {
      setInvalido(true)
      onNotify?.({
        message: e instanceof Error ? e.message : 'Falha ao gravar quantidade.',
        severity: 'error',
      })
      setValor(String(linha.qtt))
      dirtyRef.current = false
    } finally {
      setSaving(false)
    }
  }

  return (
    <Box
      onClick={(e) => e.stopPropagation()}
      sx={{
        width: '100%',
        display: 'flex',
        justifyContent: 'center',
      }}
    >
      <TextField
        size="small"
        type="number"
        value={valor}
        disabled={readOnly || saving}
        inputProps={{
          min: 0,
          step: 'any',
          readOnly,
          style: { textAlign: 'right', padding: '4px 6px' },
        }}
        onFocus={() => {
          if (readOnly) return
          focusedRef.current = true
        }}
        onChange={(e) => {
          if (readOnly) return
          dirtyRef.current = true
          setValor(e.target.value)
          setInvalido(false)
        }}
        onBlur={() => {
          if (readOnly) return
          focusedRef.current = false
          void gravar()
        }}
        onKeyDown={(e) => {
          if (readOnly) return
          if (e.key === 'Enter') {
            e.preventDefault()
            ;(e.target as HTMLInputElement).blur()
          }
        }}
        error={invalido}
        sx={{
          width: '100%',
          '& .MuiInputBase-root': { height: 30 },
        }}
      />
    </Box>
  )
}

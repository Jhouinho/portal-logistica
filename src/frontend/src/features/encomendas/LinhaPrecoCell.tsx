import { useEffect, useState } from 'react'
import { Box, TextField } from '@mui/material'
import { api, type EncomendaLinha, type LinhaAtualizada } from '../../shared/api'
import { moneyInputValue } from '../../shared/format'
import type { GravacaoSnack } from './GravacaoSnackbar'

function applyLinhaUpdate(linha: EncomendaLinha, res: LinhaAtualizada): EncomendaLinha {
  return {
    ...linha,
    quantidade: res.quantidade,
    qtt: res.quantidade,
    quantidadeOriginalPortal: res.quantidadeOriginalPortal,
    precoUnitario: res.precoUnitario,
    precoUnitarioOriginal: res.precoUnitarioOriginal,
    usrinis: res.usrinis,
    usrdata: res.usrdata,
    usrhora: res.usrhora,
  }
}

/** Edição de preço unitário (RN-021). Quantidade (qtt) não é editável no UI. */
export function LinhaPrecoCell({
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
  const [valor, setValor] = useState(moneyInputValue(linha.precoUnitario))
  const [saving, setSaving] = useState(false)
  const [invalido, setInvalido] = useState(false)

  useEffect(() => {
    setValor(moneyInputValue(linha.precoUnitario))
    setInvalido(false)
  }, [linha.biStamp, linha.precoUnitario])

  async function gravar() {
    const parsed = Number(String(valor).replace(',', '.'))
    if (Number.isNaN(parsed) || parsed < 0) {
      setInvalido(true)
      onNotify?.({ message: 'Valor inválido no preço.', severity: 'error' })
      setValor(moneyInputValue(linha.precoUnitario))
      return
    }
    const arredondado = Math.round(parsed * 100) / 100
    if (arredondado === linha.precoUnitario) {
      setValor(moneyInputValue(linha.precoUnitario))
      setInvalido(false)
      return
    }

    setSaving(true)
    setInvalido(false)
    try {
      const res = await api.atualizarLinha(linha.biStamp, {
        precoUnitario: arredondado,
        precoAnteriorEsperado: linha.precoUnitario,
      })
      onSaved(applyLinhaUpdate(linha, res))
      setValor(moneyInputValue(res.precoUnitario))
      onNotify?.({ message: 'Preço actualizado.', severity: 'success' })
    } catch (e) {
      setInvalido(true)
      onNotify?.({
        message: e instanceof Error ? e.message : 'Falha ao gravar preço.',
        severity: 'error',
      })
      setValor(moneyInputValue(linha.precoUnitario))
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
          step: '0.01',
          readOnly,
          style: { textAlign: 'right', padding: '4px 6px' },
        }}
        onChange={(e) => {
          if (readOnly) return
          setValor(e.target.value)
          setInvalido(false)
        }}
        onBlur={() => {
          if (readOnly) return
          const parsed = Number(String(valor).replace(',', '.'))
          if (!Number.isNaN(parsed) && parsed >= 0)
            setValor(moneyInputValue(parsed))
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

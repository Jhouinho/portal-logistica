import { useEffect, useRef, useState } from 'react'
import { Box, TextField } from '@mui/material'
import { api, type EncomendaLinha } from '../../shared/api'
import type { GravacaoSnack } from './GravacaoSnackbar'

/**
 * Quantidade usada na UI quando ainda não há autorização gravada (0):
 * sugere a quantidade pedida (por satisfazer). Mesma regra do valor do input.
 */
export function quantidadeAutorizadaEfectiva(linha: {
  quantidadeAutorizada: number
  quantidadePorSatisfazer: number
}): number {
  if (linha.quantidadeAutorizada === 0) {
    return linha.quantidadePorSatisfazer
  }
  return linha.quantidadeAutorizada
}

/** Valor apresentado: se ainda sem autorização (0), sugere a quantidade pedida (por satisfazer). */
function valorExibido(linha: EncomendaLinha): string {
  return String(quantidadeAutorizadaEfectiva(linha))
}

/** Total de linha = qtt autorizada efectiva × preço unitário. */
export function totalLinhaAutorizada(linha: {
  quantidadeAutorizada: number
  quantidadePorSatisfazer: number
  precoUnitario: number
}): number {
  return quantidadeAutorizadaEfectiva(linha) * linha.precoUnitario
}

function chaveRefCor(ref: string, cor: string): string {
  return `${(ref ?? '').trim().toUpperCase()}|${(cor ?? '').trim().toUpperCase()}`
}

/**
 * Disponível previsto ajustado às quantidades autorizadas **efectivas** (inclui sugestão
 * quando `u_qtdaut=0` ainda não foi gravada). O valor do servidor já desconta só o alocado
 * gravado; aqui subtrai-se o delta desta encomenda para o mesmo Ref+Cor.
 *
 * @param baselineAut mapa biStamp → u_qtdaut no servidor (lista com rascunho); se omitido,
 *   usa `quantidadeAutorizada` de cada linha como baseline.
 */
export function stockDisponivelComSugestao(
  linha: EncomendaLinha,
  linhasEncomenda: EncomendaLinha[],
  baselineAut?: Record<string, number>,
): number {
  const chave = chaveRefCor(linha.ref, linha.cor)
  let delta = 0
  for (const m of linhasEncomenda) {
    if (chaveRefCor(m.ref, m.cor) !== chave) continue
    const serverAut = baselineAut?.[m.biStamp] ?? m.quantidadeAutorizada
    const efectiva = quantidadeAutorizadaEfectiva(m)
    delta += efectiva - serverAut
  }
  return linha.stockDisponivel - delta
}

/** Soma das autorizadas efectivas (com sugestão quando ainda a 0). */
export function quantidadeAutorizadaTotalEfectiva(
  linhas: Array<{
    quantidadeAutorizada: number
    quantidadePorSatisfazer: number
  }>,
): number {
  return linhas.reduce((s, l) => s + quantidadeAutorizadaEfectiva(l), 0)
}

export function QuantidadeAutorizadaCell({
  linha,
  onSaved,
  onNotify,
  readOnly = false,
  /** Só actualiza o valor local; não chama a API até o ecrã gravar. */
  deferSave = false,
  onDraftChange,
}: {
  linha: EncomendaLinha
  onSaved: (next: EncomendaLinha) => void
  onNotify?: (snack: GravacaoSnack) => void
  readOnly?: boolean
  deferSave?: boolean
  onDraftChange?: (next: EncomendaLinha) => void
}) {
  const [valor, setValor] = useState(() => valorExibido(linha))
  const [saving, setSaving] = useState(false)
  const [invalido, setInvalido] = useState(false)
  const dirtyRef = useRef(false)
  const focusedRef = useRef(false)

  useEffect(() => {
    if (focusedRef.current || dirtyRef.current || saving) return
    setValor(valorExibido(linha))
    setInvalido(false)
  }, [
    linha.biStamp,
    linha.quantidadeAutorizada,
    linha.quantidadePorSatisfazer,
    saving,
  ])

  function aplicarDraft(parsed: number) {
    dirtyRef.current = false
    setInvalido(false)
    setValor(String(parsed))
    onDraftChange?.({
      ...linha,
      quantidadeAutorizada: parsed,
    })
  }

  async function gravarComValor(parsed: number) {
    if (saving) return false
    if (deferSave) {
      aplicarDraft(parsed)
      return true
    }
    setSaving(true)
    setInvalido(false)
    try {
      const res = await api.atualizarQuantidadeAutorizada(linha.biStamp, {
        quantidadeAutorizada: parsed,
        valorAnteriorEsperado: linha.quantidadeAutorizada,
        permitirAcimaStock: false,
      })
      dirtyRef.current = false
      onSaved({
        ...linha,
        quantidadeAutorizada: res.quantidadeAutorizada,
        autorizadaPor: res.autorizadaPor,
        autorizadaEm: res.autorizadaEm,
        quantidade: res.quantidade,
        qtt: res.quantidade,
        quantidadeOriginalPortal: res.quantidadeOriginalPortal,
        quantidadePorSatisfazer: res.quantidadePorSatisfazer,
        // Disponível previsto após esta linha (pode ser negativo — PR3-C).
        stockDisponivel:
          linha.stockDisponivel + linha.quantidadeAutorizada - res.quantidadeAutorizada,
      })
      setValor(String(res.quantidadeAutorizada))
      onNotify?.({ message: 'Quantidade autorizada actualizada.', severity: 'success' })
      return true
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Falha ao gravar quantidade autorizada.'
      setInvalido(true)
      onNotify?.({ message: msg, severity: 'error' })
      setValor(valorExibido(linha))
      dirtyRef.current = false
      return false
    } finally {
      setSaving(false)
    }
  }

  async function gravar() {
    if (saving) return
    if (!dirtyRef.current) {
      setValor(valorExibido(linha))
      setInvalido(false)
      return
    }

    const raw = String(valor).trim()
    if (raw === '') {
      setInvalido(true)
      onNotify?.({ message: 'Valor inválido na quantidade autorizada.', severity: 'error' })
      setValor(valorExibido(linha))
      dirtyRef.current = false
      return
    }

    const parsed = Number(raw.replace(',', '.'))
    if (Number.isNaN(parsed) || parsed < 0) {
      setInvalido(true)
      onNotify?.({ message: 'Valor inválido na quantidade autorizada.', severity: 'error' })
      setValor(valorExibido(linha))
      dirtyRef.current = false
      return
    }

    if (parsed === linha.quantidadeAutorizada) {
      dirtyRef.current = false
      setInvalido(false)
      setValor(valorExibido(linha))
      return
    }

    // PR3-C: sem teto de previsão na UI — o servidor aceita acima do Disponível.
    await gravarComValor(parsed)
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

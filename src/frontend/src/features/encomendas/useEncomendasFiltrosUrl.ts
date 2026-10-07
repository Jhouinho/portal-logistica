import { useCallback, useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'

/** Chaves partilhadas entre vista por encomenda e por referência. */
export const filtroKeys = {
  dataDe: 'dataDe',
  dataAte: 'dataAte',
  horaDe: 'horaDe',
  horaAte: 'horaAte',
  cliente: 'cliente',
  artigo: 'artigo',
  cor: 'cor',
  estado: 'estado',
  pickStatus: 'pickStatus',
  metodoExpedicao: 'metodoExpedicao',
} as const

export type FiltroKey = (typeof filtroKeys)[keyof typeof filtroKeys]

function useDebouncedValue<T>(value: T, delayMs: number): T {
  const [debounced, setDebounced] = useState(value)
  useEffect(() => {
    const id = window.setTimeout(() => setDebounced(value), delayMs)
    return () => window.clearTimeout(id)
  }, [value, delayMs])
  return debounced
}

function isDefaultSelect(key: string, value: string): boolean {
  return (
    ((key === filtroKeys.estado || key === filtroKeys.pickStatus) && value === 'Todos') ||
    (key === filtroKeys.metodoExpedicao && (value === 'todos' || value === 'Todos'))
  )
}

function patchParams(prev: URLSearchParams, key: string, value: string): URLSearchParams {
  const next = new URLSearchParams(prev)
  if (isDefaultSelect(key, value) || !value) {
    next.delete(key)
  } else {
    next.set(key, value)
  }
  return next
}

/**
 * Filtros de encomendas sincronizados com a query string —
 * mantêm-se ao alternar Por encomenda / Por referência.
 * Texto: grava de imediato na URL; a API usa valor com debounce.
 * Datas: vazias por omissão (sem intervalo automático).
 */
export function useEncomendasFiltrosUrl() {
  const [searchParams, setSearchParams] = useSearchParams()

  const fromUrl = useMemo(
    () => ({
      dataDe: searchParams.get(filtroKeys.dataDe) ?? '',
      dataAte: searchParams.get(filtroKeys.dataAte) ?? '',
      horaDe: searchParams.get(filtroKeys.horaDe) ?? '',
      horaAte: searchParams.get(filtroKeys.horaAte) ?? '',
      cliente: searchParams.get(filtroKeys.cliente) ?? '',
      artigo: searchParams.get(filtroKeys.artigo) ?? '',
      cor: searchParams.get(filtroKeys.cor) ?? '',
      estado: searchParams.get(filtroKeys.estado) ?? 'Todos',
      pickStatus: searchParams.get(filtroKeys.pickStatus) ?? 'Todos',
      metodoExpedicao: searchParams.get(filtroKeys.metodoExpedicao) ?? 'todos',
    }),
    [searchParams],
  )

  const setUrlFiltro = useCallback(
    (key: FiltroKey, value: string) => {
      setSearchParams((prev) => {
        const cur =
          key === filtroKeys.estado || key === filtroKeys.pickStatus
            ? (prev.get(key) ?? 'Todos')
            : key === filtroKeys.metodoExpedicao
              ? (prev.get(key) ?? 'todos')
              : (prev.get(key) ?? '')
        if (cur === value) return prev
        if (isDefaultSelect(key, value) && !prev.has(key)) {
          return prev
        }
        if (
          !value &&
          !prev.has(key) &&
          key !== filtroKeys.estado &&
          key !== filtroKeys.pickStatus &&
          key !== filtroKeys.metodoExpedicao
        ) {
          return prev
        }
        return patchParams(prev, key, value)
      }, { replace: true })
    },
    [setSearchParams],
  )

  const [clienteNo, setClienteNoState] = useState(fromUrl.cliente)
  const [artigoInput, setArtigoInputState] = useState(fromUrl.artigo)
  const [corInput, setCorInputState] = useState(fromUrl.cor)

  useEffect(() => setClienteNoState(fromUrl.cliente), [fromUrl.cliente])
  useEffect(() => setArtigoInputState(fromUrl.artigo), [fromUrl.artigo])
  useEffect(() => setCorInputState(fromUrl.cor), [fromUrl.cor])

  const setClienteNo = useCallback(
    (v: string) => {
      setClienteNoState(v)
      setUrlFiltro(filtroKeys.cliente, v.trim())
    },
    [setUrlFiltro],
  )
  const setArtigoInput = useCallback(
    (v: string) => {
      setArtigoInputState(v)
      setUrlFiltro(filtroKeys.artigo, v.trim())
    },
    [setUrlFiltro],
  )
  const setCorInput = useCallback(
    (v: string) => {
      setCorInputState(v)
      setUrlFiltro(filtroKeys.cor, v.trim())
    },
    [setUrlFiltro],
  )

  const clienteDebounced = useDebouncedValue(clienteNo.trim(), 300)
  const artigoDebounced = useDebouncedValue(artigoInput.trim(), 300)
  const corDebounced = useDebouncedValue(corInput.trim(), 300)

  return {
    dataDe: fromUrl.dataDe,
    setDataDe: (v: string) => setUrlFiltro(filtroKeys.dataDe, v),
    dataAte: fromUrl.dataAte,
    setDataAte: (v: string) => setUrlFiltro(filtroKeys.dataAte, v),
    horaDe: fromUrl.horaDe,
    setHoraDe: (v: string) => setUrlFiltro(filtroKeys.horaDe, v),
    horaAte: fromUrl.horaAte,
    setHoraAte: (v: string) => setUrlFiltro(filtroKeys.horaAte, v),
    clienteNo,
    setClienteNo,
    clienteDebounced,
    artigoInput,
    setArtigoInput,
    artigoDebounced,
    corInput,
    setCorInput,
    corDebounced,
    estado: fromUrl.estado,
    setEstado: (v: string) => setUrlFiltro(filtroKeys.estado, v),
    pickStatus: fromUrl.pickStatus,
    setPickStatus: (v: string) => setUrlFiltro(filtroKeys.pickStatus, v),
    metodoExpedicao: fromUrl.metodoExpedicao,
    setMetodoExpedicao: (v: string) => setUrlFiltro(filtroKeys.metodoExpedicao, v),
    temFiltroArtigo: !!(artigoDebounced || corDebounced),
  }
}

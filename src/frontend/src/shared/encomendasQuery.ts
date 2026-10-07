import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useCallback } from 'react'
import { api, type EncomendaListaResponse } from './api'

/** Prefixo estável — invalidate atinge todas as páginas/filtros da lista abertas. */
export const encomendasAbertasListaQueryKeyRoot = ['encomendas-lista', 'abertas'] as const

/** Parâmetros que alteram o resultado de GET /encomendas/abertas. */
export type EncomendasAbertasListaParams = {
  dataDe?: string
  dataAte?: string
  horaDe?: string
  horaAte?: string
  clienteNoContem?: string
  artigoRef?: string
  artigoCor?: string
  estadoPlaneamento?: string
  metodoExpedicao?: string
  /** false = Encomendas; true = Picking (separa as query keys). */
  prontaPicking: boolean
  pickStatus?: number
  page: number
  pageSize: number
}

export function encomendasAbertasListaQueryKey(params: EncomendasAbertasListaParams) {
  return [...encomendasAbertasListaQueryKeyRoot, params] as const
}

type UseEncomendasAbertasListaOptions = {
  enabled?: boolean
}

/**
 * Lista GET /encomendas/abertas (Encomendas `prontaPicking=false` ou Picking `=true`).
 * POC1/POC2 — não cobre dossiers.
 */
export function useEncomendasAbertasListaQuery(
  params: EncomendasAbertasListaParams,
  options: UseEncomendasAbertasListaOptions = {},
) {
  const { enabled = true } = options

  return useQuery<EncomendaListaResponse>({
    queryKey: encomendasAbertasListaQueryKey(params),
    queryFn: () =>
      api.encomendasAbertas({
        dataDe: params.dataDe,
        dataAte: params.dataAte,
        horaDe: params.horaDe,
        horaAte: params.horaAte,
        clienteNoContem: params.clienteNoContem,
        artigoRef: params.artigoRef,
        artigoCor: params.artigoCor,
        estadoPlaneamento: params.estadoPlaneamento,
        metodoExpedicao: params.metodoExpedicao,
        prontaPicking: params.prontaPicking,
        pickStatus: params.pickStatus,
        page: params.page,
        pageSize: params.pageSize,
      }),
    enabled,
  })
}

/** SignalR `encomendaAlterada` → refetch listas abertas (Encomendas e/ou Picking). */
export function useInvalidateEncomendasAbertasLista() {
  const queryClient = useQueryClient()
  return useCallback(
    () =>
      queryClient.invalidateQueries({
        queryKey: [...encomendasAbertasListaQueryKeyRoot],
      }),
    [queryClient],
  )
}

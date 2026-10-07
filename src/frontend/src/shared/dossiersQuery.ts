import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useCallback } from 'react'
import { api, type EncomendaListaResponse } from './api'

/** Prefixo — invalidate atinge todas as páginas/filtros de dossiers 66. */
export const dossiers66ListaQueryKeyRoot = ['dossiers-lista', '66'] as const

/** Prefixo — invalidate atinge todas as páginas/filtros de dossiers 65. */
export const dossiers65ListaQueryKeyRoot = ['dossiers-lista', '65'] as const

/** Params GET /picking-dossiers (ndos=66). */
export type Dossiers66ListaParams = {
  fechada?: boolean
  checkIn?: boolean
  dataDe?: string
  dataAte?: string
  horaDe?: string
  horaAte?: string
  clienteNoContem?: string
  artigoRef?: string
  artigoCor?: string
  estadoPlaneamento?: string
  metodoExpedicao?: string
  pickStatus?: number
  page: number
  pageSize: number
}

/** Params GET /separacao-dossiers (ndos=65). */
export type Dossiers65ListaParams = {
  fechada?: boolean
  dataDe?: string
  dataAte?: string
  horaDe?: string
  horaAte?: string
  clienteNoContem?: string
  artigoRef?: string
  artigoCor?: string
  estadoPlaneamento?: string
  metodoExpedicao?: string
  page: number
  pageSize: number
}

export function dossiers66ListaQueryKey(params: Dossiers66ListaParams) {
  return [...dossiers66ListaQueryKeyRoot, params] as const
}

export function dossiers65ListaQueryKey(params: Dossiers65ListaParams) {
  return [...dossiers65ListaQueryKeyRoot, params] as const
}

type UseDossiersListaOptions = {
  enabled?: boolean
}

/**
 * Lista GET /picking-dossiers (Separado checkIn=false | Em Entrega checkIn=true).
 * POC3 — Kapps / linhas / mutations fora de âmbito.
 */
export function useDossiers66ListaQuery(
  params: Dossiers66ListaParams,
  options: UseDossiersListaOptions = {},
) {
  const { enabled = true } = options

  return useQuery<EncomendaListaResponse>({
    queryKey: dossiers66ListaQueryKey(params),
    queryFn: () =>
      api.pickingDossiers({
        fechada: params.fechada,
        checkIn: params.checkIn,
        dataDe: params.dataDe,
        dataAte: params.dataAte,
        horaDe: params.horaDe,
        horaAte: params.horaAte,
        clienteNoContem: params.clienteNoContem,
        artigoRef: params.artigoRef,
        artigoCor: params.artigoCor,
        estadoPlaneamento: params.estadoPlaneamento,
        metodoExpedicao: params.metodoExpedicao,
        pickStatus: params.pickStatus,
        page: params.page,
        pageSize: params.pageSize,
      }),
    enabled,
  })
}

/**
 * Lista GET /separacao-dossiers (Expedido / Já separados / Concluídas).
 * POC3 — linhas / mutations fora de âmbito.
 */
export function useDossiers65ListaQuery(
  params: Dossiers65ListaParams,
  options: UseDossiersListaOptions = {},
) {
  const { enabled = true } = options

  return useQuery<EncomendaListaResponse>({
    queryKey: dossiers65ListaQueryKey(params),
    queryFn: () =>
      api.separacaoDossiers({
        fechada: params.fechada,
        dataDe: params.dataDe,
        dataAte: params.dataAte,
        horaDe: params.horaDe,
        horaAte: params.horaAte,
        clienteNoContem: params.clienteNoContem,
        artigoRef: params.artigoRef,
        artigoCor: params.artigoCor,
        estadoPlaneamento: params.estadoPlaneamento,
        metodoExpedicao: params.metodoExpedicao,
        page: params.page,
        pageSize: params.pageSize,
      }),
    enabled,
  })
}

/** SignalR `dossier66Alterado` → refetch listas 66 activas. */
export function useInvalidateDossiers66Lista() {
  const queryClient = useQueryClient()
  return useCallback(
    () =>
      queryClient.invalidateQueries({
        queryKey: [...dossiers66ListaQueryKeyRoot],
      }),
    [queryClient],
  )
}

/** SignalR `dossier65Alterado` → refetch listas 65 activas. */
export function useInvalidateDossiers65Lista() {
  const queryClient = useQueryClient()
  return useCallback(
    () =>
      queryClient.invalidateQueries({
        queryKey: [...dossiers65ListaQueryKeyRoot],
      }),
    [queryClient],
  )
}

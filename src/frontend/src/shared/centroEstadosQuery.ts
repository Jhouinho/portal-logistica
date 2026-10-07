import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useCallback } from 'react'
import { api, type CentroEstadosKpis } from './api'

/** Query key estável partilhada por AppShell e Centro de Operações. */
export const centroEstadosQueryKey = ['centro-estados'] as const

const REFETCH_MS = 30_000

type UseCentroEstadosOptions = {
  /** Se false, a query não corre (ex.: utilizador não autenticado no shell). */
  enabled?: boolean
}

/**
 * Server state: GET /api/v1/painel/centro-estados.
 * Cache partilhada + poll 30s (equivalente ao setInterval anterior no AppShell).
 */
export function useCentroEstadosQuery(options: UseCentroEstadosOptions = {}) {
  const { enabled = true } = options

  return useQuery<CentroEstadosKpis>({
    queryKey: centroEstadosQueryKey,
    queryFn: () => api.centroEstados(),
    enabled,
    refetchInterval: REFETCH_MS,
    // Alinhado ao poll: cache partilhada sem 2.º GET ao montar Centro se ainda fresca.
    // SignalR / invalidate / mudança de rota forçam refresh independentemente.
    staleTime: REFETCH_MS,
  })
}

/** Invalida (e refetch activo) a query centro-estados — usar a partir do SignalR / eventos. */
export function useInvalidateCentroEstados() {
  const queryClient = useQueryClient()
  return useCallback(
    () => queryClient.invalidateQueries({ queryKey: centroEstadosQueryKey }),
    [queryClient],
  )
}

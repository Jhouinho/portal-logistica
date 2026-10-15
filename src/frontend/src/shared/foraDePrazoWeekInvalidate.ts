import type { QueryClient } from '@tanstack/react-query'

/**
 * Prefixos das query keys React Query que expõem `foraDePrazo` nas listas.
 * Alinhado a `encomendasAbertasListaQueryKeyRoot` (`encomendas-lista` / `abertas`)
 * e `dossiers66|65ListaQueryKeyRoot` (`dossiers-lista` / `66|65`).
 *
 * Em TanStack Query v5, `invalidateQueries({ queryKey: prefix })` cobre todas as
 * queries cujo key começa por esse prefixo.
 */
export const FORA_DE_PRAZO_WEEK_QUERY_KEY_ROOTS = [
  ['encomendas-lista'],
  ['dossiers-lista'],
] as const

/** True se `queryKey` seria abrangida pela invalidação da passagem de semana. */
export function queryKeyCoveredByForaDePrazoWeekInvalidation(
  queryKey: readonly unknown[],
): boolean {
  if (!Array.isArray(queryKey) || queryKey.length === 0) return false
  const head = queryKey[0]
  return FORA_DE_PRAZO_WEEK_QUERY_KEY_ROOTS.some((root) => root[0] === head)
}

/** Invalida listas RQ com `foraDePrazo` (encomendas abertas + dossiers 66/65). */
export function invalidateForaDePrazoWeekQueries(qc: QueryClient): void {
  for (const root of FORA_DE_PRAZO_WEEK_QUERY_KEY_ROOTS) {
    void qc.invalidateQueries({ queryKey: [...root] })
  }
}

import { labels } from './i18n/labels'

/**
 * Opções do filtro «Método de Expedição».
 * `value` = texto canónico em BO3.u_modExp (excepto todos / nao_definido).
 * `label` = texto amigável na UI (pode diferir na ortografia, ex. acento).
 */
export const FILTRO_METODO_OPCOES = [
  { value: 'todos', label: () => labels.filtroMetodoTodos },
  { value: 'Levantamento em Armazem', label: () => 'Levantamento em Armazém' },
  { value: 'Transportadora', label: () => 'Transportadora' },
  { value: 'N/Viatura', label: () => 'N/Viatura' },
  { value: 'nao_definido', label: () => labels.filtroMetodoNaoDefinido },
] as const

export type FiltroMetodoExpedicao = (typeof FILTRO_METODO_OPCOES)[number]['value']

/** Match UI ↔ BO3.u_modExp (trim; nao_definido = vazio). */
export function coincideMetodoExpedicao(
  metodoExpedicao: string | null | undefined,
  filtro: string,
): boolean {
  if (!filtro || filtro === 'todos' || filtro === 'Todos') return true
  const v = metodoExpedicao?.trim() ?? ''
  if (filtro === 'nao_definido') return v === ''
  return v === filtro
}

/** Valor a enviar à API (omitir se Todos). */
export function metodoExpedicaoApiParam(
  filtro: string | undefined | null,
): string | undefined {
  if (!filtro || filtro === 'todos' || filtro === 'Todos') return undefined
  return filtro
}

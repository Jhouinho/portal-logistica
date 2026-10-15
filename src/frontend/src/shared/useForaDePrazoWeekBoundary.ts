import { useEffect, useRef } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import {
  FORA_DE_PRAZO_WEEK_BOUNDARY_EVENT,
  msAteProximaSegunda,
} from './foraDePrazoWeek'
import { invalidateForaDePrazoWeekQueries } from './foraDePrazoWeekInvalidate'

/**
 * Na passagem de semana (dom→seg Lisboa) invalida listas React Query que
 * expõem `foraDePrazo` e notifica ecrãs sem RQ (detalhe / check-in).
 */
export function useForaDePrazoWeekBoundaryInvalidation(enabled: boolean) {
  const qc = useQueryClient()
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    if (!enabled) return

    let cancelled = false

    const schedule = () => {
      if (timerRef.current != null) clearTimeout(timerRef.current)
      const wait = msAteProximaSegunda()
      timerRef.current = setTimeout(() => {
        if (cancelled) return
        invalidateForaDePrazoWeekQueries(qc)
        window.dispatchEvent(new Event(FORA_DE_PRAZO_WEEK_BOUNDARY_EVENT))
        schedule()
      }, wait)
    }

    schedule()
    return () => {
      cancelled = true
      if (timerRef.current != null) clearTimeout(timerRef.current)
    }
  }, [enabled, qc])
}

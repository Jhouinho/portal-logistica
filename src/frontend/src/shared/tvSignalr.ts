import { HubConnection, HubConnectionBuilder, LogLevel } from '@microsoft/signalr'
import { useEffect, useRef } from 'react'

const hubPath = '/hubs/tv'

/** Eventos de invalidação do hub TV público (sem payload). */
export const TvHubEvents = {
  Dossier66Alterado: 'dossier66Alterado',
  Dossier65Alterado: 'dossier65Alterado',
  KappsAlterado: 'kappsAlterado',
} as const

type TvHubHandlers = {
  onDossier66Alterado?: () => void
  onDossier65Alterado?: () => void
  onKappsAlterado?: () => void
}

/**
 * Ligação anónima ao hub TV (/hubs/tv).
 * Não partilha estado com useOperacoesHub; falha silenciosa se SignalR indisponível.
 */
export function useTvHub(enabled: boolean, handlers: TvHubHandlers = {}) {
  const handlersRef = useRef(handlers)
  handlersRef.current = handlers

  useEffect(() => {
    if (!enabled) return

    const base = import.meta.env.VITE_API_BASE ?? ''
    const connection: HubConnection = new HubConnectionBuilder()
      .withUrl(`${base}${hubPath}`, { withCredentials: false })
      .withAutomaticReconnect()
      .configureLogging(LogLevel.Warning)
      .build()

    connection.on(TvHubEvents.Dossier66Alterado, () => {
      handlersRef.current.onDossier66Alterado?.()
    })
    connection.on(TvHubEvents.Dossier65Alterado, () => {
      handlersRef.current.onDossier65Alterado?.()
    })
    connection.on(TvHubEvents.KappsAlterado, () => {
      handlersRef.current.onKappsAlterado?.()
    })

    void connection.start().catch(() => {
      /* TV continua com polling 30s */
    })

    return () => {
      connection.off(TvHubEvents.Dossier66Alterado)
      connection.off(TvHubEvents.Dossier65Alterado)
      connection.off(TvHubEvents.KappsAlterado)
      void connection.stop()
    }
  }, [enabled])
}

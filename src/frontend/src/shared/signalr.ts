import {
  createContext,
  createElement,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  type ReactNode,
} from 'react'
import { HubConnection, HubConnectionBuilder, LogLevel } from '@microsoft/signalr'

const hubPath = '/hubs/operacoes'

/** Nomes dos eventos SignalR do hub `/hubs/operacoes` (alinhados com OperacoesHubEvents no backend). */
export const OperacoesHubEvents = {
  EncomendaAlterada: 'encomendaAlterada',
  LinhaQuantidadePreco: 'linhaQuantidadePreco',
  QuantidadeAutorizada: 'quantidadeAutorizada',
  StockAlterado: 'stockAlterado',
  Dossier66Alterado: 'dossier66Alterado',
  Dossier65Alterado: 'dossier65Alterado',
  KappsAlterado: 'kappsAlterado',
} as const

export type OperacoesHubHandlers = {
  onEncomendaAlterada?: () => void
  onLinhaQuantidadePreco?: () => void
  onQuantidadeAutorizada?: () => void
  /** Invalidação universo ndos=66 (sem payload). */
  onDossier66Alterado?: () => void
  /** Invalidação universo ndos=65 (sem payload). */
  onDossier65Alterado?: () => void
  /** Invalidação Kapps (sem payload). */
  onKappsAlterado?: () => void
}

type ListenerKey =
  | 'onEncomendaAlterada'
  | 'onLinhaQuantidadePreco'
  | 'onQuantidadeAutorizada'
  | 'onDossier66Alterado'
  | 'onDossier65Alterado'
  | 'onKappsAlterado'

type SubscribeFn = (handlers: OperacoesHubHandlers) => () => void

const OperacoesHubSubscribeContext = createContext<SubscribeFn | null>(null)

/** Serializa start/stop entre remounts (StrictMode) para evitar 2 ligações activas. */
let connectionLifecycle: Promise<void> = Promise.resolve()

function emit(set: Set<() => void>) {
  for (const fn of set) {
    try {
      fn()
    } catch {
      /* consumidor não deve derrubar o hub */
    }
  }
}

/**
 * Uma única HubConnection a `/hubs/operacoes` para toda a árvore autenticada.
 * Não guarda server state — só transporte e distribuição de eventos.
 */
export function OperacoesHubProvider({ children }: { children: ReactNode }) {
  const listenersRef = useRef({
    onEncomendaAlterada: new Set<() => void>(),
    onLinhaQuantidadePreco: new Set<() => void>(),
    onQuantidadeAutorizada: new Set<() => void>(),
    onDossier66Alterado: new Set<() => void>(),
    onDossier65Alterado: new Set<() => void>(),
    onKappsAlterado: new Set<() => void>(),
  })

  const subscribe = useCallback<SubscribeFn>((handlers) => {
    const buckets = listenersRef.current
    const registered: { key: ListenerKey; fn: () => void }[] = []

    const add = (key: ListenerKey, fn: (() => void) | undefined) => {
      if (!fn) return
      buckets[key].add(fn)
      registered.push({ key, fn })
    }

    add('onEncomendaAlterada', handlers.onEncomendaAlterada)
    add('onLinhaQuantidadePreco', handlers.onLinhaQuantidadePreco)
    add('onQuantidadeAutorizada', handlers.onQuantidadeAutorizada)
    add('onDossier66Alterado', handlers.onDossier66Alterado)
    add('onDossier65Alterado', handlers.onDossier65Alterado)
    add('onKappsAlterado', handlers.onKappsAlterado)

    return () => {
      for (const { key, fn } of registered) {
        buckets[key].delete(fn)
      }
    }
  }, [])

  useEffect(() => {
    let cancelled = false
    let connection: HubConnection | null = null

    connectionLifecycle = connectionLifecycle.then(async () => {
      if (cancelled) return

      const base = import.meta.env.VITE_API_BASE ?? ''
      const conn = new HubConnectionBuilder()
        .withUrl(`${base}${hubPath}`, { withCredentials: true })
        .withAutomaticReconnect()
        .configureLogging(LogLevel.Warning)
        .build()

      const L = () => listenersRef.current

      // Fan-out preservado: linha/qtd → também dispara onEncomendaAlterada (comportamento anterior).
      conn.on(OperacoesHubEvents.EncomendaAlterada, () => {
        emit(L().onEncomendaAlterada)
      })
      conn.on(OperacoesHubEvents.LinhaQuantidadePreco, () => {
        emit(L().onLinhaQuantidadePreco)
        emit(L().onEncomendaAlterada)
      })
      conn.on(OperacoesHubEvents.QuantidadeAutorizada, () => {
        emit(L().onQuantidadeAutorizada)
        emit(L().onEncomendaAlterada)
      })
      conn.on(OperacoesHubEvents.Dossier66Alterado, () => {
        emit(L().onDossier66Alterado)
      })
      conn.on(OperacoesHubEvents.Dossier65Alterado, () => {
        emit(L().onDossier65Alterado)
      })
      conn.on(OperacoesHubEvents.KappsAlterado, () => {
        emit(L().onKappsAlterado)
      })
      // stockAlterado: intencionalmente não subscrito (fase posterior).

      connection = conn
      try {
        await conn.start()
      } catch {
        /* hub opcional — falha silenciosa se API offline */
      }

      if (cancelled) {
        try {
          conn.off(OperacoesHubEvents.EncomendaAlterada)
          conn.off(OperacoesHubEvents.LinhaQuantidadePreco)
          conn.off(OperacoesHubEvents.QuantidadeAutorizada)
          conn.off(OperacoesHubEvents.Dossier66Alterado)
          conn.off(OperacoesHubEvents.Dossier65Alterado)
          conn.off(OperacoesHubEvents.KappsAlterado)
          await conn.stop()
        } catch {
          /* ignore */
        }
        if (connection === conn) connection = null
      }
    })

    return () => {
      cancelled = true
      connectionLifecycle = connectionLifecycle.then(async () => {
        const conn = connection
        connection = null
        if (!conn) return
        try {
          conn.off(OperacoesHubEvents.EncomendaAlterada)
          conn.off(OperacoesHubEvents.LinhaQuantidadePreco)
          conn.off(OperacoesHubEvents.QuantidadeAutorizada)
          conn.off(OperacoesHubEvents.Dossier66Alterado)
          conn.off(OperacoesHubEvents.Dossier65Alterado)
          conn.off(OperacoesHubEvents.KappsAlterado)
          await conn.stop()
        } catch {
          /* ignore */
        }
      })
    }
  }, [])

  const value = useMemo(() => subscribe, [subscribe])

  return createElement(
    OperacoesHubSubscribeContext.Provider,
    { value },
    children,
  )
}

/**
 * Subscreve eventos do hub operacional partilhado (não cria HubConnection).
 * Mantém o nome `useOperacoesHub` para compatibilidade com os consumidores existentes.
 *
 * Preferência futura: alias `useOperacoesHubEvents`.
 */
export function useOperacoesHub(enabled: boolean, handlers: OperacoesHubHandlers = {}) {
  const subscribe = useContext(OperacoesHubSubscribeContext)
  const handlersRef = useRef(handlers)
  handlersRef.current = handlers

  useEffect(() => {
    if (!enabled || !subscribe) return

    // Wrappers estáveis: a ligação não se recria quando os handlers mudam.
    return subscribe({
      onEncomendaAlterada: () => handlersRef.current.onEncomendaAlterada?.(),
      onLinhaQuantidadePreco: () => handlersRef.current.onLinhaQuantidadePreco?.(),
      onQuantidadeAutorizada: () => handlersRef.current.onQuantidadeAutorizada?.(),
      onDossier66Alterado: () => handlersRef.current.onDossier66Alterado?.(),
      onDossier65Alterado: () => handlersRef.current.onDossier65Alterado?.(),
      onKappsAlterado: () => handlersRef.current.onKappsAlterado?.(),
    })
  }, [enabled, subscribe])
}

/** Alias explícito — mesma implementação que `useOperacoesHub`. */
export const useOperacoesHubEvents = useOperacoesHub

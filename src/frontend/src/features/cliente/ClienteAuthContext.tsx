import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import { clienteApi, type ClienteMe } from './clienteApi'

type State = {
  cliente: ClienteMe | null
  loading: boolean
  setCliente: (c: ClienteMe | null) => void
  refresh: () => Promise<void>
  logout: () => Promise<void>
}

const Ctx = createContext<State | null>(null)

export function ClienteAuthProvider({ children }: { children: ReactNode }) {
  const [cliente, setCliente] = useState<ClienteMe | null>(null)
  const [loading, setLoading] = useState(true)

  const refresh = useCallback(async () => {
    try {
      const me = await clienteApi.me()
      setCliente(me)
    } catch {
      setCliente(null)
    }
  }, [])

  useEffect(() => {
    refresh().finally(() => setLoading(false))
  }, [refresh])

  const logout = useCallback(async () => {
    try {
      await clienteApi.logout()
    } finally {
      setCliente(null)
    }
  }, [])

  const value = useMemo(
    () => ({ cliente, loading, setCliente, refresh, logout }),
    [cliente, loading, refresh, logout],
  )

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>
}

export function useClienteAuth() {
  const ctx = useContext(Ctx)
  if (!ctx) throw new Error('useClienteAuth fora de ClienteAuthProvider')
  return ctx
}

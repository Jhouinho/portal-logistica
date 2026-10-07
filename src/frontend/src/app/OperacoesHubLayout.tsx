import { Outlet } from 'react-router-dom'
import { OperacoesHubProvider } from '../shared/signalr'

/**
 * Layout autenticado: uma única HubConnection operacional para AppShell + páginas.
 * TV (/hubs/tv) fica fora desta árvore.
 */
export function OperacoesHubLayout() {
  return (
    <OperacoesHubProvider>
      <Outlet />
    </OperacoesHubProvider>
  )
}

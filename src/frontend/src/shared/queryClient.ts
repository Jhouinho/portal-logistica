import { QueryClient } from '@tanstack/react-query'

/** QueryClient único do portal (POC TanStack Query). */
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // POC: evitar refetch ao focar a janela (comportamento anterior não o fazia).
      refetchOnWindowFocus: false,
      retry: 1,
    },
  },
})

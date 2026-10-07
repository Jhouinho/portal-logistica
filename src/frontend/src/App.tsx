import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { CssBaseline, GlobalStyles } from '@mui/material'
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider'
import { AdapterDayjs } from '@mui/x-date-pickers/AdapterDayjs'
import 'dayjs/locale/pt'
import { ColorModeProvider, useColorMode } from './shared/ColorModeContext'
import { AuthProvider } from './features/autenticacao/AuthContext'
import { LoginPage } from './features/autenticacao/LoginPage'
import { DefinirPasswordPage } from './features/autenticacao/DefinirPasswordPage'
import { RequireAuth } from './app/RequireAuth'
import { RequireAdmin } from './app/RequireAdmin'
import { OperacoesHubLayout } from './app/OperacoesHubLayout'
import { AppShell } from './app/AppShell'
import { EncomendasHubPage } from './features/encomendas/EncomendasHubPage'
import { EncomendaDetailPage } from './features/encomendas/EncomendaDetailPage'
import { PickingPage } from './features/picking/PickingPage'
import { ExpedicaoPage } from './features/expedicao/ExpedicaoPage'
import { ConcluidasPage } from './features/concluidas/ConcluidasPage'
import { CortesQuantidadePage } from './features/cortes/CortesQuantidadePage'
import { PendentesPicagemHubPage } from './features/pendentes-picagem/PendentesPicagemHubPage'
import {
  AdministracaoLayout,
  AdminPrevisoesPage,
  AdminUtilizadoresPage,
} from './features/administracao/AdministracaoPage'
import { CentroOperacionalPage } from './features/centro/CentroOperacionalPage'
import { CentroTvPage } from './features/centro/CentroTvPage'
import { CheckInPage } from './features/checkin/CheckInPage'
import { EmEntregaPage } from './features/entrega/EmEntregaPage'
import { ExpedidoPage } from './features/expedido/ExpedidoPage'
import { getPortalScrollbarGlobalCss } from './features/centro/portalChrome'

/** Rotas do portal (cookie). A Vista TV fica fora — sem AuthProvider / sem login. */
function PortalRoutes() {
  return (
    <AuthProvider>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/definir-password" element={<DefinirPasswordPage />} />
        <Route element={<RequireAuth />}>
          <Route element={<OperacoesHubLayout />}>
            <Route element={<AppShell />}>
              <Route index element={<CentroOperacionalPage />} />
              <Route path="check-in" element={<CheckInPage />} />
              <Route path="em-entrega" element={<EmEntregaPage />} />
              <Route path="expedido" element={<ExpedidoPage />} />
              <Route path="encomendas" element={<EncomendasHubPage />} />
              <Route path="encomendas/:boStamp" element={<EncomendaDetailPage />} />
              <Route path="picking" element={<PickingPage />} />
              <Route path="expedicao" element={<ExpedicaoPage />} />
              <Route path="concluidas" element={<ConcluidasPage />} />
              <Route path="nao-entregues" element={<CortesQuantidadePage />} />
              <Route path="pendentes-picagem" element={<PendentesPicagemHubPage />} />
              <Route path="cortes" element={<Navigate to="/nao-entregues" replace />} />
              <Route path="artigos" element={<Navigate to="/encomendas?vista=referencia" replace />} />
              <Route element={<RequireAdmin />}>
                <Route path="administracao" element={<AdministracaoLayout />}>
                  <Route index element={<Navigate to="utilizadores" replace />} />
                  <Route path="utilizadores" element={<AdminUtilizadoresPage />} />
                  <Route path="previsoes" element={<AdminPrevisoesPage />} />
                </Route>
              </Route>
            </Route>
          </Route>
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AuthProvider>
  )
}

function AppChrome({ children }: { children: React.ReactNode }) {
  const { mode } = useColorMode()
  return (
    <>
      <CssBaseline />
      <GlobalStyles
        styles={{
          html: { height: '100%', overflow: 'hidden' },
          body: { height: '100%', overflow: 'hidden', margin: 0 },
          '#root': { height: '100%', overflow: 'hidden' },
          ...getPortalScrollbarGlobalCss(mode),
        }}
      />
      {children}
    </>
  )
}

export default function App() {
  return (
    <ColorModeProvider>
      <LocalizationProvider dateAdapter={AdapterDayjs} adapterLocale="pt">
        <AppChrome>
          <BrowserRouter>
            <Routes>
              {/* Links públicos de parede — sem credenciais */}
              <Route path="/tv" element={<CentroTvPage />} />
              <Route path="/centro-tv" element={<CentroTvPage />} />
              <Route path="/*" element={<PortalRoutes />} />
            </Routes>
          </BrowserRouter>
        </AppChrome>
      </LocalizationProvider>
    </ColorModeProvider>
  )
}

import { useEffect, useState, type ElementType } from 'react'
import {
  AppBar,
  Box,
  Button,
  Collapse,
  Drawer,
  IconButton,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Toolbar,
  Typography,
  useMediaQuery,
} from '@mui/material'
import { useTheme } from '@mui/material/styles'
import MenuIcon from '@mui/icons-material/Menu'
import HowToRegIcon from '@mui/icons-material/HowToReg'
import DashboardOutlinedIcon from '@mui/icons-material/DashboardOutlined'
import ReportProblemOutlinedIcon from '@mui/icons-material/ReportProblemOutlined'
import PendingActionsOutlinedIcon from '@mui/icons-material/PendingActionsOutlined'
import AdminPanelSettingsOutlinedIcon from '@mui/icons-material/AdminPanelSettingsOutlined'
import ExpandLessIcon from '@mui/icons-material/ExpandLess'
import ExpandMoreIcon from '@mui/icons-material/ExpandMore'
import PeopleOutlineIcon from '@mui/icons-material/PeopleOutline'
import Inventory2OutlinedIcon from '@mui/icons-material/Inventory2Outlined'
import TvOutlinedIcon from '@mui/icons-material/TvOutlined'
import { Link as RouterLink, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from '../features/autenticacao/AuthContext'
import { type CentroEstadosKpis } from '../shared/api'
import {
  useCentroEstadosQuery,
  useInvalidateCentroEstados,
} from '../shared/centroEstadosQuery'
import { labels } from '../shared/i18n/labels'
import { BrandLogo } from '../shared/ui/BrandLogo'
import { ColorModeToggle } from '../shared/ui/ColorModeToggle'
import { useOperacoesHub } from '../shared/signalr'
import { centroColors } from '../features/centro/centroUi'
import { etapaColors, hexToRgba, portalPrimaryCtaSx } from '../features/centro/portalChrome'

const drawerWidth = 280

type NavChild = {
  to: string
  label: string
  Icon?: ElementType
}

type NavItem = {
  to: string
  label: string
  etapa?: 1 | 2 | 3 | 4 | 5 | 6
  countKey?: keyof CentroEstadosKpis
  Icon?: ElementType
  children?: NavChild[]
}

const navBase: NavItem[] = [
  { to: '/', label: labels.painel, Icon: DashboardOutlinedIcon },
  { to: '/encomendas', label: labels.encomendas, etapa: 1, countKey: 'emAberto' },
  { to: '/picking', label: labels.picking, etapa: 2, countKey: 'emPicking' },
  { to: '/expedicao', label: labels.expedicao, etapa: 3, countKey: 'separado' },
  { to: '/em-entrega', label: labels.emEntrega, etapa: 4, countKey: 'emEntrega' },
  { to: '/expedido', label: labels.expedido, etapa: 5, countKey: 'expedido' },
  { to: '/concluidas', label: labels.concluidas, etapa: 6, countKey: 'concluidas' },
  {
    to: '/nao-entregues',
    label: labels.cortesQuantidade,
    Icon: ReportProblemOutlinedIcon,
  },
  {
    to: '/pendentes-picagem',
    label: labels.pendentesPicagemMenu,
    Icon: PendingActionsOutlinedIcon,
  },
]

const adminNavChildren: NavChild[] = [
  {
    to: '/administracao/previsoes',
    label: labels.adminPrevisoes,
    Icon: Inventory2OutlinedIcon,
  },
  {
    to: '/administracao/utilizadores',
    label: labels.adminUtilizadores,
    Icon: PeopleOutlineIcon,
  },
]

export function AppShell() {
  const theme = useTheme()
  const isDesktop = useMediaQuery(theme.breakpoints.up('md'))
  const [mobileOpen, setMobileOpen] = useState(false)
  const { utilizador, logout } = useAuth()
  const location = useLocation()
  const invalidateCentroEstados = useInvalidateCentroEstados()
  // Menu: falha da API não bloqueia navegação (data fica undefined / anterior).
  const { data: counts } = useCentroEstadosQuery({ enabled: !!utilizador })

  useOperacoesHub(!!utilizador, {
    onEncomendaAlterada: () => void invalidateCentroEstados(),
    onDossier66Alterado: () => void invalidateCentroEstados(),
    onDossier65Alterado: () => void invalidateCentroEstados(),
    // Único ponto SignalR → KPIs (evita dupla invalidate com o Centro).
    onKappsAlterado: () => void invalidateCentroEstados(),
  })

  useEffect(() => {
    const onRefresh = () => void invalidateCentroEstados()
    window.addEventListener('portal:contagens-refresh', onRefresh)
    return () => window.removeEventListener('portal:contagens-refresh', onRefresh)
  }, [invalidateCentroEstados])

  // Preservar refresh ao mudar de rota (comportamento anterior).
  useEffect(() => {
    if (!utilizador) return
    void invalidateCentroEstados()
  }, [location.pathname, utilizador, invalidateCentroEstados])

  useEffect(() => {
    setMobileOpen(false)
  }, [location.pathname])

  const [adminOpen, setAdminOpen] = useState(() =>
    location.pathname.startsWith('/administracao'),
  )

  useEffect(() => {
    if (location.pathname.startsWith('/administracao')) {
      setAdminOpen(true)
    }
  }, [location.pathname])

  const nav: NavItem[] = utilizador?.isAdmin
    ? [
        ...navBase,
        {
          to: '/administracao',
          label: labels.administracao,
          Icon: AdminPanelSettingsOutlinedIcon,
          children: adminNavChildren,
        },
      ]
    : navBase

  const checkInActive =
    location.pathname === '/check-in' || location.pathname.startsWith('/check-in/')

  const drawerContent = (
    <>
      <Toolbar />
      <Box px={1.5} pt={1.5} pb={0.5}>
        <Button
          component={RouterLink}
          to="/check-in"
          fullWidth
          variant="contained"
          startIcon={<HowToRegIcon />}
          sx={{
            ...portalPrimaryCtaSx,
            py: 1.15,
            fontSize: '0.85rem',
            bgcolor: checkInActive ? '#34c487' : centroColors.green,
            boxShadow: checkInActive
              ? '0 0 20px rgba(61,220,151,0.45)'
              : portalPrimaryCtaSx.boxShadow,
            border: checkInActive
              ? '2px solid rgba(255,255,255,0.35)'
              : '2px solid transparent',
          }}
        >
          {labels.checkIn}
        </Button>
      </Box>
      <List sx={{ px: 0.75, pb: 2 }}>
        {nav.map((item) => {
          const selected =
            item.to === '/'
              ? location.pathname === '/'
              : location.pathname === item.to ||
                location.pathname.startsWith(`${item.to}/`)
          const color = item.etapa != null ? etapaColors[item.etapa] : undefined
          const count =
            item.countKey && counts ? counts[item.countKey] : undefined
          const Icon = item.Icon
          const hasChildren = !!item.children?.length

          if (hasChildren) {
            return (
              <Box key={item.to} mb={0.25}>
                <ListItemButton
                  onClick={() => setAdminOpen((v) => !v)}
                  selected={selected}
                  sx={{ borderRadius: 1.25 }}
                >
                  {Icon ? (
                    <ListItemIcon sx={{ minWidth: 36, color: 'text.secondary' }}>
                      <Icon fontSize="small" />
                    </ListItemIcon>
                  ) : null}
                  <ListItemText
                    primary={item.label}
                    primaryTypographyProps={{ noWrap: true, fontWeight: 700 }}
                  />
                  {adminOpen ? (
                    <ExpandLessIcon fontSize="small" />
                  ) : (
                    <ExpandMoreIcon fontSize="small" />
                  )}
                </ListItemButton>
                <Collapse in={adminOpen} timeout="auto" unmountOnExit>
                  <List disablePadding>
                    {item.children!.map((child) => {
                      const childSelected =
                        location.pathname === child.to ||
                        location.pathname.startsWith(`${child.to}/`)
                      const ChildIcon = child.Icon
                      return (
                        <ListItemButton
                          key={child.to}
                          component={RouterLink}
                          to={child.to}
                          selected={childSelected}
                          sx={{
                            borderRadius: 1.25,
                            ml: 1.5,
                            pl: 1.5,
                            mb: 0.15,
                            minHeight: 40,
                          }}
                        >
                          {ChildIcon ? (
                            <ListItemIcon sx={{ minWidth: 32, color: 'text.secondary' }}>
                              <ChildIcon fontSize="small" />
                            </ListItemIcon>
                          ) : null}
                          <ListItemText
                            primary={child.label}
                            primaryTypographyProps={{
                              noWrap: true,
                              fontSize: '0.875rem',
                              fontWeight: childSelected ? 700 : 500,
                            }}
                          />
                        </ListItemButton>
                      )
                    })}
                  </List>
                </Collapse>
              </Box>
            )
          }

          return (
            <ListItemButton
              key={item.to}
              component={RouterLink}
              to={item.to}
              selected={selected}
              sx={
                color
                  ? {
                      mb: 0.35,
                      borderRadius: 1.25,
                      borderLeft: `3px solid ${color}`,
                      bgcolor: selected ? hexToRgba(color, 0.14) : 'transparent',
                      '&:hover': { bgcolor: hexToRgba(color, 0.1) },
                      '&.Mui-selected': {
                        bgcolor: hexToRgba(color, 0.16),
                        '&:hover': { bgcolor: hexToRgba(color, 0.2) },
                      },
                    }
                  : { borderRadius: 1.25, mb: 0.25 }
              }
            >
              {color && item.etapa != null ? (
                <Box display="flex" alignItems="center" gap={1} width="100%" minWidth={0}>
                  <Box
                    sx={{
                      width: 22,
                      height: 22,
                      borderRadius: '50%',
                      flexShrink: 0,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      bgcolor: hexToRgba(color, 0.14),
                      border: `1px solid ${hexToRgba(color, 0.45)}`,
                      color,
                      fontWeight: 800,
                      fontSize: '0.7rem',
                      fontVariantNumeric: 'tabular-nums',
                    }}
                  >
                    {item.etapa}
                  </Box>
                  <Typography
                    noWrap
                    fontWeight={700}
                    sx={{
                      fontSize: '0.9rem',
                      color: selected ? color : 'text.primary',
                      flex: 1,
                      minWidth: 0,
                    }}
                  >
                    {item.label}
                  </Typography>
                  {typeof count === 'number' ? (
                    <Typography
                      component="span"
                      fontWeight={800}
                      sx={{
                        fontSize: '0.8rem',
                        color,
                        fontVariantNumeric: 'tabular-nums',
                        flexShrink: 0,
                      }}
                    >
                      ({count})
                    </Typography>
                  ) : null}
                </Box>
              ) : (
                <>
                  {Icon ? (
                    <ListItemIcon sx={{ minWidth: 36, color: 'text.secondary' }}>
                      <Icon fontSize="small" />
                    </ListItemIcon>
                  ) : null}
                  <ListItemText
                    primary={item.label}
                    primaryTypographyProps={{ noWrap: true }}
                  />
                </>
              )}
            </ListItemButton>
          )
        })}
        <ListItemButton
          component={RouterLink}
          to="/tv"
          target="_blank"
          rel="noreferrer"
          sx={{ borderRadius: 1.25 }}
        >
          <ListItemIcon sx={{ minWidth: 36, color: 'text.secondary' }}>
            <TvOutlinedIcon fontSize="small" />
          </ListItemIcon>
          <ListItemText primary={labels.vistaTv} />
        </ListItemButton>
      </List>
    </>
  )

  return (
    <Box
      sx={{
        display: 'flex',
        height: '100vh',
        maxHeight: '100vh',
        width: '100%',
        overflow: 'hidden',
      }}
    >
      <AppBar
        position="fixed"
        sx={{
          zIndex: (t) => t.zIndex.drawer + 1,
          width: '100%',
        }}
      >
        <Toolbar sx={{ gap: 1, minWidth: 0 }}>
          {!isDesktop ? (
            <IconButton
              color="inherit"
              edge="start"
              aria-label="Abrir menu"
              onClick={() => setMobileOpen((v) => !v)}
              sx={{ flexShrink: 0 }}
            >
              <MenuIcon />
            </IconButton>
          ) : null}
          <Box
            component={RouterLink}
            to="/"
            sx={{
              flexGrow: 1,
              minWidth: 0,
              color: 'inherit',
              textDecoration: 'none',
              display: 'flex',
              alignItems: 'center',
              '&:hover': { opacity: 0.92 },
            }}
          >
            <BrandLogo
              height={isDesktop ? 36 : 28}
              withTitle={isDesktop}
              titleVariant="body2"
            />
          </Box>
          <Typography
            variant="body2"
            sx={{ mr: { xs: 0.5, sm: 1 }, display: { xs: 'none', sm: 'block' } }}
            noWrap
          >
            {utilizador?.nome}
          </Typography>
          <ColorModeToggle size="small" />
          <Button color="inherit" onClick={() => void logout()} sx={{ flexShrink: 0, px: { xs: 1, sm: 2 } }}>
            {labels.logout}
          </Button>
        </Toolbar>
      </AppBar>

      <Box
        component="nav"
        sx={{
          width: { md: drawerWidth },
          flexShrink: { md: 0 },
        }}
        aria-label="Navegação"
      >
        <Drawer
          variant="temporary"
          open={mobileOpen}
          onClose={() => setMobileOpen(false)}
          ModalProps={{ keepMounted: true }}
          sx={{
            display: { xs: 'block', md: 'none' },
            [`& .MuiDrawer-paper`]: {
              width: drawerWidth,
              boxSizing: 'border-box',
              maxWidth: '85vw',
            },
          }}
        >
          {drawerContent}
        </Drawer>
        <Drawer
          variant="permanent"
          open
          sx={{
            display: { xs: 'none', md: 'block' },
            width: drawerWidth,
            [`& .MuiDrawer-paper`]: {
              width: drawerWidth,
              boxSizing: 'border-box',
            },
          }}
        >
          {drawerContent}
        </Drawer>
      </Box>

      <Box
        component="main"
        sx={{
          flexGrow: 1,
          display: 'flex',
          flexDirection: 'column',
          height: '100vh',
          maxHeight: '100vh',
          width: {
            xs: '100%',
            md: `calc(100% - ${drawerWidth}px)`,
          },
          maxWidth: '100%',
          minWidth: 0,
          p: 0,
          overflow: 'hidden',
          boxSizing: 'border-box',
        }}
      >
        <Toolbar sx={{ flexShrink: 0 }} />
        <Box
          sx={{
            flex: 1,
            minHeight: 0,
            width: '100%',
            maxWidth: '100%',
            minWidth: 0,
            boxSizing: 'border-box',
            display: 'flex',
            flexDirection: 'column',
            overflow: 'hidden',
          }}
        >
          <Outlet />
        </Box>
      </Box>
    </Box>
  )
}

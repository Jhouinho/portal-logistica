import { useCallback, useEffect, useMemo, useState } from 'react'
import { Alert, Box, CircularProgress, Tab, Tabs, Typography } from '@mui/material'
import Inventory2OutlinedIcon from '@mui/icons-material/Inventory2Outlined'
import PlaylistAddCheckIcon from '@mui/icons-material/PlaylistAddCheck'
import LocalShippingOutlinedIcon from '@mui/icons-material/LocalShippingOutlined'
import LocalShippingIcon from '@mui/icons-material/LocalShipping'
import HourglassEmptyIcon from '@mui/icons-material/HourglassEmpty'
import PriorityHighIcon from '@mui/icons-material/PriorityHigh'
import HowToRegIcon from '@mui/icons-material/HowToReg'
import { api, type EncomendaListaItem } from '../../shared/api'
import { useCentroEstadosQuery } from '../../shared/centroEstadosQuery'
import { labels } from '../../shared/i18n/labels'
import { partitionTvKappsResumo } from '../../shared/tvKappsResumo'
import { CentroHeader, KpiStrip, MiniStat, NaoClassificadasHint } from './centroUi'
import { etapaColors, estadoSemantic, centroPageBg } from './portalChrome'
import {
  EmPickingView,
  EmSeparacaoView,
  GeralView,
  byPrioridadeCentro,
  isEmEsperaKapps,
  type KappsByStamp,
} from './CentroViews'
import { useOperacoesHub } from '../../shared/signalr'

type TabId = 'geral' | 'picking' | 'separacao'

const tabs: { id: TabId; label: string }[] = [
  { id: 'geral', label: 'Geral' },
  { id: 'picking', label: labels.picking },
  { id: 'separacao', label: labels.expedicao },
]

const ARMAZEM_LABEL = 'ARMAZÉM PRINCIPAL — INFORMAÇÃO OPERACIONAL'
const REFRESH_MS = 30_000

export function CentroOperacionalPage() {
  const [tab, setTab] = useState<TabId>('geral')
  const [loading, setLoading] = useState(true)
  const [erro, setErro] = useState<string | null>(null)
  const [rowsPicking, setRowsPicking] = useState<EncomendaListaItem[]>([])
  const [rowsSeparacao, setRowsSeparacao] = useState<EncomendaListaItem[]>([])
  const [rowsEmEntrega, setRowsEmEntrega] = useState<EncomendaListaItem[]>([])
  const [kappsPicking, setKappsPicking] = useState<KappsByStamp>({})
  const [kappsSeparacao, setKappsSeparacao] = useState<KappsByStamp>({})
  const [atualizadoEm, setAtualizadoEm] = useState<Date | null>(null)

  // Mesma cache que AppShell — sem GET independente a centro-estados.
  const { data: estados, dataUpdatedAt } = useCentroEstadosQuery()

  useEffect(() => {
    if (dataUpdatedAt) setAtualizadoEm(new Date(dataUpdatedAt))
  }, [dataUpdatedAt])

  /** Listas + Kapps do centro (KPIs vêm da query partilhada; invalidate SignalR → AppShell). */
  const carregar = useCallback(async (silencioso = false) => {
    if (!silencioso) {
      setLoading(true)
      setErro(null)
    }
    try {
      const [pickingRes, separacaoRes, emEntregaRes, kappsResumo] = await Promise.all([
        api.encomendasAbertas({ prontaPicking: true, page: 1, pageSize: 50 }),
        api.pickingDossiers({ fechada: false, checkIn: false, page: 1, pageSize: 50 }),
        api.pickingDossiers({ fechada: false, checkIn: true, page: 1, pageSize: 50 }),
        api.tvKappsResumo(),
      ])

      const picking = [...pickingRes.items].sort(byPrioridadeCentro)
      const separacao = [...separacaoRes.items].sort(byPrioridadeCentro)
      const emEntrega = [...emEntregaRes.items].sort((a, b) => {
        if (a.urgente !== b.urgente) return a.urgente ? -1 : 1
        const ta = a.checkInEm ? new Date(a.checkInEm).getTime() : 0
        const tb = b.checkInEm ? new Date(b.checkInEm).getTime() : 0
        if (ta !== tb) return ta - tb
        return byPrioridadeCentro(a, b)
      })

      const { picking: mapPicking, separacao: mapSeparacao } = partitionTvKappsResumo(
        kappsResumo.items,
      )

      setRowsPicking(picking)
      setRowsSeparacao(separacao)
      // Completa para progresso Separado (Kapps em curso com check-in); Check-in corta a 16 na view.
      setRowsEmEntrega(emEntrega)
      setKappsPicking(mapPicking)
      setKappsSeparacao(mapSeparacao)
      setAtualizadoEm(new Date())
      setErro(null)
    } catch (e) {
      setErro(e instanceof Error ? e.message : 'Erro ao carregar dados do centro.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void carregar(false)
    const id = window.setInterval(() => void carregar(true), REFRESH_MS)
    return () => window.clearInterval(id)
  }, [carregar])

  // Só listas/Kapps — KPIs invalidados uma vez no AppShell.
  const refreshSilencioso = useCallback(() => {
    void carregar(true)
  }, [carregar])

  useOperacoesHub(true, {
    onEncomendaAlterada: refreshSilencioso,
    onDossier66Alterado: refreshSilencioso,
    onDossier65Alterado: refreshSilencioso,
    onKappsAlterado: refreshSilencioso,
  })

  const kpis = useMemo(() => {
    const d = estados?.distribuicaoLogica
    return [
      {
        label: 'Em aberto',
        value: estados?.emAberto ?? 0,
        percent: d?.emAberto.percentagem,
        color: etapaColors[1],
        icon: Inventory2OutlinedIcon,
      },
      {
        label: labels.picking,
        value: estados?.emPicking ?? 0,
        percent: d?.emPicking.percentagem,
        color: etapaColors[2],
        icon: PlaylistAddCheckIcon,
      },
      {
        label: labels.expedicao,
        value: estados?.separado ?? 0,
        percent: d?.separado.percentagem,
        color: etapaColors[3],
        icon: LocalShippingOutlinedIcon,
      },
      {
        label: labels.emEntrega,
        value: estados?.emEntrega ?? 0,
        percent: d?.emEntrega.percentagem,
        color: etapaColors[4],
        icon: HowToRegIcon,
      },
      {
        label: labels.expedido,
        value: estados?.expedido ?? 0,
        percent: d?.emExpedicao.percentagem,
        color: etapaColors[5],
        icon: LocalShippingIcon,
      },
    ]
  }, [estados])

  const pickingEspera = useMemo(() => {
    let espera = 0
    let urgentesEspera = 0
    for (const r of rowsPicking) {
      if (!isEmEsperaKapps(kappsPicking[r.boStamp])) continue
      espera++
      if (r.urgente) urgentesEspera++
    }
    return { espera, urgentesEspera }
  }, [rowsPicking, kappsPicking])

  const separacaoEspera = useMemo(() => {
    let espera = 0
    let urgentesEspera = 0
    for (const r of rowsSeparacao) {
      if (!isEmEsperaKapps(kappsSeparacao[r.boStamp])) continue
      espera++
      if (r.urgente) urgentesEspera++
    }
    return { espera, urgentesEspera }
  }, [rowsSeparacao, kappsSeparacao])

  const checkInVisivel = useMemo(() => rowsEmEntrega.slice(0, 16), [rowsEmEntrega])

  const emEntregaUrgentes = useMemo(
    () => checkInVisivel.filter((r) => r.urgente).length,
    [checkInVisivel],
  )

  return (
    <Box
      sx={(theme) => ({
        ...centroPageBg(theme),
        flex: 1,
        minHeight: 0,
        alignSelf: 'stretch',
        width: '100%',
        maxWidth: '100%',
        px: { xs: 1.5, sm: 2, md: 3 },
        pt: 2,
        pb: 2,
        overflow: 'hidden',
        boxSizing: 'border-box',
        display: 'flex',
        flexDirection: 'column',
      })}
    >
      <Box flexShrink={0}>
        <CentroHeader armazem={ARMAZEM_LABEL} />
      </Box>

      <Tabs
        value={tab}
        onChange={(_, v: TabId) => setTab(v)}
        variant="scrollable"
        sx={{
          mb: 2,
          minHeight: 44,
          flexShrink: 0,
          borderBottom: (theme) => `1px solid ${theme.palette.portal.border}`,
          '& .MuiTab-root': {
            textTransform: 'none',
            fontWeight: 700,
            letterSpacing: 0.15,
            minHeight: 44,
            color: 'text.secondary',
          },
          '& .Mui-selected': { color: `${etapaColors[2]} !important` },
          '& .MuiTabs-indicator': { bgcolor: etapaColors[2], height: 3 },
        }}
      >
        {tabs.map((t) => (
          <Tab key={t.id} value={t.id} label={t.label} />
        ))}
      </Tabs>

      {erro ? (
        <Alert severity="error" sx={{ mb: 2, flexShrink: 0 }}>
          {erro}
        </Alert>
      ) : null}

      {loading && !estados ? (
        <Box display="flex" justifyContent="center" py={6} flexShrink={0}>
          <CircularProgress size={32} />
        </Box>
      ) : (
        <>
          <Box flexShrink={0} mb={1.25}>
            <KpiStrip items={kpis} />
            {(estados?.distribuicaoLogica?.naoClassificadas ?? 0) > 0 ? (
              <Box mt={0.75}>
                <NaoClassificadasHint
                  count={estados!.distribuicaoLogica!.naoClassificadas}
                />
              </Box>
            ) : null}
          </Box>

          <Box
            display="grid"
            gap={1}
            mb={1.25}
            flexShrink={0}
            gridTemplateColumns={{ xs: '1fr 1fr', md: 'repeat(3, 1fr)', lg: 'repeat(6, 1fr)' }}
          >
            <MiniStat
              label="Picking · em espera"
              value={pickingEspera.espera}
              color={etapaColors[2]}
              Icon={HourglassEmptyIcon}
            />
            <MiniStat
              label="Picking · urgentes"
              value={pickingEspera.urgentesEspera}
              color={estadoSemantic.urgente.color}
              Icon={PriorityHighIcon}
            />
            <MiniStat
              label="Separado · à espera"
              value={separacaoEspera.espera}
              color={etapaColors[3]}
              Icon={HourglassEmptyIcon}
            />
            <MiniStat
              label="Separado · urgentes"
              value={separacaoEspera.urgentesEspera}
              color={estadoSemantic.urgente.color}
              Icon={PriorityHighIcon}
            />
            <MiniStat
              label="Check-in · à espera"
              value={checkInVisivel.length}
              color={etapaColors[4]}
              Icon={HowToRegIcon}
            />
            <MiniStat
              label="Check-in · urgentes"
              value={emEntregaUrgentes}
              color={estadoSemantic.urgente.color}
              Icon={PriorityHighIcon}
            />
          </Box>

          <Box
            sx={{
              flex: 1,
              minHeight: 0,
              display: 'flex',
              flexDirection: 'column',
              overflow: 'hidden',
            }}
          >
            {tab === 'geral' && (
              <GeralView
                rowsPicking={rowsPicking}
                rowsSeparacao={rowsSeparacao}
                rowsEmEntrega={rowsEmEntrega}
                kappsPicking={kappsPicking}
                kappsSeparacao={kappsSeparacao}
              />
            )}
            {tab === 'picking' && (
              <EmPickingView rows={rowsPicking} kappsByStamp={kappsPicking} />
            )}
            {tab === 'separacao' && (
              <EmSeparacaoView
                rows={rowsSeparacao}
                rowsEmEntrega={rowsEmEntrega}
                kappsByStamp={kappsSeparacao}
              />
            )}
          </Box>
        </>
      )}

      <Typography
        variant="caption"
        color="text.secondary"
        display="block"
        mt={1.5}
        fontWeight={600}
        flexShrink={0}
      >
        Actualização automática a cada {REFRESH_MS / 1000}s
        {atualizadoEm
          ? ` · última ${atualizadoEm.toLocaleTimeString('pt-PT')}`
          : ''}
        {' · '}mesmo modelo da Vista TV
      </Typography>
    </Box>
  )
}

import { useCallback, useEffect, useMemo, useState } from 'react'
import { Alert, Box, CircularProgress, Typography } from '@mui/material'
import Inventory2OutlinedIcon from '@mui/icons-material/Inventory2Outlined'
import PlaylistAddCheckIcon from '@mui/icons-material/PlaylistAddCheck'
import LocalShippingOutlinedIcon from '@mui/icons-material/LocalShippingOutlined'
import LocalShippingIcon from '@mui/icons-material/LocalShipping'
import HourglassEmptyIcon from '@mui/icons-material/HourglassEmpty'
import PriorityHighIcon from '@mui/icons-material/PriorityHigh'
import HowToRegIcon from '@mui/icons-material/HowToReg'
import { api, type CentroEstadosKpis, type EncomendaListaItem } from '../../shared/api'
import { labels } from '../../shared/i18n/labels'
import { ColorModeToggle } from '../../shared/ui/ColorModeToggle'
import { CentroHeader, KpiStrip, MiniStat, NaoClassificadasHint, centroPageBg } from './centroUi'
import {
  GeralView,
  byPrioridadeCentro,
  isEmEsperaKapps,
  type KappsByStamp,
} from './CentroViews'
import { etapaColors, estadoSemantic } from './portalChrome'
import { useTvHub } from '../../shared/tvSignalr'
import { partitionTvKappsResumo } from '../../shared/tvKappsResumo'

/** Mesmo rótulo e modelo de dados do Centro Operacional. */
const ARMAZEM_LABEL = 'ARMAZÉM PRINCIPAL — INFORMAÇÃO OPERACIONAL'
const REFRESH_MS = 30_000

export function CentroTvPage() {
  const [loading, setLoading] = useState(true)
  const [erro, setErro] = useState<string | null>(null)
  const [estados, setEstados] = useState<CentroEstadosKpis | null>(null)
  const [rowsPicking, setRowsPicking] = useState<EncomendaListaItem[]>([])
  const [rowsSeparacao, setRowsSeparacao] = useState<EncomendaListaItem[]>([])
  const [rowsEmEntrega, setRowsEmEntrega] = useState<EncomendaListaItem[]>([])
  const [kappsPicking, setKappsPicking] = useState<KappsByStamp>({})
  const [kappsSeparacao, setKappsSeparacao] = useState<KappsByStamp>({})
  const [atualizadoEm, setAtualizadoEm] = useState<Date | null>(null)

  const carregar = useCallback(async (silencioso = false) => {
    if (!silencioso) {
      setLoading(true)
      setErro(null)
    }
    try {
      const [estadosRes, pickingRes, separacaoRes, emEntregaRes, kappsResumo] = await Promise.all([
        api.centroEstados(),
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

      setEstados(estadosRes)
      setRowsPicking(picking)
      setRowsSeparacao(separacao)
      // Lista completa: progresso Separado usa também check-in; o painel Check-in corta a 16.
      setRowsEmEntrega(emEntrega)
      setKappsPicking(mapPicking)
      setKappsSeparacao(mapSeparacao)
      setAtualizadoEm(new Date())
      setErro(null)
    } catch (e) {
      setErro(e instanceof Error ? e.message : 'Erro ao carregar vista TV.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void carregar(false)
    const id = window.setInterval(() => void carregar(true), REFRESH_MS)
    return () => window.clearInterval(id)
  }, [carregar])

  const refreshSilencioso = useCallback(() => {
    void carregar(true)
  }, [carregar])

  useTvHub(true, {
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
      height="100%"
      overflow="hidden"
      display="flex"
      flexDirection="column"
      px={{ xs: 2, md: 3, lg: 4 }}
      py={2.5}
      sx={centroPageBg}
    >
      <Box flexShrink={0}>
        <CentroHeader
          armazem={ARMAZEM_LABEL}
          endActions={<ColorModeToggle size="small" />}
        />
      </Box>

      {erro ? (
        <Alert severity="error" sx={{ mb: 2, flexShrink: 0 }}>
          {erro}
        </Alert>
      ) : null}

      {loading && !estados ? (
        <Box display="flex" justifyContent="center" alignItems="center" flex={1}>
          <CircularProgress size={40} />
        </Box>
      ) : (
        <Box flex={1} minHeight={0} display="flex" flexDirection="column" overflow="hidden">
          <Box flexShrink={0} mb={1.25}>
            <KpiStrip items={kpis} />
            {(estados?.distribuicaoLogica?.naoClassificadas ?? 0) > 0 ? (
              <Box mt={0.75}>
                <NaoClassificadasHint count={estados!.distribuicaoLogica!.naoClassificadas} />
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

          <Box flex={1} minHeight={0} display="flex" flexDirection="column" overflow="hidden">
            <GeralView
              rowsPicking={rowsPicking}
              rowsSeparacao={rowsSeparacao}
              rowsEmEntrega={rowsEmEntrega}
              kappsPicking={kappsPicking}
              kappsSeparacao={kappsSeparacao}
            />
          </Box>
        </Box>
      )}

      <Typography
        variant="body2"
        color="text.secondary"
        display="block"
        mt={2}
        fontWeight={600}
        flexShrink={0}
      >
        Modo TV · actualização automática a cada {REFRESH_MS / 1000}s
        {atualizadoEm
          ? ` · última actualização ${atualizadoEm.toLocaleTimeString('pt-PT')}`
          : ''}
        {' · '}mesmo modelo do Centro Operacional
      </Typography>
    </Box>
  )
}

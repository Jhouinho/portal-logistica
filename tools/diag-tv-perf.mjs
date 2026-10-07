/**
 * DIAG_TV_PERF — mirrors CentroTvPage.carregar() HTTP waves.
 * Base: http://localhost:5080
 *
 * Usage:
 *   node tools/diag-tv-perf.mjs
 *   node tools/diag-tv-perf.mjs --signalr-only
 *   node tools/diag-tv-perf.mjs --cycles 5 --signalr-ms 45000
 */
import { createRequire } from 'node:module'
import { pathToFileURL } from 'node:url'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const BASE = process.env.API_BASE ?? 'http://localhost:5080'
const CYCLES = Number(process.argv.includes('--cycles')
  ? process.argv[process.argv.indexOf('--cycles') + 1]
  : 5)
const SIGNALR_MS = Number(process.argv.includes('--signalr-ms')
  ? process.argv[process.argv.indexOf('--signalr-ms') + 1]
  : 45000)
const SIGNALR_ONLY = process.argv.includes('--signalr-only')
const SKIP_SIGNALR = process.argv.includes('--no-signalr')

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const signalrPkg = path.resolve(
  __dirname,
  '../src/frontend/node_modules/@microsoft/signalr/dist/cjs/index.js',
)

async function timed(label, fn) {
  const t0 = performance.now()
  const startedAt = new Date().toISOString()
  try {
    const data = await fn()
    const ms = Math.round(performance.now() - t0)
    return { label, ok: true, ms, startedAt, endedAt: new Date().toISOString(), data }
  } catch (e) {
    const ms = Math.round(performance.now() - t0)
    return {
      label,
      ok: false,
      ms,
      startedAt,
      endedAt: new Date().toISOString(),
      error: e instanceof Error ? e.message : String(e),
      data: null,
    }
  }
}

async function getJson(urlPath) {
  const res = await fetch(`${BASE}${urlPath}`, {
    headers: { Accept: 'application/json' },
  })
  if (!res.ok) {
    let detail = res.statusText
    try {
      const body = await res.json()
      detail = body.detail ?? body.title ?? detail
    } catch {
      /* ignore */
    }
    throw new Error(`${res.status} ${detail} (${urlPath})`)
  }
  if (res.status === 204) return null
  return res.json()
}

function itemsOf(payload) {
  if (!payload) return []
  if (Array.isArray(payload.items)) return payload.items
  if (Array.isArray(payload)) return payload
  return []
}

async function carregarOnce(cycle) {
  const cycleStart = new Date().toISOString()
  const t0 = performance.now()

  const wave1 = await Promise.all([
    timed('centroEstados', () => getJson('/api/v1/painel/centro-estados')),
    timed('encomendasAbertas', () =>
      getJson('/api/v1/encomendas/abertas?prontaPicking=true&page=1&pageSize=40'),
    ),
    timed('pickingDossiers_checkInFalse', () =>
      getJson('/api/v1/picking-dossiers?fechada=false&checkIn=false&page=1&pageSize=40'),
    ),
    timed('pickingDossiers_checkInTrue', () =>
      getJson('/api/v1/picking-dossiers?fechada=false&checkIn=true&page=1&pageSize=40'),
    ),
  ])
  const wave1Ms = Math.round(performance.now() - t0)

  const picking = itemsOf(wave1[1].data)
  const separacao = itemsOf(wave1[2].data)
  const emEntrega = itemsOf(wave1[3].data)

  const tKapps = performance.now()
  const kappsCalls = [
    ...picking.map((item) =>
      timed(`encomendaPickingKapps:${item.boStamp}`, () =>
        getJson(`/api/v1/encomendas/${encodeURIComponent(item.boStamp)}/picking-kapps`),
      ),
    ),
    ...separacao.map((item) =>
      timed(`pickingDossierPickingKapps:${item.boStamp}`, () =>
        getJson(`/api/v1/picking-dossiers/${encodeURIComponent(item.boStamp)}/picking-kapps`),
      ),
    ),
  ]
  const kappsResults = await Promise.all(kappsCalls)
  const kappsMs = Math.round(performance.now() - tKapps)
  const totalMs = Math.round(performance.now() - t0)

  const kappsOk = kappsResults.filter((r) => r.ok).length
  const kappsFail = kappsResults.filter((r) => !r.ok).length
  const kappsMsList = kappsResults.map((r) => r.ms)
  const kappsAvg =
    kappsMsList.length === 0
      ? 0
      : Math.round(kappsMsList.reduce((a, b) => a + b, 0) / kappsMsList.length)

  return {
    cycle,
    cycleStart,
    cycleEnd: new Date().toISOString(),
    wave1Ms,
    kappsMs,
    totalMs,
    dominantWave: kappsMs > wave1Ms ? 'kapps' : 'wave1',
    counts: {
      picking: picking.length,
      separacao: separacao.length,
      emEntrega: emEntrega.length,
      kappsHttp: kappsCalls.length,
      kappsOk,
      kappsFail,
    },
    wave1TimingsMs: Object.fromEntries(wave1.map((w) => [w.label, w.ms])),
    wave1Ok: wave1.every((w) => w.ok),
    wave1Errors: wave1.filter((w) => !w.ok).map((w) => ({ label: w.label, error: w.error })),
    kapps: {
      avgMs: kappsAvg,
      minMs: kappsMsList.length ? Math.min(...kappsMsList) : null,
      maxMs: kappsMsList.length ? Math.max(...kappsMsList) : null,
      sampleErrors: kappsResults
        .filter((r) => !r.ok)
        .slice(0, 5)
        .map((r) => ({ label: r.label, error: r.error, ms: r.ms })),
    },
  }
}

async function listenSignalR(ms) {
  const require = createRequire(import.meta.url)
  let signalR
  try {
    signalR = require(signalrPkg)
  } catch (e) {
    return {
      connected: false,
      error: `Cannot load @microsoft/signalr: ${e instanceof Error ? e.message : String(e)}`,
      events: [],
    }
  }

  const { HubConnectionBuilder, LogLevel } = signalR
  const connection = new HubConnectionBuilder()
    .withUrl(`${BASE}/hubs/tv`, { withCredentials: false })
    .configureLogging(LogLevel.Warning)
    .build()

  const events = []
  const eventNames = ['dossier66Alterado', 'dossier65Alterado', 'kappsAlterado']
  for (const name of eventNames) {
    connection.on(name, (...args) => {
      const receivedAt = new Date().toISOString()
      const perfNow = performance.now()
      events.push({ event: name, receivedAt, perfNow, args })
      console.error(`[signalr] ${receivedAt} event=${name}`)
    })
  }

  const t0 = performance.now()
  try {
    await connection.start()
  } catch (e) {
    return {
      connected: false,
      connectMs: Math.round(performance.now() - t0),
      error: e instanceof Error ? e.message : String(e),
      events: [],
    }
  }

  const connectedAt = new Date().toISOString()
  console.error(`[signalr] connected ${connectedAt} id=${connection.connectionId}`)

  // Wait for first event or timeout; on event run one carregar
  let eventTriggeredCarregar = null
  const waitUntil = Date.now() + ms
  while (Date.now() < waitUntil) {
    if (events.length > 0 && !eventTriggeredCarregar) {
      const ev = events[0]
      const gapMs = Math.round(performance.now() - ev.perfNow)
      console.error(`[signalr] event→carregar starting after ${gapMs}ms`)
      const carregar = await carregarOnce('signalr-trigger')
      eventTriggeredCarregar = {
        event: ev,
        eventToCarregarStartMs: gapMs,
        carregar,
      }
      // continue listening remaining time but don't re-trigger
    }
    await new Promise((r) => setTimeout(r, 250))
  }

  try {
    await connection.stop()
  } catch {
    /* ignore */
  }

  return {
    connected: true,
    connectMs: Math.round(performance.now() - t0),
    connectionId: connection.connectionId,
    listenMs: ms,
    events,
    eventTriggeredCarregar,
  }
}

async function main() {
  const report = {
    base: BASE,
    startedAt: new Date().toISOString(),
    cycles: [],
    signalr: null,
  }

  if (!SIGNALR_ONLY) {
    for (let i = 1; i <= CYCLES; i++) {
      console.error(`[diag] cycle ${i}/${CYCLES} starting…`)
      const result = await carregarOnce(i)
      report.cycles.push(result)
      console.error(
        `[diag] cycle ${i} totalMs=${result.totalMs} wave1Ms=${result.wave1Ms} kappsMs=${result.kappsMs} kappsHttp=${result.counts.kappsHttp} dominant=${result.dominantWave}`,
      )
      if (i < CYCLES) await new Promise((r) => setTimeout(r, 2000))
    }
  }

  if (!SKIP_SIGNALR) {
    console.error(`[diag] SignalR listen ${SIGNALR_MS}ms…`)
    report.signalr = await listenSignalR(SIGNALR_MS)
  }

  report.endedAt = new Date().toISOString()

  if (report.cycles.length) {
    const totals = report.cycles.map((c) => c.totalMs)
    const wave1s = report.cycles.map((c) => c.wave1Ms)
    const kapps = report.cycles.map((c) => c.kappsMs)
    report.summary = {
      totalMs: { avg: avg(totals), min: Math.min(...totals), max: Math.max(...totals) },
      wave1Ms: { avg: avg(wave1s), min: Math.min(...wave1s), max: Math.max(...wave1s) },
      kappsMs: { avg: avg(kapps), min: Math.min(...kapps), max: Math.max(...kapps) },
      dominantVotes: {
        wave1: report.cycles.filter((c) => c.dominantWave === 'wave1').length,
        kapps: report.cycles.filter((c) => c.dominantWave === 'kapps').length,
      },
      kappsHttpPerCycle: report.cycles.map((c) => c.counts.kappsHttp),
    }
  }

  console.log(JSON.stringify(report, null, 2))
}

function avg(nums) {
  return Math.round(nums.reduce((a, b) => a + b, 0) / nums.length)
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})

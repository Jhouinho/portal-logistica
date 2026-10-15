/**
 * Teste de contrato (sem Vitest): confirma que a invalidação da mudança de semana
 * usa as roots reais das listas RQ e cobre as keys conhecidas.
 *
 * Executar:
 *   node --experimental-strip-types src/frontend/src/shared/foraDePrazoWeekInvalidate.contract.test.mjs
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const dir = dirname(fileURLToPath(import.meta.url))

const {
  FORA_DE_PRAZO_WEEK_QUERY_KEY_ROOTS,
  queryKeyCoveredByForaDePrazoWeekInvalidation,
  invalidateForaDePrazoWeekQueries,
} = await import('./foraDePrazoWeekInvalidate.ts')

assert.deepEqual(
  [...FORA_DE_PRAZO_WEEK_QUERY_KEY_ROOTS.map((r) => [...r])],
  [['encomendas-lista'], ['dossiers-lista']],
)

const encomendasSrc = readFileSync(join(dir, 'encomendasQuery.ts'), 'utf8')
const dossiersSrc = readFileSync(join(dir, 'dossiersQuery.ts'), 'utf8')
assert.match(encomendasSrc, /\['encomendas-lista',\s*'abertas'\]/)
assert.match(dossiersSrc, /\['dossiers-lista',\s*'66'\]/)
assert.match(dossiersSrc, /\['dossiers-lista',\s*'65'\]/)

assert.equal(
  queryKeyCoveredByForaDePrazoWeekInvalidation(['encomendas-lista', 'abertas', {}]),
  true,
)
assert.equal(
  queryKeyCoveredByForaDePrazoWeekInvalidation(['dossiers-lista', '66', {}]),
  true,
)
assert.equal(
  queryKeyCoveredByForaDePrazoWeekInvalidation(['dossiers-lista', '65', {}]),
  true,
)
assert.equal(queryKeyCoveredByForaDePrazoWeekInvalidation(['encomendas']), false)
assert.equal(queryKeyCoveredByForaDePrazoWeekInvalidation(['picking']), false)
assert.equal(queryKeyCoveredByForaDePrazoWeekInvalidation(['checkin']), false)

const calls = []
invalidateForaDePrazoWeekQueries({
  invalidateQueries(opts) {
    calls.push(opts.queryKey)
  },
})
assert.deepEqual(calls, [['encomendas-lista'], ['dossiers-lista']])

const hookSrc = readFileSync(join(dir, 'useForaDePrazoWeekBoundary.ts'), 'utf8')
assert.match(hookSrc, /invalidateForaDePrazoWeekQueries/)
assert.doesNotMatch(hookSrc, /queryKey:\s*\['encomendas'\]/)
assert.doesNotMatch(hookSrc, /queryKey:\s*\['picking'\]/)
assert.doesNotMatch(hookSrc, /queryKey:\s*\['separacao'\]/)
assert.doesNotMatch(hookSrc, /queryKey:\s*\['checkin'\]/)
assert.match(hookSrc, /FORA_DE_PRAZO_WEEK_BOUNDARY_EVENT/)
assert.match(hookSrc, /timerRef\.current/)
assert.match(hookSrc, /cancelled = true/)

console.log('foraDePrazoWeekInvalidate.contract.test.mjs: OK')

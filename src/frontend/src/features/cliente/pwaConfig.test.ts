/**
 * Contrato estático do PWA no Vite — sem dispositivo físico.
 * Executar: node --experimental-strip-types --test src/features/cliente/pwaConfig.test.ts
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { describe, it } from 'node:test'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..')
const viteConfig = readFileSync(join(root, 'vite.config.ts'), 'utf8')

describe('vite PWA config', () => {
  it('define manifest do Portal Mobile com start_url cliente', () => {
    assert.match(viteConfig, /name:\s*'Portal Mobile/)
    assert.match(viteConfig, /start_url:\s*'\/cliente\/login'/)
    assert.match(viteConfig, /scope:\s*'\/cliente\/'/)
  })

  it('não injecta SW automaticamente em LAN/IIS local', () => {
    assert.match(viteConfig, /injectRegister:\s*false/)
    assert.match(viteConfig, /selfDestroying:\s*true/)
    assert.match(viteConfig, /devOptions:\s*\{[\s\S]*enabled:\s*false/)
  })
})

/**
 * Testes não destrutivos do contexto de login operador / returnUrl.
 * Executar: node --experimental-strip-types --test src/features/autenticacao/safeReturnUrl.test.ts
 */
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import {
  isOperadorLoginContext,
  resolveOperadorReturnUrl,
  resolvePostLoginDestination,
  sanitizeOperadorReturnUrl,
} from './safeReturnUrl.ts'

describe('sanitizeOperadorReturnUrl', () => {
  it('aceita destinos internos de operador', () => {
    assert.equal(sanitizeOperadorReturnUrl('/operador/pedidos-mobile'), '/operador/pedidos-mobile')
    assert.equal(sanitizeOperadorReturnUrl('/operador'), '/operador')
  })

  it('decodifica percent-encoding simples e duplo', () => {
    const once = encodeURIComponent('/operador/pedidos-mobile')
    const twice = encodeURIComponent(once)
    assert.equal(sanitizeOperadorReturnUrl(once), '/operador/pedidos-mobile')
    assert.equal(sanitizeOperadorReturnUrl(twice), '/operador/pedidos-mobile')
  })

  it('rejeita externos, protocolo e path traversal aberto', () => {
    assert.equal(sanitizeOperadorReturnUrl('https://evil.example/x'), null)
    assert.equal(sanitizeOperadorReturnUrl('//evil.example'), null)
    assert.equal(sanitizeOperadorReturnUrl('/operadorEvil'), null)
    assert.equal(sanitizeOperadorReturnUrl('/pedidos-mobile'), null)
    assert.equal(sanitizeOperadorReturnUrl('operador/pedidos-mobile'), null)
  })
})

describe('login operador com returnUrl válido', () => {
  it('activa contexto de operador e destino pós-login', () => {
    const sources = {
      queryReturnUrl: '/operador/pedidos-mobile',
      state: null,
      stashed: null,
    }
    assert.equal(isOperadorLoginContext(sources), true)
    assert.equal(resolvePostLoginDestination(sources), '/operador/pedidos-mobile')
  })

  it('usa state quando a query falha', () => {
    const sources = {
      queryReturnUrl: 'https://evil.example',
      state: { returnUrl: '/operador/pedidos-mobile' },
      stashed: null,
    }
    assert.equal(resolveOperadorReturnUrl(sources), '/operador/pedidos-mobile')
    assert.equal(isOperadorLoginContext(sources), true)
  })
})

describe('login normal da Logística sem returnUrl', () => {
  it('não activa UI de operador e navega para /', () => {
    const sources = { queryReturnUrl: null, state: null, stashed: null }
    assert.equal(isOperadorLoginContext(sources), false)
    assert.equal(resolvePostLoginDestination(sources), '/')
  })
})

describe('preservação do destino após falha (candidato em memória)', () => {
  it('mantém o destino capturado mesmo sem query live', () => {
    const captured = '/operador/pedidos-mobile'
    // Simula ref de mount + submit sem alterar URL (erro anterior não limpou stash/ref).
    const dest = resolvePostLoginDestination({
      queryReturnUrl: null,
      state: null,
      stashed: captured,
    })
    assert.equal(dest, '/operador/pedidos-mobile')
    assert.equal(isOperadorLoginContext({ stashed: captured }), true)
  })
})

describe('rejeição de destinos externos ou inválidos', () => {
  it('resolvePostLoginDestination cai em / quando só há lixo', () => {
    assert.equal(
      resolvePostLoginDestination({
        queryReturnUrl: 'https://phish.test/login',
        state: { returnUrl: '//evil' },
        stashed: '/cliente/carrinho',
      }),
      '/',
    )
    assert.equal(
      isOperadorLoginContext({
        queryReturnUrl: '/cliente',
        state: { returnUrl: 'https://x' },
        stashed: null,
      }),
      false,
    )
  })
})

describe('Portal do Cliente não é aceite como returnUrl de operador', () => {
  it('rejeita paths /cliente/**', () => {
    assert.equal(sanitizeOperadorReturnUrl('/cliente'), null)
    assert.equal(sanitizeOperadorReturnUrl('/cliente/login'), null)
    assert.equal(
      resolvePostLoginDestination({ queryReturnUrl: '/cliente/carrinho', stashed: null }),
      '/',
    )
  })
})

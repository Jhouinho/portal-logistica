/**
 * Executar: node --experimental-strip-types --test src/features/cliente/clienteQr.test.ts
 */
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { httpsHintUrl, normalizeQrPayload } from './clienteQrPayload.ts'

describe('normalizeQrPayload', () => {
  it('aceita referência simples', () => {
    assert.equal(normalizeQrPayload('1051'), '1051')
    assert.equal(normalizeQrPayload('  1051  '), '1051')
  })

  it('extrai ref de URL com query', () => {
    assert.equal(normalizeQrPayload('https://portal.example/x?ref=1051'), '1051')
    assert.equal(normalizeQrPayload('https://portal.example/x?referencia=1310'), '1310')
  })

  it('usa último segmento do path se não houver query', () => {
    assert.equal(normalizeQrPayload('https://portal.example/artigos/1051'), '1051')
  })

  it('trata payloads vazios e não-URL de forma previsível', () => {
    assert.equal(normalizeQrPayload(''), '')
    assert.equal(normalizeQrPayload('   '), '')
    assert.equal(normalizeQrPayload('javascript:alert(1)'), 'javascript:alert(1)')
    assert.equal(normalizeQrPayload('not a url'), 'not a url')
  })
})

describe('httpsHintUrl', () => {
  it('em secure context não sugere HTTPS', () => {
    assert.equal(
      httpsHintUrl({
        isSecureContext: true,
        hostname: '192.168.0.123',
        port: '8088',
        pathname: '/cliente',
        search: '',
      }),
      null,
    )
  })

  it('em HTTP LAN na 8088 sugere 8443', () => {
    assert.equal(
      httpsHintUrl({
        isSecureContext: false,
        hostname: '192.168.0.123',
        port: '8088',
        pathname: '/cliente/login',
        search: '',
      }),
      'https://192.168.0.123:8443/cliente/login',
    )
  })

  it('localhost HTTP não força hint', () => {
    assert.equal(
      httpsHintUrl({
        isSecureContext: false,
        hostname: '127.0.0.1',
        port: '5173',
        pathname: '/',
        search: '',
      }),
      null,
    )
  })
})

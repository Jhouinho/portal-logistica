/**
 * Executar: node --experimental-strip-types --test src/features/cliente/carrinhoStorage.test.ts
 */
import assert from 'node:assert/strict'
import { afterEach, beforeEach, describe, it } from 'node:test'
import {
  CARRINHO_CHANGED_EVENT,
  cartStorageKey,
  clearCarrinho,
  lisbonDateKey,
  loadCarrinho,
  saveCarrinho,
  upsertLinha,
  type CarrinhoLinha,
} from './carrinhoStorage.ts'

function installMemoryStorage() {
  const map = new Map<string, string>()
  const storage = {
    getItem: (k: string) => (map.has(k) ? map.get(k)! : null),
    setItem: (k: string, v: string) => {
      map.set(k, String(v))
    },
    removeItem: (k: string) => {
      map.delete(k)
    },
    clear: () => map.clear(),
    key: (i: number) => [...map.keys()][i] ?? null,
    get length() {
      return map.size
    },
  }
  Object.defineProperty(globalThis, 'localStorage', { value: storage, configurable: true })
  return map
}

describe('carrinhoStorage', () => {
  const events: string[] = []
  const day = new Date('2026-10-28T12:00:00Z')
  const nextDay = new Date('2026-10-29T12:00:00Z')

  beforeEach(() => {
    installMemoryStorage()
    events.length = 0
    const g = globalThis as typeof globalThis & { window?: Window & typeof globalThis }
    g.window = g.window ?? (g as unknown as Window & typeof globalThis)
    g.window!.addEventListener = ((type: string) => {
      // capture via dispatch override below
      void type
    }) as Window['addEventListener']
    g.window!.dispatchEvent = ((ev: Event) => {
      events.push(ev.type)
      return true
    }) as Window['dispatchEvent']
  })

  afterEach(() => {
    events.length = 0
  })

  it('upsert acumula mesma ref+cor e separa cores diferentes', () => {
    let linhas: CarrinhoLinha[] = []
    linhas = upsertLinha(linhas, {
      ref: '1051',
      design: 'A',
      cor: 'AZUL',
      qtt: 1,
      precoUnitario: 6.5,
    })
    linhas = upsertLinha(linhas, {
      ref: '1051',
      design: 'A',
      cor: 'AZUL',
      qtt: 2,
      precoUnitario: 6.5,
    })
    linhas = upsertLinha(linhas, {
      ref: '1051',
      design: 'A',
      cor: 'VERDE',
      qtt: 1,
      precoUnitario: 6.5,
    })
    assert.equal(linhas.length, 2)
    assert.equal(linhas[0]!.qtt, 3)
    assert.equal(linhas[1]!.cor, 'VERDE')
  })

  it('save/load no mesmo dia e clear emite evento', () => {
    const linhas: CarrinhoLinha[] = [
      { ref: '1051', design: 'X', cor: '', qtt: 2, precoUnitario: 6.5 },
    ]
    saveCarrinho(6065, 0, linhas, day)
    assert.deepEqual(loadCarrinho(6065, 0, day), linhas)
    assert.ok(events.includes(CARRINHO_CHANGED_EVENT))
    events.length = 0
    clearCarrinho(6065, 0, day)
    assert.deepEqual(loadCarrinho(6065, 0, day), [])
    assert.ok(events.includes(CARRINHO_CHANGED_EVENT))
  })

  it('chave de outro dia não recupera o carrinho', () => {
    saveCarrinho(
      6065,
      0,
      [{ ref: '1051', design: 'X', cor: '', qtt: 1, precoUnitario: 6.5 }],
      day,
    )
    assert.equal(loadCarrinho(6065, 0, nextDay).length, 0)
    assert.notEqual(lisbonDateKey(day), lisbonDateKey(nextDay))
    assert.equal(cartStorageKey(6065, 0, lisbonDateKey(day)), `ls_cliente_cart_6065_0_${lisbonDateKey(day)}`)
  })

  it('clientes diferentes não partilham chave', () => {
    saveCarrinho(1, 0, [{ ref: 'A', design: 'A', cor: '', qtt: 1, precoUnitario: 1 }], day)
    assert.equal(loadCarrinho(2, 0, day).length, 0)
  })
})

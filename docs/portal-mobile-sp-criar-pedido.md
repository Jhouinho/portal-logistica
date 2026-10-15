# SP `sp_HCA_criar_pedido_mobile` (ndos=67)

## Scripts

| Ficheiro | Função |
| --- | --- |
| `sql/091_create_sp_HCA_criar_pedido_mobile.sql` | TVP + tabela idempotência + SP |
| `sql/091b_validate_sp_HCA_criar_pedido_mobile.sql` | Testes UAT (com cleanup) |
| `sql/091c_grant_sp_HCA_criar_pedido_mobile.sql` | GRANT a `portal_app` |

## Contrato (ainda sem API .NET)

**Entrada**

| Parâmetro | Tipo | Notas |
| --- | --- | --- |
| `@no`, `@estab` | numeric | Cliente PHC |
| `@Linhas` | `HCA_PedidoMobileLinhaType` | `linha_ord`, `ref`, `qtt` (>0), `cor` (→ `BI.u_cor`; default `''`) — ver `093_alter_sp_HCA_criar_pedido_mobile_cor.sql` |
| `@IdempotencyKey` | varchar(64) | Obrigatória; repetir a mesma key não cria 2.º documento |
| `@usrinis` | varchar(3) | Default `MOB` |
| `@armazem` | numeric | Default `1` (como ref Desktop) |
| `@dataobra` | date | Default hoje |

**Preços:** nunca vindos do browser. `CL.preco` (1..5) → `ST.epv1`..`epv5`.

**Saída:** `alreadyExists`, `bostamp`, `obrano`, `boano`, `ndos`, `nmdos`, `etotaldeb`, `totaldeb`, `linhas`.

## Stamps

`LEFT(CONVERT(varchar(36), NEWID()), 23)` → `char(25)`. Decisão de projecto; **não** é o formato nativo Desktop (`ADM…`). Validar em UAT junto do negócio/PHC.

## UAT (15/10/2026)

Caso A (1911 / ref 1310 / qtt 1): `edebito`, `debito`, `ettdeb`, `ttdeb`, `iva`, `etotaldeb`, `totaldeb` **iguais** ao dossier Desktop `ADM26101553304,036000001`. Extensões BO2/BO3/BI2 presentes; sem movimentos `SL`. Idempotência e obranos distintos: OK. Cleanup dos docs `UAT-MOB-*` executado; ref Desktop intacto.

## API

Não alterada nesta fase. Quando integrar: enviar `Idempotency-Key` e mapear o TVP; não aceitar preços do cliente.

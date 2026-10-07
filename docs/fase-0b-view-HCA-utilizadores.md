# Fase 0B — Criar `view_HCA_utilizadores` (passo a passo)

> **HISTÓRICO (2026-09-29).** Objecto 0B. Auth/gate actual: [`auth-portal-identity.md`](./auth-portal-identity.md).

| | |
| --- | --- |
| Projeto | Liliana & Seródio — Portal de Logística |
| Objeto | `dbo.view_HCA_utilizadores` |
| Script | [`sql/010_create_view_HCA_utilizadores.sql`](../sql/010_create_view_HCA_utilizadores.sql) |
| Ambiente atual | **UAT feito** (2026-08-10) · **Produção** só no fim da implementação completa |
| Fonte | [ARCHITECTURE.md](../ARCHITECTURE.md) · [sql/002_views_and_procedures.md](../sql/002_views_and_procedures.md) |

---

## 1. Objetivo

Criar a **primeira vista SQL** do portal: dados mínimos da tabela PHC **`US`** para lookup do utilizador após autenticação Microsoft Entra.

A API .NET lê via **`sp_HCA_validar_login`** / Dapper. Após login Entra válido e mapeamento → **cookie / sessão web**.

---

## 2. Pré-requisitos (já feitos neste projeto)

- [x] Campo `US.u_portalph` criado (`varchar(254) NOT NULL`) — legado; **não** é requisito de acesso Entra
- [ ] Pelo menos um utilizador piloto em `US` com `inactivo = 0` e `usercode` alinhado ao username/UPN Entra
- [x] Acesso SQL à BD UAT (login com permissão para criar vistas no schema `dbo`)

---

## 3. Mapeamento de colunas

| Coluna `US` (PHC) | Alias na vista | Uso |
| --- | --- | --- |
| `usstamp` | `userstamp` | Identificador estável do utilizador |
| `usercode` | `login` | Utilizador do portal (match Entra) |
| `username` | `nome` | Nome apresentado |
| `iniciais` | `usrinis` | Fonte para `usrinis` em BO/BI |
| `u_portalph` | `portal_hash` | Legado (opcional) |
| `inactivo` | *(filtro)* | Excluir inativos |

---

## 4. Regras da vista

Devolver **apenas** utilizadores que:

1. **Não estão inativos:** `ISNULL(us.inactivo, 0) = 0`

---

## 5. Passo a passo — UAT

### Passo 1 — Abrir a BD de teste

1. Abrir **SQL Server Management Studio** (ou Azure Data Studio).
2. Ligar ao servidor UAT.
3. Selecionar a base de dados PHC CS de **teste** (não Produção).

### Passo 2 — Confirmar pré-requisitos

Executar:

```sql
-- Campo u_portalph existe?
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'us'
  AND COLUMN_NAME = 'u_portalph';

-- Utilizadores candidatos (ativos + hash preenchido)
SELECT TOP 20
  us.usstamp,
  us.usercode,
  us.username,
  us.iniciais,
  ISNULL(us.inactivo, 0) AS inactivo,
  CASE WHEN LTRIM(RTRIM(us.u_portalph)) = '' THEN 0 ELSE 1 END AS tem_hash
FROM dbo.us us WITH (NOLOCK)
WHERE ISNULL(us.inactivo, 0) = 0;
```

Se `u_portalph` não existir → parar e criar o campo no PHC (ver `sql/001_user_fields.md`).

### Passo 3 — Executar o script da vista

1. Abrir o ficheiro `sql/010_create_view_HCA_utilizadores.sql`.
2. Confirmar que a ligação aponta para a BD **UAT**.
3. Executar o script completo (`CREATE OR ALTER VIEW` + `GO`).

### Passo 4 — Validar a vista

```sql
-- A vista existe?
SELECT OBJECT_SCHEMA_NAME(object_id) AS sch, name
FROM sys.views
WHERE name = 'view_HCA_utilizadores';

-- Ler dados (sem expor em UI — só teste)
SELECT TOP 20
  userstamp,
  login,
  nome,
  usrinis,
  CASE WHEN LTRIM(RTRIM(portal_hash)) = '' THEN 0 ELSE 1 END AS tem_hash
FROM dbo.view_HCA_utilizadores
ORDER BY login;
```

Critérios de sucesso:

- A vista existe em `dbo`.
- Só aparecem utilizadores ativos.
- Colunas: `userstamp`, `login`, `nome`, `usrinis`, `portal_hash`.

### Passo 5 — Permissão da conta da aplicação (UAT)

Conceder `SELECT` na vista ao login SQL do portal (ajustar o nome do utilizador):

```sql
-- Exemplo — substituir [portal_app] pelo user SQL real
GRANT SELECT ON dbo.view_HCA_utilizadores TO [portal_app];
```

### Passo 6 — Registar no checklist

Marcar em [`phc-installation-checklist.md`](./phc-installation-checklist.md):

- [x] Criar `view_HCA_utilizadores` (UAT) — **feito** 2026-08-10
- [x] Validar `SELECT` na vista (UAT)
- [ ] Repetir em Produção — **só quando a implementação estiver completa**

---

## 6. Repetir em Produção (no fim da implementação)

**Política do projeto:** não executar scripts na BD oficial até a implementação estar completa. Até lá, trabalhar só em UAT/teste.

Usar **o mesmo script** versionado:

`sql/010_create_view_HCA_utilizadores.sql`

Ordem em Produção (quando for altura):

1. Confirmar `US.u_portalph` em Produção.
2. Executar o script na BD de Produção.
3. Validar com os mesmos `SELECT`s de teste (sem copiar hashes para tickets).
4. `GRANT SELECT` ao user SQL de Produção.
5. Atualizar checklist (coluna OK Prod).

**Não** alterar o script entre UAT e Produção, salvo correção versionada no repositório.

---

## 7. O que esta vista não faz

- Não autentica no Entra (isso é a API + MSAL).
- Não cria cookie/sessão.
- Não escreve em `US`.
- Não usa JWT Bearer nas APIs de negócio.

Lookup de login: `sp_HCA_validar_login` (exceção técnica) — ver catálogo SQL e [`auth-microsoft-entra.md`](./auth-microsoft-entra.md).

---

## 8. Script oficial

```sql
CREATE OR ALTER VIEW dbo.view_HCA_utilizadores
AS
SELECT
    us.usstamp AS userstamp,
    LTRIM(RTRIM(us.usercode)) AS login,
    LTRIM(RTRIM(us.username)) AS nome,
    LTRIM(RTRIM(us.iniciais)) AS usrinis,
    us.u_portalph AS portal_hash
FROM dbo.us us WITH (NOLOCK)
WHERE ISNULL(us.inactivo, 0) = 0;
GO
```

Ficheiro: [`../sql/010_create_view_HCA_utilizadores.sql`](../sql/010_create_view_HCA_utilizadores.sql)

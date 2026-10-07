# Segurança e Permissões

> **Emenda 2026-09-29:** autenticação actual = **ASP.NET Identity** (`u_HcaLogi*`) + gate `US.u_usaPort` — ver [`auth-portal-identity.md`](./auth-portal-identity.md).  
> O texto abaixo descreve o modelo **0B histórico** (login directo via `US.u_portalph`). Mantém-se para auditoria; **não** usar como guia de auth de hoje.  
> SoT operacional: [`PROJECT-STATE.md`](./PROJECT-STATE.md).

| | |
| --- | --- |
| Projeto | Liliana & Seródio — Portal de Logística e B2B |
| Fonte | [ARCHITECTURE.md](../ARCHITECTURE.md) |
| Identidade actual | Identity `u_HcaLogi*` + gate PHC `US.u_usaPort` |
| Identidade 0B (histórico) | PHC **`US`** + `u_portalph` |
| Autenticação | Cookie Identity — **sem** JWT / Bearer na interface |
| MVP | Login cookie · logística · Admin Identity · diagnóstico (opcional) |
| Fora do MVP ativo | JWT · refresh · RN-019 · perfis além de Admin · `U_PORTALAUDIT` · AD / Entra · Cash & Carry |

---

## Separação de responsabilidades

| PHC (`US`) | Portal |
| --- | --- |
| Fonte de identidade | Autenticar (utilizador + password vs `u_portalph`) |
| Criar / password | Emitir cookie / sessão web |
| Definição de `u_portalph` | Operação logística (acesso operacional completo no MVP) |
| | Info operacional / diagnóstico simples (opcional) |

**Não:** JWT, `accessToken`, `refreshToken`, Bearer, `/auth/refresh`, `U_PORTALUSER`, `U_PORTALREFRESH`, `U_PORTALCFG`, `U_PORTALAUDIT` (MVP), AD / Entra / Windows Auth.

---

## Gestão de utilizadores

A **gestão de utilizadores PHC** continua na tabela nativa **`US`**.

Para o portal MVP:

- Definir / atualizar `u_portalph` apenas via **PHC / SQL** (não pela UI do portal)
- O portal **não** cria, ativa, desativa nem altera palavras-passe
- O portal **não** tem ecrãs de admin de utilizadores / passwords / perfis / permissões / sessões
- Acesso = `US` existente + `u_portalph` válido + autenticação bem-sucedida

### Campo portal em `US` (obrigatório MVP)

| Campo | Uso |
| --- | --- |
| `u_portalph` | Hash (PasswordHasher / PBKDF2) — **único** campo portal MVP em `US` |

### Não criar no MVP

| Campo / tabela | Estado |
| --- | --- |
| `u_portalperfil` | **Não criar** — perfis = futuro/condicional |
| `u_portalativo` / `u_portalfalhas` / `u_portallockuntil` | **Não criar** — **RN-019** = melhoria futura |
| `U_PORTALAUDIT` | **Não criar** no MVP — melhoria futura |
| `U_PORTALUSER` / `U_PORTALREFRESH` / `U_PORTALCFG` | **Não criar** |
| `CL.u_portalactive` | **Não criar** no MVP — possível futuro Fase 2 (Portal Cliente B2B) |

---

## Modelo de autenticação (MVP)

| Tema | Decisão |
| --- | --- |
| Fonte de identidade | Tabela nativa PHC `US` |
| Credencial | Utilizador em `US` + password verificada contra `u_portalph` |
| Sessão | **Cookie / sessão web** após login |
| Tokens na interface | **Não** — sem `accessToken` / `refreshToken` / JWT |
| Cabeçalho Bearer | **Não** — autenticação = credenciais de cookie |
| Logout | Limpa cookie / sessão (`POST /auth/logout`) |
| `/auth/refresh` | **Não existe** |
| Perfil na resposta | **Não** — só `login` / `nome` |

Resposta de login:

```json
{
  "utilizador": {
    "login": "JLOPES",
    "nome": "João Lopes"
  }
}
```

> Resposta HTTP inclui **Set-Cookie** (sessão). Sem `accessToken`, `refreshToken`, `expiresAt`, `perfil`, `role` ou `permissions`.

Endpoints: `POST /auth/login` · `POST /auth/logout` · `GET /auth/me`.  
**Não existe** `POST /auth/refresh`.

---

## Acesso operacional MVP (sem matriz de perfis)

No MVP **não** há perfis obrigatórios (`Operador` / `Supervisor` / `Administrador`) nem matriz de permissões por perfil.

**Todos os utilizadores autenticados** têm acesso operacional completo, incluindo:

- Painel, encomendas, ajuste qtt/preço (RN-020/021)
- Quantidade autorizada, ultrapassar o restante
- Pré-visualizar e **confirmar** alocação proporcional
- Diagnóstico operacional (se o ecrã de Administração existir)

Restrições por perfil / políticas por perfil = **futuro** (condicional).

### Cliente (Fase 2 — futuro)

Self-service B2B: registo QR (RN-017), catálogo, encomendas, faturas — identidade cliente a definir na Fase 2. **Portal Cliente = Fase 2.**

### Cash & Carry (futuro)

Capacidade futura. Um portal Cash & Carry futuro **pode usar um modelo de autenticação diferente**, a definir mais tarde — **não** desenhar auth C&C no MVP.

---

## Políticas ASP.NET Authorization (MVP)

```csharp
options.FallbackPolicy = new AuthorizationPolicyBuilder()
    .RequireAuthenticatedUser()
    .Build();

// Sem políticas por perfil no MVP — utilizador autenticado = acesso operacional completo.
// Políticas "PodeUltrapassarAutorizacao" / "PodeConfirmarAlocacao" / perfis = futuro.
```

---

## Regras de segurança

### Armazenamento de palavras-passe

- PasswordHasher ASP.NET **ou** PBKDF2 em `US.u_portalph`
- Nunca em texto simples
- **Alteração de palavras-passe no MVP:** PHC / SQL (formato de hash compatível com o portal)

### Cookie / sessão (MVP)

| Parâmetro | Valor |
| --- | --- |
| Tipo | Cookie / sessão web após login |
| Tokens JWT | **Não** |
| Refresh | Não |
| Logout | Servidor limpa cookie/sessão |
| HTTPS | Obrigatório em UAT/Produção (cookie Secure) |

### Bloqueio de conta — **RN-019** (melhoria futura)

**Não ativo no MVP.** Não criar `u_portalfalhas` / `u_portallockuntil` / `u_portalativo` para o MVP.  
Quando implementado no futuro: tipicamente 5 falhas → bloqueio 15 min.

### Auditoria (MVP)

**Camada nativa PHC:** em alterações de `qtt` / `edebito`, atualizar `usrinis` / `usrdata` / `usrhora` em `BI` e `BO`.  
**Nunca** alterar `ousr*`.

**Camada portal:** **sem** `U_PORTALAUDIT` obrigatório no MVP.

> A consulta de auditoria detalhada é uma melhoria futura. No MVP, a auditoria operacional é assegurada pelos campos nativos PHC `usr*` em `BO` e `BI`.

Também no MVP:

- Originais `u_qttorig` / `u_prcorig` na 1.ª alteração (quando `= 0`; campos `NOT NULL`)
- Alteração de quantidade autorizada (`u_qtdaut`, `u_qtdautur`, `u_qtdautdt` — valores base = ainda sem autorização)

### Outras regras

- Sem AD / Entra ID / IdP externos / Windows Auth
- Sem JWT / Bearer / refresh tokens
- HTTPS em UAT e Produção (**IIS on-premises**)
- Secrets fora do código (connection string, data protection keys — variáveis de ambiente IIS / config protegida)
- Login SQL com permissões mínimas (`SELECT` em `view_HCA_*`, `EXECUTE` em `sp_HCA_*`)
- Dapper parametrizado (`SELECT` em `view_HCA_*` / `EXECUTE` em `sp_HCA_*` — sem SQL direto a tabelas base)
- Exceção técnica: `sp_HCA_validar_login` encapsula a validação de login contra `US` (não é escrita de negócio)
- Rate limiting em `/auth/login` e (Fase 2) `/publico/registo/iniciar`

Detalhe de implantação: [`deployment-architecture.md`](./deployment-architecture.md).

---

## Checklist de revisão de segurança (go-live MVP)

| # | Controlo | Estado esperado |
| --- | --- | --- |
| 1 | Passwords com hasher / PBKDF2 em `US.u_portalph` | Cumprido |
| 2 | Auth = cookie / sessão (sem JWT / Bearer / tokens na interface) | Cumprido |
| 3 | RN-019 **não** exigido no MVP (melhoria futura) | Cumprido |
| 4 | Acesso = `US` + hash válido + login OK | Cumprido |
| 5 | Rotas internas exigem cookie/sessão autenticada | Cumprido |
| 6 | Sem matriz de perfis obrigatória no MVP | Cumprido |
| 7 | Auditoria nativa = `usr*` em BO/BI (sem `U_PORTALAUDIT` obrigatório) | Cumprido |
| 8 | Sem IdP externos / Windows Auth | Cumprido |
| 9 | TLS e secrets por ambiente | Cumprido |
| 10 | Nenhuma rota Cash & Carry exposta no MVP | Cumprido |
| 11 | Sem ecrãs/API de manutenção de utilizadores no portal | Cumprido |
| 13 | Conta SQL: `SELECT` em `view_HCA_*` e `EXECUTE` em `sp_HCA_*` (sem SQL direto a tabelas base) | Cumprido |

---

*MVP: PHC US = identidade; portal = cookie/sessão + operação logística; sem JWT; sem perfis/RN-019/`U_PORTALAUDIT` obrigatórios.*

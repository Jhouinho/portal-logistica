# Passo a passo — colocar o Portal no servidor do cliente

| | |
| --- | --- |
| Projecto | Liliana & Seródio — Portal de Logística |
| Modelo | Windows Server + IIS + .NET 8 + SQL Server PHC (on-premises) |
| SoT operacional | [`PROJECT-STATE.md`](./PROJECT-STATE.md) |
| Topologia | [`deployment-architecture.md`](./deployment-architecture.md) |
| Actualizado | 2026-10-09 |
| Go-live (definição OK + preparação) | [`GO_LIVE_SEMANA.md`](./GO_LIVE_SEMANA.md) |

**Objectivo:** checklist operacional para a **primeira** instalação em produção (ou cópia UAT → Prod).  
**Não** executar em produção o script de seed de testes `sql/090_seed_clone_encomendas_teste.sql`.

---

## 0. Antes de ir ao cliente (checklist)

| # | Pedir / preparar | Notas |
| --- | --- | --- |
| 0.1 | Acesso RDP (ou consola) ao Windows Server do portal | Conta local/domínio com direitos de instalar IIS / Hosting Bundle |
| 0.2 | Acesso à BD PHC de **produção** (SSMS) | Preferir login admin só para aplicar scripts; depois `portal_app` |
| 0.3 | Nome DNS / URL do portal | Ex.: `https://portal.cliente.local` |
| 0.4 | Certificado TLS | Interno ou público; HTTPS obrigatório (cookies / SignalR) |
| 0.5 | Confirmar séries PHC | Encomendas `ndos=1`, picking `66`, expedição `65` (defaults do Portal) |
| 0.6 | Confirmar Kapps / Syslog | Circuito 1→66→65 já usado no armazém |
| 0.7 | Pacote de release | Código actual: [github.com/Jhouinho/portal-logistica](https://github.com/Jhouinho/portal-logistica) |
| 0.8 | Máquina de **build** | .NET 8 SDK + Node.js 20+ (pode ser o teu PC; o servidor só precisa do Hosting Bundle) |
| 0.9 | Backup PHC agendado / feito **antes** dos scripts | Obrigatório |

Topologia alvo:

```text
Browser  →  https://portal… (IIS)
              ├── /          → React (ficheiros estáticos)
              ├── /api/...   → API .NET 8  (ou site portal-api separado)
              └── /hubs/...  → SignalR (WebSockets)
                    ↓
              SQL Server PHC (rede interna :1433)
```

Recomendação simples em produção: **um site IIS** com a SPA na raiz e a API como **aplicação** `/api` **ou** dois sites (`portal-web` + `portal-api`) no mesmo host com CORS.  
A opção mais simples para cookies/SignalR: **mesmo origin** (SPA na raiz + reverse proxy `/api` e `/hubs` para a API, ou API no mesmo site).

---

## 1. Backup e janela

1. Pedir backup completo da BD PHC (ou snapshot acordado com IT).  
2. Confirmar RTO/RPO e contacto se algo falhar.  
3. Preferir janela fora de pico (aplicação de campos `U_*` + scripts).

---

## 2. Campos do utilizador no PHC (Supervisor)

Criar / confirmar campos no **PHC CS Desktop → Supervisor → Framework → Campos do utilizador** e **Actualizar a Tabela**.  
Referência: [`sql/001_user_fields.md`](../sql/001_user_fields.md) e checklist histórico em [`phc-installation-checklist.md`](./phc-installation-checklist.md).

Mínimo típico (confirmar o que já existe em UAT e **replicar** em Prod):

| Área | Exemplos |
| --- | --- |
| `US` | `u_usaPort` (bit/flag acesso portal) |
| `BI` / `BI2` | `u_qtdaut`, `u_qtdautur`, `u_qtdautdt`, `u_qttorig`, `u_prcorig`, `u_previd`, `u_cor`, … |
| `BO` / `BO2` / `BO3` | `u_mEntrega`, `u_modExp`, `u_chkin`, `u_chkinur`, `u_chkindt`, `u_pickrdy`, `u_pickstat`, `u_urgente`, … |
| `STOBS` | `u_dispPort` (universo Portal) |

**Regra:** se UAT já tem o circuito a funcionar, exportar lista de campos e aplicar **os mesmos** em Prod — não inventar diferenças.

---

## 3. Objectos SQL na BD PHC

### 3.1 Login SQL da aplicação

1. Criar login/user SQL dedicado (ex. `portal_app`) — **não** usar `sa` em produção.  
2. Dar permissões via scripts `*grant*` / `030_grant_portal_app.sql` (ajustar nome do user se diferente).  
3. Connection string (exemplo):

```text
Server=SERVIDOR\INSTANCIA;Database=NOME_BD_PHC;User Id=portal_app;Password=***;TrustServerCertificate=True;Encrypt=True;
```

### 3.2 Ordem de aplicação dos scripts

Na pasta `sql/`, aplicar por ordem numérica os scripts de **criação/alteração** (`create` / `alter` / `add` / `migrate` / `grant` / `seed_role`).

**Saltar em produção:**

| Padrão | Motivo |
| --- | --- |
| `*_validate_*.sql`, `*_validate_*.sql` | Só diagnóstico |
| `023a_discover_*` | Discovery |
| `090_seed_clone_encomendas_teste.sql` | **Dados de teste — NÃO** |
| `sql/_tmp_*` | Temporário |
| Scripts com `DryRun` de clone | Nunca em Prod |

Ordem resumida (blocos):

1. **Campos / US** — `028` (`u_usaPort`), restantes campos via Supervisor se ainda não existirem.  
2. **Vistas base** — `010`, `012`, `014`, `016`, `018` (+ alters posteriores `034`, `037`, `039`, `042`, `043`, `044`, `046`, `049`, `054`, `055`, `061`, …).  
3. **SPs base** — `020`…`027`, picking `038`…`058`, check-in `059`/`060`, previsões `062`…`086`.  
4. **Identity** — `029` (tabelas `u_HcaLogi*`), `033` (role Admin).  
5. **Grants** — `030`, `052`, `059b`, `060b`, `063b`, `065b`, `076b`, `083b`, …  

Se a BD de Prod for **cópia recente de UAT** onde o Portal já corre: comparar objectos em falta e aplicar **só o delta** (mais seguro). Se for BD “limpa” de campos portal: aplicar a cadeia completa como em UAT.

### 3.3 Kapps (PHC)

Confirmar em Prod a personalização `SP_u_Kapps_DossiersUSR` (cópia `u_mEntrega` / `u_modExp` 1→66→65) se já estiver em UAT — ver `PROJECT-STATE.md`.

---

## 4. Preparar o Windows Server

1. Windows Server 2022+ (ou o que o cliente tiver, com suporte .NET 8).  
2. Instalar função **Web Server (IIS)** + **WebSocket Protocol** (SignalR).  
3. Instalar **ASP.NET Core 8 Hosting Bundle** ([download Microsoft](https://dotnet.microsoft.com/download/dotnet/8.0)).  
4. Reiniciar IIS após o Hosting Bundle: `iisreset`.  
5. Criar pastas, por exemplo:

```text
C:\inetpub\portal\web
C:\inetpub\portal\api
C:\inetpub\portal\dp-keys
```

6. Dar permissão de escrita à identidade do App Pool em `dp-keys` (Data Protection dos cookies).

---

## 5. Build na máquina de desenvolvimento / CI

**Modelo validado no PC local (IIS :8088):** API + SPA no **mesmo site** (`wwwroot` + `MapFallbackToFile`) — cookies e SignalR sem CORS entre portas.

### 5.0 Atalho (recomendado)

No teu PC (já ensaiado):

```powershell
Set-Location -LiteralPath "...\Liliana&Serodio"   # ou clone portal-logistica
.\tools\publish-release.ps1 -Zip
```

Isto gera `releases\portal-AAAAAMMDD-HHMM\` (+ `.zip`) com API + SPA, `web.config` em Production e `appsettings.Production.TEMPLATE.json` (**sem** passwords).

No servidor:

```powershell
# 1) Extrair zip → C:\inetpub\portal\api
# 2) Copiar TEMPLATE → appsettings.Production.json e preencher connection string / URL
# 3) IIS (Admin):
.\tools\iis-install-site.ps1 -PhysicalPath 'C:\inetpub\portal\api' -Port 80 -SiteName Portal
# ou HTTPS com host header / binding no IIS Manager
```

Ensaio local: [`LOCAL_IIS.md`](./LOCAL_IIS.md).

### 5.1 Manual (equivalente)

```powershell
# Frontend
Set-Location .\src\frontend
npm ci
npm run build

# API
Set-Location ..\backend
dotnet publish .\src\Portal.Api\Portal.Api.csproj -c Release -o C:\inetpub\portal\api
Copy-Item ..\frontend\dist\* C:\inetpub\portal\api\wwwroot\ -Recurse -Force
```

**Não** uses dois sites/portas em HTTP sem HTTPS: cookies (`SameSite=Lax`) falham entre origins.

---

## 6. Configuração da API no servidor

Criar `C:\inetpub\portal\api\appsettings.Production.json` (ou variáveis de ambiente IIS) — **não** meter passwords no Git:

```json
{
  "Phc": {
    "ConnectionString": "Server=...;Database=...;User Id=portal_app;Password=***;TrustServerCertificate=True;Encrypt=True;",
    "SerieEncomendasNdos": 1,
    "SeriePickingNdos": 66,
    "SerieSeparacaoNdos": 65
  },
  "DataProtection": {
    "KeysPath": "C:\\inetpub\\portal\\dp-keys"
  },
  "Portal": {
    "SpaBaseUrl": "https://portal.cliente.local"
  },
  "Cors": {
    "Origins": [ "https://portal.cliente.local" ]
  },
  "AllowedHosts": "portal.cliente.local"
}
```

Notas:

- `ASPNETCORE_ENVIRONMENT=Production` no App Pool / `web.config`.  
- Swagger desligado ou inacessível de fora.  
- Connection string e keys **fora** do repositório.

---

## 7. IIS — sites e App Pools

### 7.1 API

1. App Pool `PortalApiAppPool`: **No Managed Code**, .NET CLR = No Managed Code.  
2. Site ou aplicação apontando a `C:\inetpub\portal\api`.  
3. Binding HTTPS :443 com o certificado.  
4. Confirmar que o `web.config` do publish tem o ASP.NET Core Module.  
5. WebSockets **enabled** no site (SignalR).

### 7.2 SPA

1. Site apontando a `C:\inetpub\portal\web`.  
2. URL Rewrite — fallback SPA (exemplo `web.config` na raiz do web):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <system.webServer>
    <rewrite>
      <rules>
        <rule name="SPA" stopProcessing="true">
          <match url=".*" />
          <conditions logicalGrouping="MatchAll">
            <add input="{REQUEST_FILENAME}" matchType="IsFile" negate="true" />
            <add input="{REQUEST_FILENAME}" matchType="IsDirectory" negate="true" />
            <add input="{REQUEST_URI}" pattern="^/(api|hubs|health)" negate="true" />
          </conditions>
          <action type="Rewrite" url="/index.html" />
        </rule>
      </rules>
    </rewrite>
  </system.webServer>
</configuration>
```

### 7.3 Mesmo host: proxy `/api` e `/hubs` (se SPA e API em pastas distintas)

Usar Application Request Routing (ARR) + URL Rewrite para encaminhar `/api/*` e `/hubs/*` para o site da API interna, **ou** publicar a API como aplicação virtual `/api` no mesmo site (ajustar path base da API se necessário).

Validar:

```text
GET https://portal…/health
GET https://portal…/   → index.html
```

---

## 8. Utilizadores do Portal

1. Em `US` (PHC): utilizador activo, email preenchido, **`u_usaPort = 1`**.  
2. Criar conta Identity (mesma máquina com .NET SDK ou no servidor):

```powershell
$env:Phc__ConnectionString = "Server=...;Database=...;User Id=portal_app;Password=...;TrustServerCertificate=True;"
dotnet run --project .\tools\criar-utilizador-portal -- "email@cliente.pt" "PasswordTemporaria!"
```

3. Login no browser com esse email/password.  
4. Admin: role `Admin` (`sql/033`) para gestão de utilizadores no ecrã Administração.

Detalhe: [`auth-portal-identity.md`](./auth-portal-identity.md) · [`tools/criar-utilizador-portal/README.md`](../tools/criar-utilizador-portal/README.md).

---

## 9. Smoke test no cliente (30–45 min)

| # | Teste | Resultado esperado |
| --- | --- | --- |
| 9.1 | HTTPS sem aviso crítico | Certificado OK |
| 9.2 | Login / logout | Cookie; `GET /api/v1/auth/me` |
| 9.3 | Centro `/` | 5 KPIs + painéis |
| 9.4 | Vista TV `/tv` (sem login, outro browser) | Mesmos KPIs; actualiza ~30 s |
| 9.5 | Em Aberto — lista + detalhe | Autorizada / Disponível |
| 9.6 | Marcar pronta picking (doc de teste) | Aparece em Em Picking |
| 9.7 | Após Kapps/Syslog 66 | Separado; Centro «em progresso» se Kapps em curso |
| 9.8 | Check-in + A Preparar Entrega | `u_chkin`; Voltar ao Separado |
| 9.9 | SignalR | Alterar dossier 66 noutro sítio → lista refresca sem F5 (até ~5 s) |
| 9.10 | Logs | Event Viewer + pasta logs da API sem passwords |

---

## 10. Pós go-live

| Item | Acção |
| --- | --- |
| Backup | Incluir `C:\inetpub\portal` + `dp-keys` + BD PHC |
| Contas | Forçar troca de passwords temporárias |
| Previsão | Criar 1ª previsão de entrada aberta (Administração) se o fluxo de autorização depender dela |
| Monitorização | Disco de logs; App Pool recycling acordado |
| Rollback | Repor pasta `api`/`web` anterior + scripts SQL só se IT tiver backup pontual |

---

## 11. Problemas frequentes

| Sintoma | Verificar |
| --- | --- |
| 500.19 / 502.5 na API | Hosting Bundle .NET 8; `iisreset`; App Pool No Managed Code |
| Login OK mas APIs 401 | Cookie Secure + HTTPS; CORS/origem; `SpaBaseUrl` |
| TV sem dados | `/api` público nos GETs TV; hub `/hubs/tv`; WebSockets |
| SignalR falha | Protocolo WebSocket no IIS; proxy `/hubs` |
| SQL permission denied | Grants `030` + `*b_grant*`; user `portal_app` |
| Disponível / Autorizada estranho | Previsão aberta; scripts `068`/`082`/`061` |
| Logo em falta | Normal no repo público — UI usa texto |

---

## 12. Ordem do dia no cliente (resumo de 1 página)

```text
1. Backup PHC
2. Campos U_* (Supervisor) — espelho UAT
3. Scripts SQL (sem 090) + grants + portal_app
4. IIS + Hosting Bundle + WebSockets + pastas + dp-keys
5. Publish API + build SPA → copiar
6. appsettings.Production + certificado HTTPS
7. criar-utilizador-portal + u_usaPort=1
8. Smoke 9.1–9.10
9. Entregar URLs: portal + /tv  |  contactos IT
```

---

## Referências

| Documento | Uso |
| --- | --- |
| [`deployment-architecture.md`](./deployment-architecture.md) | Topologia, portas, TLS, DR |
| [`PROJECT-STATE.md`](./PROJECT-STATE.md) | O que está validado / o que não fazer |
| [`auth-portal-identity.md`](./auth-portal-identity.md) | Identity + `u_usaPort` |
| [`sql/002_views_and_procedures.md`](../sql/002_views_and_procedures.md) | Catálogo views/SPs |
| [`sql/001_user_fields.md`](../sql/001_user_fields.md) | Campos utilizador |

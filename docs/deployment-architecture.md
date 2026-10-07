# Arquitetura de Implantação

> **Emenda 2026-09-29:** topologia IIS/.NET 8 mantém-se. Hubs SignalR em produção: `/hubs/operacoes` (auth) e `/hubs/tv` (anónimo). Estado: [`PROJECT-STATE.md`](./PROJECT-STATE.md).

| | |
| --- | --- |
| Projeto | Liliana & Seródio — Portal de Logística e B2B |
| Fonte | [ARCHITECTURE.md](../ARCHITECTURE.md) |
| Modelo oficial | **On-premises** |
| Data | 2026-08-10 (emenda hubs 2026-09-29) |

---

## Objetivo

Descrever a arquitetura de implantação em produção do portal, alinhada com a decisão de infraestrutura final:

**Windows Server + IIS + ASP.NET Core .NET 8 + SQL Server (PHC CS)**

Este é o modelo primário. Kubernetes, Azure App Service e implantação cloud-native **não** são arquitetura alvo. Cloud pode ser mencionada apenas como possibilidade futura.

---

## Infraestrutura alvo

| Componente | Requisito |
| --- | --- |
| Sistema operativo | Windows Server 2022 ou superior |
| Servidor web | IIS 10+ |
| Runtime API | ASP.NET Core Runtime / Hosting Bundle **.NET 8** |
| Interface | React SPA (compilação estática) |
| Base de dados | Microsoft SQL Server (base PHC CS existente) |
| Rede | SQL Server na rede interna; portal tipicamente na LAN / VPN |

---

## Topologia

```
React SPA
        ↓
IIS (HTTPS :443)
        ↓
ASP.NET Core .NET 8 API
        ↓
SQL Server PHC (rede interna :1433)
```

| Camada | Responsabilidade |
| --- | --- |
| React SPA | Interface; login Identity (email/password); sessão por cookie; ficheiros estáticos IIS |
| IIS | TLS, sites web/API, ASP.NET Core Module, rewrite HTTP→HTTPS |
| API .NET 8 | Cookie/sessão, regras de apresentação, Dapper → `view_HCA_*` / `sp_HCA_*`, SignalR |
| SQL Server | Dados PHC + `US.u_portalph` + campos `U_*` + objetos `view_HCA_*` / `sp_HCA_*` |

---

## Requisitos mínimos

### Instalação pequena

| Recurso | Valor |
| --- | --- |
| vCPU | 4 |
| RAM | 8 GB |
| Disco | 100 GB SSD |

### Recomendado

| Recurso | Valor |
| --- | --- |
| vCPU | 8 |
| RAM | 16 GB |
| Disco | SSD (capacidade conforme logs e retenção) |

> O servidor SQL PHC pode ser o mesmo host ou (preferível) um SQL Server dedicado já existente. Dimensionar RAM/CPU do SQL segundo a carga PHC + portal.

---

## Software necessário

| Software | Notas |
| --- | --- |
| Windows Server 2022+ | Com atualizações de segurança |
| Função **Web Server (IIS)** | Incluir ASP.NET / gestão de certificados conforme necessidade |
| **ASP.NET Core 8 Hosting Bundle** | Obrigatório para anfitriar a API no IIS |
| Node.js (apenas build) | Máquina de CI ou de publicação — não obrigatório no servidor de produção se o build for feito noutro sítio |
| Acesso de rede ao SQL Server | Drivers / conectividade TCP 1433 interna |
| Certificado TLS | Válido para o nome público/interno do portal |

---

## Estrutura IIS

Exemplo de organização:

```
Default Web Site (ou sites dedicados)
├── portal-web     → interface React
└── portal-api     → API ASP.NET Core
```

### Caminhos físicos (exemplo)

```
C:\inetpub\portal\web
C:\inetpub\portal\api
```

### Application Pool

| Site | Pool | Identidade | Notas |
| --- | --- | --- | --- |
| portal-api | `PortalApiAppPool` | ApplicationPoolIdentity ou conta de serviço dedicada | Sem managed pipeline clássico; “No Managed Code” + Hosting Bundle |
| portal-web | `PortalWebAppPool` | ApplicationPoolIdentity | Site estático; URL Rewrite para SPA (`index.html`) |

Recomenda-se **dois sites** (ou site + aplicação) para isolar ciclos de publicação interface/servidor.

---

## Publicação da interface

1. Em máquina de build: `npm ci` / `npm install`  
2. Configurar URL da API de produção (variáveis de ambiente / ficheiro de config do build)  
3. `npm run build`  
4. Copiar o conteúdo de `dist/` (ou `build/`) para `C:\inetpub\portal\web`  
5. Configurar IIS para SPA: redirecionamento para `index.html` em rotas do lado do cliente  
6. Validar HTTPS e carregamento dos assets  

---

## Publicação da API

1. `dotnet publish -c Release -o .\publish` (ou pipeline CI)  
2. Copiar output para `C:\inetpub\portal\api`  
3. Garantir `web.config` gerado pelo SDK (ASP.NET Core Module)  
4. Configurar **appsettings** / variáveis de ambiente / User Secrets equivalentes em produção:
   - Connection string SQL  
   - Data Protection / cookie session keys  
   - Defaults de corte / `SerieEncomendasNdos`  
   - CORS (origem do `portal-web`, com credenciais)  
5. Reciclar o Application Pool  
6. Validar `GET /health` (ou rota de saúde configurada)  

---

## TLS / HTTPS

| Regra | Valor |
| --- | --- |
| HTTPS | **Obrigatório** |
| Porta | **443** |
| Certificado | Válido (não usar certificados autoassinados em produção sem acordo IT) |
| HTTP | Porta **80** apenas para redirect permanente para HTTPS |

---

## Portas

| Porta | Uso | Exposição |
| --- | --- |
| 80 | HTTP → redirect HTTPS | Interna / perimetral conforme política |
| 443 | HTTPS (portal web + API) | Utilizadores do portal |
| 1433 | SQL Server | **Apenas rede interna** — nunca Internet |

---

## Segurança

### Autenticação

A aplicação autentica com **ASP.NET Core Identity** (tabelas `u_HcaLogi*` na BD PHC). Após password OK, exige `US` activo com **`u_usaPort = 1`** e o mesmo email. Cookie de sessão (`ls_portal_auth`).

**Não utilizar (MVP):**

- JWT Bearer / `accessToken` / `refreshToken` na UI  
- `/auth/refresh`  
- Microsoft Entra / MSAL como login  
- Windows Authentication no pipeline IIS do portal  

**MVP:** logout = `POST /auth/logout`. Criar utilizadores Identity: [`tools/criar-utilizador-portal`](../tools/criar-utilizador-portal/README.md). Doc: [`auth-portal-identity.md`](./auth-portal-identity.md).

### Outros controlos

- Connection string e chaves de Data Protection **fora** do repositório (variáveis de ambiente IIS / ficheiro protegido no servidor)
- Login SQL dedicado com permissões mínimas
- CORS alinhado à origem da interface (com credenciais)
- Swagger desativado ou protegido em produção
- Contas de serviço IIS com privilégios mínimos no filesystem

---

## Base de Dados

| Tema | Prática |
| --- | --- |
| Ligação | SQL Server PHC CS (mesma BD; sem BD de aplicação separada) |
| Segredo | Connection string armazenada fora do código |
| Autenticação SQL | Login dedicado (não `sa`) |
| Permissões | `SELECT` em `view_HCA_*`; `EXECUTE` em `sp_HCA_*`; preferir **sem** acesso direto a `BO`/`BI`/`ST`/`CL`/`US` pela aplicação; UPDATE de `u_portalph` só no arranque/SQL |
| Rede | Servidor de aplicação → SQL apenas na LAN |

Detalhe de permissões: [`phc-installation-checklist.md`](./phc-installation-checklist.md).

---

## Backups

| Item | Frequência / âmbito |
| --- | --- |
| Backup SQL Server | **Diário** (e conforme política PHC existente) |
| Incluir sempre | Dados PHC incluindo `US` (`u_portalph`) e campos `U_*` de logística |
| Ficheiros IIS | Incluir no backup de filesystem / imagem do servidor (web + api + config) |
| Segredos | Backup seguro separado (connection strings, data protection) — não no Git |

---

## Monitorização

| Fonte | Uso |
| --- | --- |
| Serilog (ficheiros / sink acordado) | Logs da API (sem passwords) |
| Windows Event Viewer | Erros do IIS / ASP.NET Core Module |
| Health checks | Disponibilidade da API e conectividade SQL |
| Disco | Rotação/retenção de logs |

---

## Disaster Recovery

Procedimento resumido:

1. Restaurar backup SQL Server (BD PHC incluindo `US` e campos portal)  
2. Restaurar publicação IIS (`portal-web` + `portal-api`) ou redeploy a partir do artefacto de release  
3. Validar connection string, Data Protection, appsettings (corte/`ndos`)  
4. Validar HTTPS / certificado  
5. Testar login (cookie/sessão), Painel Principal e uma operação de autorização  
6. Validar SignalR (dois browsers) se usado em produção  

RTO/RPO: definir com IT do cliente (alinhado à política PHC).

---

## Ambientes

| Ambiente | Hospedagem típica |
| --- | --- |
| Desenvolvimento | Local (Visual Studio / `dotnet run` + Vite) |
| UAT | Windows Server + IIS (espelho de produção, BD UAT) |
| Produção | Windows Server + IIS + SQL Server PHC |

---

## Possibilidade futura (não alvo atual)

Migração para cloud (IaaS Windows, PaaS, etc.) pode ser avaliada mais tarde. **Não** altera o desenho atual: on-premises IIS permanece a arquitetura oficial.

> Cash & Carry futuro: um portal C&C **pode usar um modelo de autenticação diferente**, a definir mais tarde — não desenhar auth C&C no MVP.

---

## Referências

- [ARCHITECTURE.md](../ARCHITECTURE.md) §1.6  
- [phc-installation-checklist.md](./phc-installation-checklist.md)  
- [security-permissions.md](./security-permissions.md)  

---

*Documento de implantação pronto para produção on-premises.*

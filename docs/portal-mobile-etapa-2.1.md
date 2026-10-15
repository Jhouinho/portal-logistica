# Portal Mobile — Etapa 2.1

| | |
| --- | --- |
| Projeto | Liliana & Seródio — Portal Mobile de Encomendas |
| Documento | Acta técnica + mapa de bloqueadores + checklist PHC |
| Idioma | Português de Portugal |
| Estado | Requisitos funcionais consolidados em documento dedicado; este ficheiro = acta técnica + checklist PHC; **produção não autorizada** |
| Actualizado | 2026-10-15 |

> **Requisitos funcionais (SoT):** [`portal-mobile-requisitos-funcionais.md`](./portal-mobile-requisitos-funcionais.md) — versão de consolidação 2026-10-15.  
> Este documento (Etapa 2.1) mantém a **acta técnica**, bloqueadores e checklist PHC. Onde houver conflito funcional, prevalece o documento de requisitos.  
> **Não** substitui [`PROJECT-STATE.md`](./PROJECT-STATE.md) para o Portal Logístico operacional.  
> **Não** autoriza alterações a código ou BD de **produção**. Trabalho UAT SQL já existente (ex. SP `091`) documenta-se em [`portal-mobile-sp-criar-pedido.md`](./portal-mobile-sp-criar-pedido.md).

---

## 1. Objetivo

Manter o mapa de bloqueadores e a checklist de validação PHC alinhados com os requisitos funcionais consolidados, **sem** implícita autorização de go-live.

---

## 2. Decisões funcionais confirmadas

Resumo alinhado a [`portal-mobile-requisitos-funcionais.md`](./portal-mobile-requisitos-funcionais.md) (detalhe completo nesse documento):

| Tema | Decisão |
| --- | --- |
| Ativação / primeiro acesso | NIF + palavra-passe (se existir); 1.º acesso = validar telemóvel PHC + definir palavra-passe; máx. 5 tentativas de telemóvel; recuperação via NIF + telemóvel; sem SMS; sessão 30 min inactividade. NIF `999999990` (consumidor final) **bloqueado no servidor** (1.º acesso, login e recuperação). NIF localiza ficha mas não é chave única: 0 fichas ou várias fichas distintas → balcão (sem escolha automática); 1 ficha elegível → telemóvel; identidade autenticada = `CL.no` + `CL.estab`. Risco de representação indevida aceite e documentado. Ver requisitos §2.1 e §2.2. |
| Imagens | **Excluídas do MVP.** |
| Preços | Estimativa no portal; validação no balcão. Diferenças tratadas **fora** do portal (colaborador contacta o cliente) — sem fluxos de aprovação no portal. |
| Criação do documento comercial | O colaborador utiliza a funcionalidade **Cópia de Dossier** do PHC. |
| Documento de destino | **Ainda por definir** — não assumir `ndos` concreto até validação PHC. |
| Associação | Campos de origem do dossier de destino, após confirmação dos campos físicos. |
| Fecho do dossier de origem | Processo PHC após a cópia; **fora do âmbito do portal**. |
| Número do pedido | Apresentar o número gerado pelo PHC; campo físico a confirmar. |
| Alojamento | **Mesmo site**, percurso de clientes separado do dos colaboradores. |
| Estados | **No âmbito** desta fase (4 estados UI) — ver requisitos §6. Mapeamento PHC de «Pronto para levantamento» / «Concluído» ainda em aberto. |
| Cancelamento | Só em «Pedido submetido»; ocultar do histórico do portal; **não** apagar o registo PHC só por essa regra. |

### 2.1 Princípios a respeitar

1. O pedido mobile e o documento comercial de destino são **documentos distintos**.
2. A confirmação no balcão **não** cria automaticamente o documento de destino.
3. A associação pedido mobile ↔ destino deve ser persistente e permitir evitar duplicações.
4. Os preços estimados no portal são revalidados no balcão; diferenças **não** geram fluxo no portal (tratamento humano).
5. A sessão do cliente deve permanecer separada da sessão dos colaboradores.
6. O cliente só pode consultar os seus próprios pedidos.
7. A exclusão de imagens aplica-se ao MVP; não impede evolução posterior.
8. NIF + telemóvel / palavra-passe associada admite risco de representação indevida — limitação aceite e documentada.

---

## 3. Fluxo operacional acordado

1. O cliente submete um pedido mobile.
2. O pedido é registado no PHC e o **número gerado** é apresentado ao cliente.
3. O colaborador localiza o pedido através desse número.
4. O colaborador valida artigos e quantidades e confirma os preços no PHC.
5. O colaborador utiliza a **Cópia de Dossier** para criar o documento adequado ao processo.
6. O documento de destino é associado ao pedido mobile através dos **campos de origem** aplicáveis.
7. O fecho do dossier de origem segue o procedimento normal do PHC, **fora** do âmbito do portal.

O tipo exacto do documento de destino **não** está decidido.

---

## 4. Responsabilidades do portal

### 4.1 O portal deverá (conforme mecanismos a validar)

1. Autenticar o cliente e gerir sessão (requisitos §2).
2. Registar o pedido mobile no PHC e apresentar o número gerado.
3. Carrinho, submissão, homepage/histórico e estados (requisitos §3–§6).
4. Cancelamento apenas em «Pedido submetido», sem apagar o registo PHC (requisitos §7).
5. Permitir ao colaborador localizar o pedido (número PHC) no fluxo Desktop.
6. Suportar associação pedido ↔ destino via campos de origem, quando a Cópia de Dossier estiver definida.
7. Prevenir associações / submissões duplicadas (idempotência).

### 4.2 O portal não deverá

- Executar a Cópia de Dossier.
- Criar automaticamente o documento comercial de destino.
- Fechar o dossier de origem.
- Emitir documentos de faturação.
- Gerir diferenças de preço ou ruturas pós-submissão (tratamento humano no balcão).
- Enviar e-mail/SMS de confirmação nesta fase.

---

## 5. Requisitos adiados / em aberto

| Tema | Nota |
| --- | --- |
| Validade temporal do pedido (ex. 2 horas) / expiração automática | Continua fora do âmbito activo. |
| Máquina de estados alargada (Rascunho, Rejeitado, Expirado, …) | Fora do âmbito; a UI usa os **4 estados** dos requisitos §6. |
| Mapeamento PHC de «Pronto para levantamento» e «Concluído» | Em aberto (requisitos §10). |
| Limite máximo de quantidade; recuperação do carrinho no mesmo dia | Em aberto (requisitos §10). |

---

## 6. Mapa de bloqueadores activos

| ID | Bloqueador | Classificação | Dependência |
| --- | --- | --- | --- |
| B01 | `CL2.u_passP`: existência, tipo e características nos metadados PHC (**sem** consultar ou expor hashes) | Por validar | SSMS / Supervisor |
| B02 | Fonte efetiva de preços por cliente e artigo (descontos, IVA) | Por validar | PHC |
| B03 | Tipo de dossier mobile e respetivo `ndos` | UAT: `ndos=67` («Pedido Mobile») observado; **produção / formalização** por validar | Supervisor / PHC |
| B04 | Mecanismo autorizado para o portal criar/registar o dossier mobile | UAT: SP `sp_HCA_criar_pedido_mobile` (`091`); **autorização de produção / API** pendente | PHC / IT |
| B05 | Campo físico que contém o número a apresentar ao cliente | Por validar | PHC |
| B06 | Tipo de documento de destino e configuração da Cópia de Dossier | Por validar / Decisão pendente | Negócio + PHC |
| B07 | Campos de origem que associam o destino ao dossier mobile | Por validar | PHC |
| B08 | Mecanismo para detetar e impedir associações duplicadas | Por validar | PHC + desenho |
| B09 | Separação da sessão e autorização (cliente vs colaborador) | Por validar (desenho) | Arquitectura / código futuro |
| B10 | Revisão dos endpoints `[AllowAnonymous]` existentes no mesmo site | Por validar | Segurança / IIS |

**Nota (repositório):** colaboradores = Identity + `ls_portal_auth`. Clientes = `ls_cliente_auth` + `u_HcaClienteAuth` + `/api/v1/cliente/*` + UI `/cliente/*` (implementação 2026-10-15). SP `091`/`093` com cor em UAT. Cópia de Dossier / estados 3–4 / B05–B08 continuam pendentes. Inventário AllowAnonymous: [`portal-mobile-inventario-etapa0.md`](./portal-mobile-inventario-etapa0.md).

---

## 7. Checklist de validação PHC (modo leitura)

**Regras:** apenas consultas de metadados / observação no Supervisor / leitura de configuração.  
**Proibido nesta fase:** `INSERT`, `UPDATE`, `DELETE`, `ALTER`, migrações, criação de campos/séries/dossiers, gravação de documentos de teste em produção sem autorização explícita à parte.

Ordem recomendada: **C01 → C02 → C03**, depois cópia/associação, depois preços/`CL2`, depois segurança.

| ID | Objetivo | Evidência necessária | Resultado | Pendências | Classificação |
| --- | --- | --- | --- | --- | --- |
| C01 | Identificar o **tipo de dossier mobile** e o valor de **`ndos`** aplicável (sem o criar) | Supervisor: tipos/séries; confirmação de que **não** colide com 1 / 66 / 65 do portal logístico | | | Por validar |
| C02 | Identificar o **mecanismo autorizado** para o portal registar/criar esse dossier | Documentação PHC / IT: UI apenas, SP, API CS, outro — **sem** inventar nomes | | | Por validar |
| C03 | Identificar o **campo físico do número** a apresentar ao cliente | Metadados / ecrã dossier (ex. observação de campo numérico de documento — **só após confirmação no PHC**) | | | Por validar |
| C04 | Confirmar **documento de destino** adequado ao processo | Decisão de negócio + config Cópia de Dossier | | | Decisão pendente |
| C05 | Confirmar **configuração da Cópia de Dossier** (origem mobile → destino) | Supervisor / procedimento interno | | | Por validar |
| C06 | Identificar **campos de origem** no destino que ligam ao mobile | Metadados BO/BI (ou equivalentes) **confirmados no PHC** — não assumir nomes | | | Por validar |
| C07 | Definir deteção / prevenção de **associações ou cópias duplicadas** | Comportamento observado + regra de negócio | | | Por validar |
| C08 | Identificar **fonte de preços** cliente×artigo (descontos, IVA, c/s IVA, sem preço) | Tabelas de preços PHC + amostra controlada | | | Por validar |
| C09 | Confirmar metadados de **`CL2.u_passP`** (existência, tipo, NULL) **sem** ler hashes | `sys.columns` / Supervisor; `COUNT` com preenchimento opcional **sem** devolver valores | | | Por validar |
| C10 | Rever **separação de sessões** e **endpoints anónimos** no mesmo site | Inventário API + topologia IIS | | | Por validar |

Preencher colunas **Resultado** e **Pendências** apenas com evidência verificável. Não marcar `Confirmado` sem evidência.

---

## 8. Contradições com documentação anterior (não resolvidas por assunção)

| Fonte | Conteúdo que diverge desta acta | Tratamento |
| --- | --- | --- |
| [`api-contract.md`](./api-contract.md) § Portal Cliente (Fase 2) | Endpoints `/publico/registo/*`, `/eu/encomendas`, catálogo com stock; modelo de conta F2 a definir | **Histórico / Fase 2 antiga.** Não é SoT do Portal Mobile MVP desta acta até revisão explícita autorizada. |
| [`business-flows.md`](./business-flows.md) § Registo Cliente (RN-017) | Fluxo com OTP SMS futuro; “preparar conta” F2 | RN-017 (NIF + `tlmvl`/`telefone`) permanece referência de **validação de ficha**; activação só com NIF+telemóvel e risco aceite **substitui** o OTP nesta decisão de negócio. Documento de fluxos **ainda não** reescrito nesta etapa. |
| [`ARCHITECTURE.md`](../ARCHITECTURE.md) § Fase 2 | Catálogo com imagens/stock; criação de encomenda pelo cliente | Baseline arquitectónica antiga; **emenda implícita** por esta acta para o MVP mobile (sem imagens; destino via Cópia de Dossier manual). Actualização formal do ARCHITECTURE fica para momento autorizado. |
| Actas de chat anteriores (2.1) | Validade 2 horas; estados; “encomenda de cliente” como destino fixo | **Superseded** por este documento quanto a validade/estados (adiados) e destino (por definir). |

---

## 9. Critério de fecho da Etapa 2.1 (técnico)

A Etapa 2.1 técnica só poderá ser fechada após:

1. Execução e registo da checklist PHC (§7) com evidências.
2. Identificação do tipo de dossier mobile e do mecanismo de registo.
3. Decisão fundamentada sobre o documento de destino.
4. Validação dos campos de origem e da associação.
5. Definição da prevenção de duplicados.
6. Revisão da segurança do percurso público (sessões + `[AllowAnonymous]`).
7. Registo das pendências que permaneçam **Fora do MVP**.

Validade e máquina de estados **não** são critério de fecho desta fase (estão adiados).

---

## 10. Limites e autorização

Esta acta regista decisões e requisitos. **Não** comprova a execução das validações técnicas e **não** constitui autorização de implementação.

Não foram autorizadas alterações ao código, à base de dados, às configurações ou aos mecanismos de criação de documentos do PHC no âmbito desta actualização documental.

**Estado final:** decisões de negócio registadas; documento de destino por definir; validade/estados adiados; validação técnica PHC pendente; implementação **não** autorizada.

---

## 11. Referências no repositório (contexto)

| Recurso | Relação |
| --- | --- |
| [`PROJECT-STATE.md`](./PROJECT-STATE.md) | SoT do Portal Logístico |
| [`auth-portal-identity.md`](./auth-portal-identity.md) | Sessão colaboradores (a separar da sessão cliente) |
| [`sql/001_user_fields.md`](../sql/001_user_fields.md) | `CL.ncont` / `tlmvl` / `telefone`; **sem** `CL2.u_passP` documentado |
| Análise Etapa 1 / 2 (chat) | Levantamento prévio; este ficheiro consolida a 2.1 actualizada |

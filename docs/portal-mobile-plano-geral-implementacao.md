# Portal Mobile — Plano Geral de Implementação

| | |
| --- | --- |
| Projeto | Liliana & Seródio — Portal Mobile de Pedidos |
| Documento | Plano geral de implementação |
| Idioma | Português de Portugal |
| Actualizado | 2026-10-15 |
| Estado | **Plano de execução**; SoT funcional = [`portal-mobile-requisitos-funcionais.md`](./portal-mobile-requisitos-funcionais.md) |

> Acta técnica / bloqueadores: [`portal-mobile-etapa-2.1.md`](./portal-mobile-etapa-2.1.md).  
> SP UAT: [`portal-mobile-sp-criar-pedido.md`](./portal-mobile-sp-criar-pedido.md).  
> **Não** substitui [`PROJECT-STATE.md`](./PROJECT-STATE.md) para o Portal Logístico (colaboradores).

---

## 1. Objetivo

Implementar de ponta a ponta o Portal Mobile de clientes da Liliana & Seródio, integrado com o PHC CS existente.

O portal permitirá que clientes já registados no PHC acedam através de smartphone ou tablet, consultem artigos, preparem pedidos e acompanhem o seu estado.

O objetivo é entregar uma funcionalidade completa, integrada e testada, não apenas criar ecrãs ou endpoints isolados.

O Cursor deve analisar o estado real do repositório, definir o plano de execução completo e implementar as etapas pela ordem adequada, reutilizando os componentes existentes quando fizer sentido.

## 2. Regras de execução para o Cursor

Trabalha como responsável técnico pela implementação.

1. Começa por analisar os requisitos funcionais e o estado atual do projeto.
2. Distingue o que já existe, o que está parcialmente implementado e o que falta.
3. Define uma sequência de execução completa, incluindo dependências, alterações ao PHC, backend, frontend, segurança e testes.
4. Identifica previamente os bloqueios que possam impedir uma implementação correta.
5. Depois de definido o plano, executa as etapas sequencialmente, concluindo e validando cada uma antes de avançar para a seguinte.
6. Não pares para pedir aprovação a cada ficheiro, método ou pequena decisão técnica. Escolhe a solução mais simples e consistente com a arquitetura existente.
7. Não inventes regras de negócio nem alteres decisões funcionais já aprovadas.
8. Se surgir uma decisão funcional realmente indispensável que não esteja definida, apresenta apenas essa decisão, explica brevemente as alternativas e aguarda resposta.
9. Não consideres uma funcionalidade concluída só porque o código compila. Confirma também integração, segurança e comportamento funcional.
10. Mantém a documentação e os testes atualizados ao longo da implementação.

Na fase inicial de planeamento, não alteres ficheiros nem bases de dados. Depois de identificados os bloqueios e definida a sequência, passa à implementação quando estiveres em modo de execução.

Não executes alterações em produção sem autorização explícita. As alterações de base de dados devem ser preparadas e validadas em UAT antes de qualquer passagem a produção.

## 3. Arquitetura e contexto existente

O projeto atual é um portal operacional para funcionários, não uma implementação do Portal Mobile de clientes.

Tecnologias existentes:
- Backend: .NET 8.
- Frontend: React, Vite e Material UI.
- Base de dados: PHC CS sobre SQL Server.
- Acesso aos dados: Dapper, vistas `view_HCA_*` e procedimentos `sp_HCA_*`.
- Instalação prevista: Windows Server e IIS.
- Interface e documentação: português de Portugal.

Não criar uma base de dados aplicacional separada sem necessidade comprovada. Analisar a arquitetura existente e propor a persistência mínima necessária para as credenciais dos clientes.

A autenticação dos funcionários utiliza ASP.NET Identity, utilizadores PHC em `US` e o cookie `ls_portal_auth`. Esta autenticação deve permanecer funcional e isolada da autenticação dos clientes.

## 4. Requisitos funcionais

### 4.1. Entrada e autenticação

O portal deve ser acessível por URL direta e QR code de acesso ao portal. Este QR code é distinto dos códigos QR utilizados para identificar artigos.

A autenticação dos clientes deve suportar:

- Identificação através do NIF.
- Login com palavra-passe.
- Primeiro acesso, quando ainda não existe palavra-passe definida.
- Recuperação de palavra-passe.
- Logout manual.
- Expiração da sessão após 30 minutos de inatividade.

Não existe registo livre de novos clientes. O cliente tem de estar registado no PHC.

#### Identificação do cliente

O NIF é um localizador, não uma chave única.

- O NIF `999999990`, correspondente ao consumidor final, não pode aceder ao portal.
- A restrição deve ser aplicada no servidor no primeiro acesso, login e recuperação de palavra-passe.
- Se não existir uma ficha de cliente, informar que o cliente deve dirigir-se ao balcão para criação ou atualização dos dados.
- Se o NIF corresponder a várias fichas distintas, não escolher automaticamente uma delas. Encaminhar para regularização no balcão.
- Se existir uma única ficha elegível, validar o telemóvel e prosseguir.
- Após a identificação, associar a sessão a `CL.no` e `CL.estab`.

A implementação não pode confiar apenas no NIF nem em identificadores enviados pelo navegador para autorizar operações.

#### Primeiro acesso

1. O cliente introduz o NIF.
2. O servidor verifica as regras de elegibilidade e identifica uma única ficha de cliente.
3. O cliente valida o telemóvel registado no PHC.
4. Após validação, pode definir a palavra-passe.
5. A credencial fica guardada com hash seguro.

A validação utiliza `CL.tlmvl`, dando prioridade a este campo, e `CL.telefone` como alternativa, de acordo com as regras documentadas do projeto.

Não existe validação por SMS nesta fase.

Após cinco tentativas falhadas de validação do telemóvel, bloquear novas tentativas durante 15 minutos. O bloqueio é controlado no servidor.

#### Login

O cliente introduz NIF e palavra-passe. O servidor verifica a elegibilidade, resolve a ficha e valida as credenciais.

Aplicar proteção contra tentativas abusivas, mensagens de erro adequadas e bloqueio temporário. Evitar revelar desnecessariamente se determinado NIF tem conta ou palavra-passe definida.

#### Recuperação de palavra-passe

O cliente introduz o NIF e valida o telemóvel registado no PHC. Se a validação for bem-sucedida, pode definir uma nova palavra-passe.

Aplicam-se as mesmas regras de elegibilidade, bloqueio e proteção contra tentativas abusivas.

Não implementar alteração direta de palavra-passe dentro de uma sessão autenticada nesta fase.

### 4.2. Credenciais e segurança

A autenticação dos clientes deve ser independente da dos funcionários.

- Utilizar um esquema e cookie de autenticação próprios para clientes.
- Não reutilizar `ls_portal_auth`, o UserStore dos funcionários ou as claims `usercode` e `Admin`.
- Gerir as palavras-passe através de hash seguro.
- Não utilizar `CL2.u_passp` nesta fase, uma vez que a sua finalidade e formato não estão confirmados.
- Associar a identidade autenticada a `CL.no` e `CL.estab`.
- Isolar as políticas de autorização das APIs de clientes e de funcionários.
- Garantir HTTPS e cookies seguros em produção.
- Implementar proteção contra CSRF quando aplicável, rate limiting e validação de pedidos.
- Garantir que o logout invalida a sessão do cliente.

A persistência das credenciais deve ser integrada na arquitetura existente. Definir os campos e índices necessários, preparar as alterações de base de dados e documentar as permissões. Não aplicar alterações de esquema ou dados em produção sem autorização.

### 4.3. Página inicial do cliente

Após login e após submissão bem-sucedida de um pedido, apresentar a página inicial do portal.

Deve conter:

- Acesso a **Novo pedido**.
- Acesso à leitura de um artigo por QR code ou introdução manual da referência.
- Os últimos 10 pedidos não cancelados, do mais recente para o mais antigo.
- Estado atual de cada pedido.

Não criar pesquisa de artigos por descrição ou categoria.

### 4.4. Consulta e seleção de artigos

O cliente pode identificar o artigo através de:

- Leitura de QR code contendo a referência.
- Introdução manual da referência.

Depois de identificado o artigo, apresentar os dados necessários para preparar o pedido.

Regras:
- Não incluir imagens de artigos.
- Não disponibilizar pesquisa por descrição ou categoria.
- Consultar os preços segundo as condições comerciais do cliente no PHC.
- Disponibilizar a lista geral de cores, quando aplicável.
- Os artigos sem cor não apresentam seletor de cor.
- Não limitar o seletor às cores configuradas individualmente no artigo.
- Mostrar um aviso de disponibilidade limitada quando aplicável, sem revelar quantidades exatas de stock.
- O aviso não impede a submissão do pedido.

A fonte definitiva da lista geral de cores e o limiar do aviso devem ser confirmados através dos metadados e regras existentes no PHC. Não inventar valores nem assumir que uma tabela vazia é a fonte definitiva.

### 4.5. Carrinho

O carrinho deve permitir adicionar, alterar e remover linhas antes da submissão.

Regras:
- A identidade de uma linha é a referência do artigo e a cor, quando aplicável.
- Adicionar o mesmo artigo com a mesma cor acumula a quantidade.
- O mesmo artigo com cores diferentes origina linhas separadas.
- As quantidades são números inteiros positivos.
- Não existe quantidade mínima adicional.
- Não definir um limite máximo arbitrário; analisar os limites técnicos e funcionais antes de os aplicar.
- Não incluir observações ou instruções no pedido nesta fase.

Antes da submissão, apresentar:
- Artigo.
- Referência.
- Cor, quando aplicável.
- Quantidade.
- Preço unitário.
- Total da linha.
- Total estimado do pedido.

O cliente pode corrigir o carrinho até à submissão.

Preservar o carrinho durante a sessão e após expiração ou fecho do navegador, quando tecnicamente possível. No mesmo dia, tentar recuperar o carrinho; no dia seguinte, iniciar vazio. Se houver limitações relevantes, documentá-las e propor a solução mais simples sem comprometer a segurança.

### 4.6. Submissão do pedido

A submissão deve criar um pedido autónomo no PHC.

Existe em UAT a stored procedure `sp_HCA_criar_pedido_mobile`, associada a `ndos=67`, com suporte de idempotência. Esta SP já foi criada e validada em UAT, mas a auditoria identificou que ainda não está integrada na API e na interface mobile.

Antes de a integrar:
- Rever o contrato atual da SP e os seus testes.
- Confirmar os campos obrigatórios e as permissões necessárias.
- Resolver a inclusão da cor nas linhas do pedido.
- Garantir que a identidade do cliente provém da sessão autenticada.
- Garantir que o pedido não é duplicado quando há falha de comunicação ou repetição da submissão.
- Validar preços, quantidades, IVA e totais de acordo com o comportamento PHC já documentado.

Não assumir que `ndos=67` é a encomenda comercial definitiva. É o documento autónomo do pedido mobile; a transformação posterior é um processo separado.

Após sucesso:
- Mostrar confirmação no ecrã.
- Regressar à página inicial.
- Apresentar o pedido no histórico.

Não enviar emails ou SMS nesta fase.

Em caso de erro, apresentar uma mensagem clara, preservar o carrinho e permitir nova tentativa sem criar duplicados.

### 4.7. Histórico e detalhe do pedido

Apresentar os últimos 10 pedidos não cancelados, do mais recente para o mais antigo.

O detalhe deve mostrar:
- Data e hora da submissão.
- Estado atual.
- Artigos e descrições.
- Quantidades.
- Preços unitários.
- Totais por linha.
- Total estimado do pedido.

O número apresentado ao cliente deve utilizar o número de negócio PHC confirmado para esse documento, não o identificador técnico `bostamp`. Validar a combinação de campos necessária para garantir que o número é inequívoco.

### 4.8. Estados dos pedidos

Os estados funcionais previstos são:

1. **Pedido submetido** — pedido registado no PHC.
2. **Em preparação** — funcionário transforma o pedido mobile numa encomenda de cliente no PHC.
3. **Pronto para levantamento** — pedido preparado e separado.
4. **Concluído** — processo terminado.

O mapeamento técnico dos estados 3 e 4 para os campos e documentos PHC ainda não está fechado.

Não inventar o mapeamento nem associar automaticamente estes estados a um `ndos` ou campo PHC sem evidência. Analisar os fluxos existentes e identificar o mínimo de informação necessário para fechar a decisão.

### 4.9. Cancelamento

O cliente só pode cancelar um pedido no estado **Pedido submetido**.

- Pedir confirmação antes de cancelar.
- Em caso de sucesso, mostrar “Pedido cancelado com sucesso”.
- Ocultar o pedido cancelado do histórico do cliente.
- Não apagar o registo PHC apenas para o ocultar.
- Em caso de falha, informar o cliente.

A implementação deve identificar uma forma segura e auditável de marcar o cancelamento, após validação do modelo de dados e das regras PHC. Não inventar campos existentes nem executar alterações de esquema sem autorização.

### 4.10. Transformação posterior no PHC

A transformação do pedido mobile numa encomenda comercial é efetuada pelo funcionário no PHC Desktop através de “Cópia de Dossier”.

Não implementar automaticamente essa transformação no Portal Mobile.

O plano deve identificar como preservar a relação entre o pedido original e a encomenda criada posteriormente. A regra concreta de associação entre documentos, o `ndos` de destino e o mapeamento dos estados dependem da validação dos fluxos PHC existentes.

Não assumir que existem campos de associação no cabeçalho `BO` que não foram confirmados na base de dados.

## 5. Integração técnica

O plano deve abranger, de forma integrada:

- Autenticação e persistência das credenciais.
- Endpoints da API para primeiro acesso, login, recuperação, logout e sessão.
- Proteção das APIs de clientes.
- Interface mobile-first e respetivas rotas.
- Consulta de artigos, preços, cores e disponibilidade.
- Carrinho e recuperação de estado.
- Submissão idempotente dos pedidos.
- Histórico, detalhe, estados e cancelamento.
- Integração com os documentos PHC.
- Configuração de segurança e permissões.
- Testes automatizados e validação funcional.
- Documentação técnica e operacional.

Reutilizar os padrões de código existentes quando forem adequados, sem misturar a identidade de clientes com a dos funcionários.

## 6. Sequência esperada de implementação

O Cursor deve determinar a sequência final com base nas dependências reais do repositório. Considerar, pelo menos, estas etapas:

1. **Preparação:** confirmar requisitos, estado do código, contratos das SPs, metadados e bloqueios.
2. **Fundação da autenticação:** persistência das credenciais, esquema de autenticação, sessão e isolamento.
3. **Fluxos de acesso:** primeiro acesso, login, recuperação, logout e expiração.
4. **Consulta de artigos:** referência/QR, preço, cor e aviso de disponibilidade.
5. **Carrinho:** linhas, quantidades, totais e recuperação.
6. **Submissão:** integração da SP mobile, cor, idempotência e tratamento de erros.
7. **Página inicial e histórico:** lista, detalhe e confirmação.
8. **Cancelamento:** regras de elegibilidade, persistência e histórico.
9. **Estados e integração operacional:** validar o mapeamento com os fluxos PHC e completar a visualização dos estados.
10. **Validação final:** testes de ponta a ponta, segurança, regressão, documentação e preparação de deployment.

O Cursor pode reorganizar estas etapas quando existir uma justificação técnica clara, mas deve preservar todas as funcionalidades do âmbito.

## 7. Testes e critérios de conclusão

A implementação só está concluída quando:

- Os clientes conseguem completar o primeiro acesso, login, recuperação e logout.
- O consumidor final `999999990` não consegue aceder por nenhum dos fluxos de autenticação.
- NIFs sem ficha ou com várias fichas não são associados arbitrariamente a um cliente.
- O bloqueio de cinco tentativas falhadas de telemóvel durante 15 minutos é aplicado no servidor.
- A sessão termina após 30 minutos de inatividade.
- Um cliente não consegue aceder às APIs de funcionários e vice-versa.
- Os artigos, preços, cores e avisos apresentados respeitam os dados e regras PHC.
- O carrinho distingue corretamente artigos com cores diferentes.
- A submissão cria um único pedido mesmo quando existem repetições ou falhas de comunicação.
- O histórico e o detalhe correspondem aos dados do pedido.
- O cancelamento só é possível no estado permitido e não apaga indevidamente documentos PHC.
- Os estados apresentados correspondem a regras confirmadas.
- Os testes existentes continuam a passar e são acrescentados testes para os novos fluxos.
- A documentação descreve a implementação real, sem afirmar funcionalidades não entregues.

## 8. Gestão de riscos e decisões em aberto

Antes de executar alterações irreversíveis, identificar as decisões que dependem de confirmação funcional ou PHC.

Os pontos conhecidos ainda por resolver incluem:
- O limiar de disponibilidade limitada.
- O limite máximo de quantidade, caso seja necessário.
- Os detalhes da recuperação do carrinho no mesmo dia.
- O campo definitivo a apresentar como número do pedido.
- A relação entre o pedido original e a encomenda criada por “Cópia de Dossier”.
- O mapeamento técnico dos estados “Pronto para levantamento” e “Concluído”.
- A forma PHC de registar o cancelamento sem eliminar o documento.

Não reabrir decisões já aprovadas, não criar funcionalidades fora do âmbito e não bloquear toda a implementação por decisões que só sejam necessárias numa etapa posterior. Avançar nas partes independentes e pedir esclarecimento apenas quando uma decisão pendente bloquear efetivamente a etapa em curso.

## 9. Entrega final

No final, apresentar:
- Funcionalidades implementadas e validadas.
- Ficheiros principais criados ou alterados.
- Scripts de base de dados preparados e aplicados em UAT.
- Testes executados e respetivos resultados.
- Decisões ainda pendentes.
- Instruções de configuração e deployment.
- Riscos ou limitações que impeçam considerar a solução pronta para produção.

Não declarar o projeto concluído enquanto existirem funcionalidades obrigatórias por implementar ou testes essenciais por validar.

# Portal Mobile de Pedidos PHC — Requisitos funcionais

| | |
| --- | --- |
| Projeto | Liliana & Seródio — Portal Mobile de Pedidos |
| Documento | Requisitos funcionais (versão de consolidação) |
| Idioma | Português de Portugal |
| Actualizado | 2026-10-15 |
| Estado | **Consolidado para comportamento pretendido**; **não** autoriza alterações a código nem BD de produção |

> Fonte de verdade **funcional** do Portal Mobile.  
> Plano geral de implementação: [`portal-mobile-plano-geral-implementacao.md`](./portal-mobile-plano-geral-implementacao.md).  
> Validação técnica PHC / bloqueadores: [`portal-mobile-etapa-2.1.md`](./portal-mobile-etapa-2.1.md).  
> SP de criação (UAT, técnica): [`portal-mobile-sp-criar-pedido.md`](./portal-mobile-sp-criar-pedido.md).  
> **Não** substitui [`PROJECT-STATE.md`](./PROJECT-STATE.md) para o Portal Logístico (colaboradores).

---

## 1. Objetivo

Disponibilizar aos clientes existentes no PHC um portal simples, otimizado para smartphones e tablets, onde possam consultar artigos, criar pedidos e acompanhar o respetivo estado.

O portal funciona como ponto de entrada dos pedidos. O processamento comercial e operacional continua a ser realizado pelos colaboradores no PHC.

---

## 2. Acesso e autenticação

- Acesso através de link direto ou QR Code de acesso ao portal.
- Autenticação através do NIF e palavra-passe, quando esta já existe no PHC.
- No primeiro acesso, validação do número de telemóvel face ao registo do cliente no PHC e definição da palavra-passe.
- Após cinco tentativas falhadas de validação do telemóvel, não permitir tentativas ilimitadas.
- Recuperação da palavra-passe através do NIF e validação do número de telemóvel registado no PHC.
- Não existe validação por SMS nesta fase.
- A sessão termina após 30 minutos de inatividade.
- O cliente pode terminar sessão manualmente.
- A alteração direta da palavra-passe fica fora do âmbito desta fase.

### 2.1 Consumidor final

- O NIF de consumidor final `999999990` **não** pode aceder ao Portal Mobile, independentemente do número de fichas de cliente existentes no PHC para esse NIF.
- Esta validação é obrigatória **no servidor**, no primeiro acesso, no login e na recuperação de palavra-passe. Não basta ocultar opções na interface.

### 2.2 Identificação do cliente (NIF → ficha PHC)

- O NIF (`CL.ncont`) serve para **localizar** a ficha do cliente no PHC, mas **não** é chave única.
- Se o NIF corresponder a **uma única** ficha elegível, o fluxo pode prosseguir após a validação do telemóvel, conforme as regras desta secção.
- Se **não** existir ficha para o NIF, o cliente deve ser encaminhado para o balcão para criação ou atualização dos dados.
- Se existirem **várias** fichas distintas para o mesmo NIF, o portal **não** escolhe automaticamente uma delas; o cliente deve ser encaminhado para regularização no balcão.
- Após a identificação bem-sucedida, a identidade autenticada fica associada a `CL.no` e `CL.estab` (não apenas ao NIF) para o resto da sessão e dos pedidos.

**Nota de risco (mantida):** autenticação baseada em NIF + telemóvel / palavra-passe associada admite risco de representação indevida — limitação aceite e documentada.

---

## 3. Consulta e seleção de artigos

- Os artigos são identificados através da leitura de QR Code ou da introdução manual da referência.
- O QR Code contém apenas a referência do artigo.
- Não existe pesquisa por descrição, referência através de pesquisa geral ou categorias.
- Após identificar o artigo, o cliente escolhe a quantidade e, quando aplicável, a cor.
- As cores são selecionadas a partir de uma lista geral.
- Artigos sem cor podem ser adicionados sem seleção de cor.
- As quantidades são números inteiros positivos, sem quantidade mínima. O limite máximo fica por definir.
- O portal apresenta um aviso de disponibilidade limitada quando aplicável, sem revelar a quantidade exata em stock.
- A disponibilidade limitada não impede a submissão do pedido.

---

## 4. Carrinho e submissão

- O cliente pode consultar o carrinho, alterar quantidades e remover artigos antes da submissão.
- Cada linha é identificada pela combinação de referência e cor, quando aplicável.
- Ao adicionar novamente o mesmo artigo na mesma cor, a quantidade acumula na linha existente.
- O carrinho apresenta artigos, quantidades, preços unitários, totais por linha e total estimado.
- Antes da submissão, o cliente pode rever e corrigir o pedido.
- Após a submissão, o pedido fica bloqueado para edição.
- A confirmação de sucesso é apresentada no próprio portal, sem envio de e-mail ou SMS.
- Após a submissão, o cliente regressa à homepage.
- Se ocorrer um erro, o portal informa o cliente, mantém o carrinho e permite tentar novamente, evitando pedidos duplicados.
- Se o cliente fechar o navegador ou voltar a iniciar sessão no mesmo dia, deve tentar recuperar o carrinho, caso seja tecnicamente possível. No dia seguinte, o carrinho começa vazio.

---

## 5. Homepage e histórico

A homepage apresenta:

- Acesso a **Novo pedido**.
- Os últimos 10 pedidos não cancelados, ordenados do mais recente para o mais antigo.
- O estado atual de cada pedido.

Ao abrir um pedido, o cliente pode consultar:

- Data e hora da submissão.
- Estado atual.
- Artigos e descrições.
- Quantidades.
- Preços unitários.
- Totais por linha.
- Total estimado.

---

## 6. Estados dos pedidos

Os estados apresentados ao cliente são:

1. **Pedido submetido** — o pedido foi registado.
2. **Em preparação** — o colaborador transformou o pedido numa encomenda de cliente no PHC.
3. **Pronto para levantamento** — o pedido está separado e pronto para entrega ao cliente.
4. **Concluído** — o processo terminou.

O momento técnico em que o PHC permite identificar os estados «Pronto para levantamento» e «Concluído» fica por definir, após análise do processo operacional existente.

**Mapeamento provisório (negócio → PHC, sujeito a validação):**

| Estado UI | Indício técnico conhecido | Confiança |
| --- | --- | --- |
| Pedido submetido | Documento `ndos=67` criado e ainda sem cópia / destino associado | A validar |
| Em preparação | Colaborador executou **Cópia de Dossier** para encomenda de cliente | A validar (`ndos` destino em aberto) |
| Pronto para levantamento | Por definir no circuito operacional | Em aberto (§10) |
| Concluído | Por definir no circuito operacional | Em aberto (§10) |

---

## 7. Cancelamento

- O cliente pode cancelar um pedido apenas enquanto estiver em **Pedido submetido**.
- Antes de cancelar, o portal pede confirmação.
- Após um cancelamento bem-sucedido, apresenta a mensagem «Pedido cancelado com sucesso».
- O pedido deixa de aparecer no histórico do portal.
- Em caso de erro, o portal informa o cliente e não apresenta o cancelamento como concluído.
- O registo no PHC **não** deve ser apagado apenas por causa desta regra de apresentação no portal.

---

## 8. Assuntos tratados fora do portal

- Diferenças entre o preço estimado e o preço validado no balcão: o colaborador chama o cliente e explica a situação.
- Artigos que deixem de estar disponíveis após a submissão: o colaborador trata diretamente com o cliente.
- Estas situações **não** originam fluxos de aprovação, alteração ou cancelamento no portal.

---

## 9. Fora do âmbito desta fase

- Envio de confirmações por e-mail ou SMS.
- Alteração direta da palavra-passe no portal.
- Pesquisa de artigos por descrição ou categoria.
- Gestão de diferenças de preços ou ruturas de stock após a submissão.
- Edição de pedidos já submetidos.
- Imagens de artigos (MVP).

---

## 10. Pontos em aberto

- Como identificar no PHC os estados «Pronto para levantamento» e «Concluído».
- Limite máximo de quantidade por artigo.
- Viabilidade e mecanismo de recuperação do carrinho no mesmo dia.
- Campo físico do número apresentado ao cliente (`obrano` / outro).
- Documento de destino da Cópia de Dossier e campos de origem.
- Regra técnica de «disponibilidade limitada» (limiar sem revelar stock).
- Persistência do cancelamento no PHC (flag / estado) vs. só filtro no histórico do portal.

---

## 11. Princípio de implementação

A implementação deve respeitar o funcionamento comercial existente no PHC, evitar duplicação de lógica e manter o portal simples. As decisões técnicas devem ser tomadas depois de os requisitos funcionais estarem consolidados e de o processo real do PHC ser analisado.

Este documento descreve o comportamento pretendido; **não** constitui autorização para alterar código ou bases de dados de produção.

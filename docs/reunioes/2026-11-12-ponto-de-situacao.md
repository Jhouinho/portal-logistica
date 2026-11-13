# Ponto de situação — Reunião de 12/11/2026

**Projecto:** Liliana & Seródio — Portal de Logística  
**Data da reunião:** 12 de Novembro de 2026  
**Tipo de documento:** Registo dos assuntos levantados e pontos a acompanhar

## Enquadramento

Este documento regista os temas discutidos na reunião de 12/11/2026, para servir de ponto de situação e base de acompanhamento entre a Liliana & Seródio e a equipa de desenvolvimento.

Os pontos abaixo representam necessidades, sugestões, alterações pretendidas e tarefas de seguimento identificadas durante a reunião. **O registo neste documento não significa, por si só, que uma funcionalidade esteja aprovada tecnicamente, estimada, implementada ou validada.** Os detalhes funcionais e técnicos deverão ser confirmados antes de iniciar cada desenvolvimento.

## Pontos levantados na reunião

### 1. Organização dos artigos por famílias
- Organizar os artigos de acordo com as duas famílias principais identificadas: Holanda e Equador.
- Rever a classificação existente e garantir que o portal apresenta os artigos agrupados de acordo com essa organização.

### 2. Previsão de stock e tratamento das encomendas
- A previsão de stock deverá funcionar como indicador visual e apoio à decisão, não podendo bloquear a criação ou o tratamento de encomendas.
- O portal deverá considerar as encomendas em aberto e as quantidades previstas para apoiar a avaliação da capacidade de resposta.
- Foi reconhecido que os valores previstos podem ser variáveis ou incertos.
- Foi sugerido complementar a previsão com o stock existente no PHC, as encomendas a fornecedores e as respectivas datas previstas de chegada.
- O modelo de cálculo e a forma de apresentação deverão ser definidos e validados com o cliente antes de fechar a solução.

### 3. Lançamento automático de encomendas para picking
- Disponibilizar na área de encomendas uma funcionalidade que permita lançar automaticamente para picking as encomendas em aberto, considerando a previsão de stock disponível.
- O objectivo é simplificar a preparação das encomendas, mantendo a previsão como informação de apoio e não como mecanismo de bloqueio.

### 4. Consulta da previsão de stock no portal e nos terminais Syslog
- Disponibilizar a previsão de stock no portal e nos terminais Syslog, como indicador visual.
- Exemplo de utilização: durante o levantamento, perante um pedido de artigo adicional, o colaborador poderá consultar a disponibilidade prevista e informar o cliente se será possível disponibilizá-lo.

### 5. Criação de encomendas directamente no Syslog
- Permitir a criação de uma encomenda de raiz no Syslog, sem necessidade de existir um documento de origem.
- O processo deverá permitir seleccionar o cliente, escolher os artigos e criar a encomenda.

### 6. Flexibilização do processo de picagem no Syslog

#### 6.1. Fecho automático do dossiê de origem
- Quando todas as quantidades previstas para picagem forem integralmente picadas, o dossiê de origem deverá fechar automaticamente.
- Quando não for picada a totalidade, o dossiê deverá permanecer aberto, reflectindo apenas as quantidades que continuam pendentes.

#### 6.2. Picagem de artigos ou quantidades adicionais
- Durante a picagem de uma encomenda, permitir adicionar artigos que não constavam originalmente do documento ou aumentar as quantidades pedidas.
- A picagem não deverá ficar limitada às linhas e quantidades da encomenda original.
- Os artigos e as quantidades adicionais deverão ficar associados ao dossiê criado no PHC e ser reflectidos no respectivo documento.
- Esta capacidade foi identificada como necessária para permitir responder a pedidos adicionais dos clientes durante a operação.

### 7. Impressão de etiquetas
- Foi identificada a necessidade de disponibilizar uma impressora de etiquetas.
- Será necessário definir o equipamento adequado e os requisitos de impressão.

### 8. Visão TV
- Confirmar com o cliente se já existe um monitor disponível para a visão TV ou se será necessário adquirir equipamento.
- Caso seja necessário adquirir um monitor, preparar o respectivo orçamento.

### 9. Ajuste do processo documental de separação e facturação
- O fluxo actual prevê o dossiê de separação como etapa final.
- Foi levantada a necessidade de rever este processo: o dossiê de separação deverá ser transformado num dossiê de pedido.
- Nesse dossiê de pedido será tratado o que será facturado ao cliente e o que ficará em aberto.

### 10. Tipo de transporte associado à encomenda
- Criar no PHC um campo de selecção para identificar o tipo de transporte associado à encomenda.
- Foram identificadas as seguintes opções:
  - Envio por transportadora;
  - Levantamento pelo cliente no armazém;
  - Entrega pela Liliana & Seródio.
- A informação deverá ser transmitida ao portal e apresentada em cada encomenda.

### 11. Morada de entrega
- Criar campos de utilizador no PHC para permitir o registo manual da morada de entrega.
- Integrar essa informação e apresentá-la nos dados da encomenda no portal.
- A necessidade identificada é o registo da morada em campos próprios no PHC e a sua transmissão ao portal.

### 12. Solução mobile — âmbito da primeira fase
- Na primeira fase, a solução mobile deverá permitir apenas a consulta de artigos.
- Para cada artigo deverão ser apresentados, pelo menos, a referência, a designação, a imagem e o preço.
- A criação e submissão de encomendas através do mobile ficam em standby e não fazem parte da primeira fase.

### 13. Infra-estrutura e acessos
- Articular com o Filipe a confirmação dos pontos de acesso à Internet nas instalações da Liliana & Seródio.
- Solicitar os acessos de gestão do domínio `lsflores.com`, necessários para emitir/configurar o certificado digital.
- O objectivo é disponibilizar o portal através de HTTPS, em substituição de HTTP.

### 14. Definição e importação das cores disponíveis por referência
- Exportar para Excel todas as referências de artigos existentes no PHC.
- O cliente deverá preencher no ficheiro as colunas correspondentes às cores válidas para cada referência.
- Após validação e devolução do ficheiro, a informação será importada para o PHC, associando as cores às respectivas referências.
- No PHC, durante a criação e edição das encomendas, deverão estar disponíveis apenas as cores definidas para a referência seleccionada.
- O portal deverá reflectir a informação de cores associada a cada referência, mas não será utilizado para criar ou submeter encomendas; estas operações são realizadas no PHC.
- O objectivo é normalizar as designações, evitar variantes (por exemplo, «amarelo» e «amarela»), duplicações e erros.
- A preparação e validação da informação comercial será feita pelo cliente através do Excel; a integração técnica será assegurada no âmbito do projecto.

### 15. Gestão autónoma de novas cores no PHC
- Para além da carga inicial através de Excel, desenvolver no PHC um mecanismo que permita ao cliente criar novas cores e associá-las autonomamente a uma ou várias referências.
- As novas cores e respectivas associações deverão ficar disponíveis no portal.
- Importa distinguir a carga inicial de dados, tratada através do Excel, da manutenção contínua, que deverá poder ser feita pelo cliente no PHC.

### 16. Gestão de prioridades das tarefas de separação nos terminais Syslog
- Comportamento actual identificado: um dossiê de separação só é disponibilizado nos terminais Syslog quando existe um check-in prévio do cliente na plataforma.
- Pretende-se alterar este comportamento para que o operador possa consultar e executar tarefas de separação mesmo quando não existe check-in.
- Quando existir check-in de um determinado cliente, as tarefas de separação associadas às encomendas desse cliente deverão passar automaticamente para primeiro plano, com prioridade superior na lista dos terminais Syslog.
- As restantes tarefas deverão continuar disponíveis, mas com prioridade inferior.

### 17. Acessórios de transporte e suporte para dispositivos móveis
- O cliente questionou a existência de acessórios que facilitem o transporte dos dispositivos móveis durante a utilização.
- Avaliar soluções de suporte para cinto/cintura e suporte peitoral ou tiracolo, que permitam manter as mãos livres.
- Identificar opções disponíveis, compatibilidade com os dispositivos e preços, para posterior apresentação ao cliente.

### 18. Filtro por família no ecrã de previsões
- No ecrã de listagem das previsões de stock, disponibilizar um filtro por família.
- O filtro deverá respeitar a classificação definida no PHC, incluindo as famílias Holanda e Equador.

### 19. Alteração do modelo de previsão de stock
- O modelo actual utiliza previsões definidas por períodos, com data inicial e data final, permitindo criar várias previsões para intervalos distintos (por exemplo, semanais).
- Foi solicitada a substituição deste modelo por uma tabela contínua de previsão de stock, sem necessidade de definir manualmente intervalos de datas.
- A tabela deverá ser actualizada frequentemente, idealmente todos os dias, apresentando a informação mais recente para consulta no portal e apoio à decisão.
- Fica por clarificar se a tabela deverá apresentar apenas o valor previsto por artigo ou também a evolução da previsão ao longo do tempo.

## Aspectos a acompanhar

1. Rever este registo com o cliente e confirmar se todos os pontos reflectem correctamente o que foi discutido.
2. Distinguir, para cada ponto, o comportamento actualmente existente, a alteração pretendida e o desenvolvimento novo.
3. Clarificar os temas que ainda carecem de definição funcional, em particular o modelo de previsão de stock, o processo documental de pedido/facturação e as regras de picagem adicional.
4. Avaliar impacto técnico, dependências, esforço e prioridade antes de integrar os pontos num plano de implementação.
5. Actualizar o estado de cada ponto após validação e decisão conjunta.

## Nota de estado

Este documento constitui o ponto de situação da reunião de 12/11/2026. Não substitui a documentação técnica do projecto nem altera automaticamente os requisitos ou comportamentos actualmente implementados no portal. As decisões finais e a evolução de cada tema deverão ser reflectidas na documentação de referência do projecto após validação.

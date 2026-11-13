# Ponto de situação — Reunião de 12/11/2026

**Projecto:** Liliana & Seródio — Portal de Logística  
**Data da reunião:** 12 de Novembro de 2026  
**Tipo de documento:** Registo dos pontos discutidos e validados

## Pontos discutidos

### 1. Organização dos artigos por famílias
- Organizar os artigos de acordo com as duas famílias principais: Holanda e Equador.
- Garantir que o portal apresenta os artigos agrupados de acordo com essa organização.

### 2. Previsão de stock e tratamento das encomendas
- A previsão de stock deverá funcionar como indicador visual e apoio à decisão, sem bloquear a criação ou o tratamento de encomendas.
- Deverá considerar as encomendas em aberto, o stock existente e as encomendas a fornecedores, incluindo as respectivas datas previstas.

### 3. Lançamento automático de encomendas para picking
- Permitir lançar automaticamente para picking as encomendas em aberto, tendo em conta a previsão de stock disponível.

### 4. Consulta da previsão de stock no portal e nos terminais Syslog
- Disponibilizar a previsão de stock no portal e nos terminais Syslog, para que os colaboradores possam consultar a disponibilidade prevista durante o atendimento.

### 5. Criação de encomendas directamente no Syslog
- Permitir a criação de encomendas de raiz nos terminais Syslog, seleccionando o cliente, escolhendo os artigos e criando a encomenda sem documento de origem.

### 6. Flexibilização do processo de picagem no Syslog
- Permitir adicionar artigos que não constavam originalmente da encomenda e ajustar quantidades durante o processo de picagem.
- As alterações deverão ser reflectidas no PHC.

### 7. Impressão de etiquetas
- Identificar o equipamento adequado para a impressão de etiquetas e os respectivos requisitos de impressão.

### 8. Visão TV
- Confirmar a existência de um monitor para a visão TV ou, caso seja necessário, preparar um orçamento.

### 9. Ajuste do processo documental de separação e facturação
- Transformar o actual dossiê de separação num dossiê de pedidos, onde se define o que será facturado ao cliente e o que ficará em aberto.

### 10. Tipo de transporte associado à encomenda
- Criar no PHC um campo para identificar o tipo de transporte: envio por transportadora, levantamento no armazém ou entrega pela empresa.
- Transmitir essa informação para o portal.

### 11. Morada de entrega
- Criar campos de utilizador no PHC para a morada de entrega, permitindo o seu registo manual e a integração com o portal.

### 12. Solução mobile — âmbito da primeira fase
- Na primeira fase, permitir apenas a consulta de artigos, apresentando referência, designação, imagem e preço.
- A criação de encomendas fica em standby.

### 13. Infra-estrutura e acessos
- Confirmar com o Filipe os pontos de acesso à Internet.
- Solicitar os acessos de gestão do domínio lsflor.com.
- Configurar o certificado para disponibilizar o portal através de HTTPS.

### 14. Definição e importação das cores disponíveis por referência
- Exportar as referências dos artigos do PHC para Excel.
- O cliente deverá preencher as cores válidas para cada referência.
- Importar a informação preenchida para o PHC, reflectindo-a também no portal.

### 15. Gestão autónoma de novas cores no PHC
- Desenvolver no PHC um mecanismo que permita ao cliente criar novas cores e associá-las às referências de forma autónoma.

### 16. Gestão de prioridades das tarefas de separação nos terminais Syslog
- Permitir que os operadores executem tarefas de separação mesmo quando não existe check-in.
- Quando existir check-in de um cliente, as tarefas de separação associadas a esse cliente deverão passar a ter prioridade na lista dos terminais Syslog.

### 17. Acessórios de transporte e suporte para dispositivos móveis
- Avaliar acessórios para transportar os dispositivos móveis durante a operação, nomeadamente suportes de cinto e de peito.

### 18. Filtro por família no ecrã de previsões
- Adicionar um filtro por família no ecrã de previsões, permitindo seleccionar, por exemplo, Holanda ou Equador.

### 19. Alteração do modelo de previsão de stock
- Substituir a previsão baseada em intervalos de datas (data inicial e data final) por uma tabela contínua de previsão de stock.
- A tabela deverá ser actualizada diariamente.

## Nota
Os 19 pontos acima foram revistos e validados ponto por ponto. Este documento regista a informação acordada nessa validação, sem acrescentar especificações funcionais ou técnicas que não tenham sido discutidas.

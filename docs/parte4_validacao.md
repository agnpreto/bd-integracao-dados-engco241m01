-- 04_validacao
-- Nome:Beatriz Souza Da Silva
# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

## 1. Pontos a validar

A reunião terá como objetivo validar a integridade, a consistência e a exatidão dos dados referentes a fevereiro de 2025.

Serão verificados os seguintes pontos:

1. **Período dos registros:** conferir se as movimentações analisadas correspondem a fevereiro de 2025.
2. **Vendas:** verificar as quantidades vendidas, os valores unitários e os valores totais por produto.
3. **Pedidos de compra:** conferir as quantidades solicitadas, entregues e pendentes.
4. **Entradas de mercadorias:** verificar se as entradas estão relacionadas aos pedidos de compra correspondentes.
5. **Produtos:** conferir se os produtos utilizados nas movimentações estão cadastrados na tabela `produtos_filial`.
6. **Fornecedores:** verificar se os fornecedores informados nos cadastros e pedidos existem na tabela `fornecedor`.
7. **Integridade dos registros:** identificar valores nulos indevidos, duplicidades e relacionamentos inconsistentes.
8. **Consistência dos valores:** verificar quantidades e preços para identificar possíveis divergências.

Ao final, os resultados serão apresentados para que os responsáveis possam identificar e corrigir possíveis inconsistências.

## 2. Técnicas para garantir exatidão e precisão

Para garantir a exatidão e a precisão das informações, serão utilizadas as seguintes técnicas de validação:

1. **Contagem de registros:** utilizar `COUNT(*)` para conferir a quantidade de registros armazenados nas tabelas.
2. **Verificação de valores nulos:** utilizar `IS NULL` para identificar campos obrigatórios que estejam sem preenchimento.
3. **Identificação de duplicidades:** utilizar `GROUP BY` e `HAVING COUNT(*) > 1` para localizar registros repetidos.
4. **Conferência de relacionamentos:** utilizar `JOIN` para verificar se os identificadores de produtos, fornecedores e pedidos correspondem aos registros relacionados.
5. **Verificação de valores e quantidades:** utilizar condições com `WHERE` para identificar valores negativos, quantidades inconsistentes e possíveis divergências.
6. **Conferência do período:** utilizar filtros de data para garantir que a análise considere somente fevereiro de 2025.
7. **Comparação dos resultados:** confrontar os resultados das consultas SQL com os dados disponíveis na planilha original.

As consultas serão executadas no PostgreSQL, e os resultados serão registrados para análise e apresentação durante a reunião.

## 3. Consultas preparadas para a reunião

As consultas SQL utilizadas na validação estão armazenadas no arquivo `sql/04_validacao.sql`. Elas foram elaboradas para verificar a integridade, a consistência e a exatidão das informações importadas para o PostgreSQL.

### Validação das vendas

- **Consulta 1:** apresenta a quantidade de registros existentes em cada tabela, permitindo conferir os dados importados.
- **Consulta 2:** calcula a quantidade de vendas, o total de produtos vendidos e o valor total das vendas em fevereiro de 2025.
- **Consulta 3:** identifica vendas com data, quantidade ou identificação do produto ausentes.
- **Consulta 4:** verifica a existência de quantidades vendidas ou valores unitários negativos.
- **Consulta 5:** identifica vendas cujos produtos não possuem correspondência no cadastro da mesma filial.

### Validação dos pedidos de compra

- **Consulta 6:** identifica quantidades negativas nos pedidos de compra.
- **Consulta 7:** verifica pedidos cuja quantidade entregue é superior à quantidade solicitada.
- **Consulta 8:** identifica pedidos com informações ausentes.
- **Consulta 9:** contabiliza separadamente os pedidos sem data, quantidade solicitada ou identificação da filial.
- **Consulta 10:** contabiliza os pedidos sem data do pedido e sem data de entrega.

### Validação das entradas de mercadoria

- **Consulta 11:** identifica entradas com data, quantidade recebida ou identificação da filial ausentes.
- **Consulta 12:** verifica a existência de quantidades recebidas ou custos unitários negativos.
- **Consulta 13:** identifica entradas de mercadoria sem correspondência nos pedidos de compra.
- **Consulta 14:** contabiliza separadamente os campos ausentes nas entradas de mercadoria.
- **Consulta 15:** apresenta os dados das entradas sem pedido correspondente.

### Comparação entre pedidos e recebimentos

- **Consulta 16:** compara as quantidades entregues registradas nos pedidos com as quantidades recebidas nas entradas de mercadoria.
- **Consulta 17:** identifica os pedidos que apresentam diferenças entre essas quantidades.
- **Consulta 18:** classifica as divergências encontradas, diferenciando pedidos sem entrada correspondente daqueles que apresentam quantidades diferentes.

### Verificação de duplicidades e fornecedores

- **Consultas 19 a 21:** verificam possíveis duplicidades nas chaves primárias dos pedidos, entradas de mercadoria e vendas.
- **Consultas 22 a 24:** verificam a integridade das informações dos fornecedores associados aos produtos.

## 4. Resultados obtidos

A conferência inicial identificou **122 registros** distribuídos entre as cinco tabelas:

| Tabela | Quantidade de registros |
|---|---:|
| fornecedor | 20 |
| produtos_filial | 20 |
| pedido_compra | 29 |
| entradas_mercadoria | 20 |
| venda | 33 |
| **Total** | **122** |

As verificações de valores negativos não identificaram ocorrências nas vendas, nos pedidos de compra ou nas entradas de mercadoria.

Também não foram identificadas duplicidades nas chaves primárias analisadas ou inconsistências nas verificações de fornecedores associados aos produtos.

### 4.1. Problemas encontrados nas vendas

Foram identificadas 13 vendas sem correspondência na tabela `produtos_filial`, considerando todo o período disponível.

Dessas ocorrências, 6 correspondem a fevereiro de 2025, envolvendo os produtos P22, P23, P24, P25, P26 e P27.

A comparação com a planilha original mostrou que o cadastro `produtos_filial` contém os produtos P1 a P20. Portanto, a ausência de correspondência já está presente nos dados fornecidos.

Esses registros deverão ser apresentados ao cliente para confirmar se existem produtos que não foram cadastrados ou se os identificadores precisam ser corrigidos.

### 4.2. Problemas encontrados nos pedidos de compra

Na primeira validação, foram identificados:

- 29 pedidos sem data do pedido;
- 29 pedidos sem data de entrega.

Ao comparar os registros do PostgreSQL com a planilha original `base_teste.xlsx`, foi constatado que as datas estavam preenchidas na planilha, mas não haviam sido armazenadas no banco.

Para corrigir o problema, foi desenvolvido o script `scripts/corrigir_datas.py`, responsável por localizar os pedidos pelos seus identificadores e preencher os campos de data ausentes.

Após a execução do script, uma nova consulta confirmou os seguintes resultados:

| Verificação | Resultado |
|---|---:|
| Total de pedidos | 29 |
| Pedidos com data do pedido | 29 |
| Pedidos com data de entrega | 29 |

**Resultado:** todas as datas dos pedidos de compra foram preenchidas com sucesso.

Também foram verificadas as quantidades solicitadas e entregues, sem identificação de valores negativos ou quantidades entregues superiores às solicitadas.

### 4.3. Problemas encontrados nas entradas de mercadoria

Na validação inicial, foram identificadas 20 entradas de mercadoria sem data de entrada.

A comparação com a planilha original confirmou que essas datas estavam presentes no arquivo Excel.

O script `scripts/corrigir_datas.py` também foi utilizado para preencher as datas ausentes na tabela `entradas_mercadoria`.

Após a correção, foram obtidos os seguintes resultados:

| Verificação | Resultado |
|---|---:|
| Total de entradas | 20 |
| Entradas com data preenchida | 20 |

**Resultado:** todas as datas de entrada foram preenchidas com sucesso.

Entretanto, permaneceram duas entradas sem correspondência com os pedidos de compra, relacionadas aos produtos P19 e P20.

Nesses registros, a ordem de compra apresenta divergência em relação aos pedidos correspondentes, sendo necessária a confirmação com o cliente.

### 4.4. Divergências entre pedidos e recebimentos

A comparação entre as tabelas `pedido_compra` e `entradas_mercadoria` identificou 18 registros com diferenças entre as quantidades entregues e as quantidades recebidas.

Essas divergências não foram corrigidas automaticamente, pois podem representar situações reais, como recebimentos parciais ou diferenças nos registros de movimentação.

Os resultados deverão ser apresentados ao cliente para confirmar as quantidades corretas.

## 5. Erros encontrados nos dados

A execução das consultas identificou as seguintes inconsistências e pendências:

| Tabela | Problema identificado | Quantidade | Situação |
|---|---|---:|---|
| pedido_compra | Data do pedido ausente na importação inicial | 29 | Corrigido |
| pedido_compra | Data de entrega ausente na importação inicial | 29 | Corrigido |
| entradas_mercadoria | Data de entrada ausente na importação inicial | 20 | Corrigido |
| entradas_mercadoria / pedido_compra | Divergência na ordem de compra dos produtos P19 e P20 | 2 | Pendente de validação |
| pedido_compra / entradas_mercadoria | Divergência entre quantidade entregue e recebida | 18 | Pendente de validação |
| venda / produtos_filial | Vendas de fevereiro de 2025 sem correspondência no cadastro de produtos | 6 | Pendente de validação |

**Observação:** as quantidades apresentadas não representam necessariamente registros distintos. As inconsistências pendentes deverão ser discutidas com o cliente antes de qualquer alteração nos dados.

## 6. Correções realizadas

Durante o processo de validação, foi identificada uma inconsistência na importação das datas das tabelas `pedido_compra` e `entradas_mercadoria`.

Para realizar a correção de forma segura, foram adotadas as seguintes medidas:

1. Criação das tabelas de backup `backup_pedido_compra` e `backup_entradas_mercadoria`.
2. Conferência das datas existentes na planilha original.
3. Comparação dos identificadores dos registros da planilha com os registros do PostgreSQL.
4. Desenvolvimento e execução do script `scripts/corrigir_datas.py`.
5. Atualização dos campos de data ausentes, preservando as datas já preenchidas.
6. Execução de consultas SQL para confirmar os resultados.

O script encontrou correspondência para os 29 pedidos e para as 20 entradas de mercadoria.

Após a execução, as consultas confirmaram que todos os campos de data analisados estavam preenchidos.

As correções foram realizadas sem excluir ou recriar os registros originais.

## 7. Conclusão da validação

A validação permitiu verificar a integridade e a consistência dos registros importados para o PostgreSQL, identificar problemas e corrigir as datas ausentes nos pedidos de compra e nas entradas de mercadoria.

As consultas confirmaram a presença de 122 registros nas cinco tabelas analisadas e não identificaram valores negativos nas verificações realizadas.

As datas ausentes foram corrigidas e posteriormente conferidas por meio de consultas SQL.

Permanecem pendentes de confirmação com o cliente as divergências entre quantidades entregues e recebidas, as entradas sem correspondência nos pedidos de compra e as vendas relacionadas a produtos não encontrados no cadastro.

Dessa forma, a validação contribuiu para melhorar a qualidade dos dados armazenados e identificar os pontos que ainda necessitam de esclarecimento antes da conclusão definitiva do processo de integração.
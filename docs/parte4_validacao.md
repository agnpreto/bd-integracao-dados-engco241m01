# Parte 4: Roteiro de Validação com o Cliente (fevereiro/2025)

## 1. Pontos a validar

Ordem sugerida para a reunião:

1. **Período.** Confirmar a janela 01/02–28/02 por `data_emissao`. Das 33 vendas, 14 são de fevereiro; as demais são de janeiro e março. Validar se a presença de outros meses é esperada.
2. **Totais do mês.** Fevereiro: 14 linhas, 173,22 un., R$ 14.093,17. Cliente compara com o relatório do sistema de origem (prova de completude).
3. **Regra de valor.** Confirmar `valor = qtde × valor_unitario` e a existência de descontos, impostos, devoluções ou cancelamentos fora da base.
4. **Cadastro de produtos.** Seis produtos vendidos em fevereiro (P22–P27) não constam em `produtos_filial`: R$ 3.241,24, cerca de 23% do mês. Definir se são cadastros pendentes ou códigos incorretos.
5. **Preços.** Todas as vendas de produtos cadastrados divergem de `preco_venda`. Definir a semântica de `preco_unitario`, `preco_compra` e `preco_venda` e qual prevalece na venda.
6. **Pedidos sem ordem.** 11 pedidos com `ordem_compra = 0`; as entradas NFE19 e NFE20 referenciam as ordens 19 e 20, inexistentes em `pedido_compra`. Impacta o relatório de pedidos não recebidos. Definir se pedido sem ordem é válido e como recuperar a ordem.
7. **Inconsistência de datas.** Em 20 dos 29 pedidos, `data_entrega < data_pedido`; 9 entradas são anteriores ao pedido. Definir qual data é a correta.
8. **Pedido × recebimento.** Nenhum pedido tem `qtde_entregue` igual ao total das entradas; 7 entradas excedem a quantidade pedida (ex.: pedido 14, recebido 64); o custo da nota nunca coincide com o preço do pedido. Definir tolerâncias de quantidade e preço e a fonte de verdade (pedido ou nota).
9. **Possíveis duplicidades.** Bloco de 9 linhas de pedido fora da tabela e pedidos/vendas com datas e preços repetidos. Definir se são lançamentos válidos, cópias ou resíduo de colagem.
10. **Interpretação do enunciado.** "Requisitado mais de 10 vezes" = `qtde_pedida > 10`; "requisição pendente" = pedido sem nenhuma entrada. Confirmar as regras.

## 2. Técnicas de garantia de exatidão e precisão

- **Reconciliação de totais:** contagens e somas da planilha vs. banco (122 vs. 122) e, depois, vs. relatório do cliente.
- **Integridade referencial:** detecção de órfãos (venda sem produto, entrada sem pedido, produto sem fornecedor). FKs previnem recorrência.
- **Regras de negócio:** quantidade e preço positivos; entregue ≤ pedido; entrada ≥ data do pedido.
- **Detecção de duplicidade:** registros idênticos ou quase idênticos que inflam totais.
- **Profiling:** distribuição de unidades de medida, faixas de preço e datas para identificar outliers e grafias divergentes.
- **Precisão numérica:** `numeric` em vez de ponto flutuante.
- **Rastreabilidade:** linhas não carregadas limpas são registradas com linha de origem e motivo.
- **Amostragem:** registros válidos aleatórios apresentados ao cliente, além das exceções.

## 3. Consultas de apoio

Arquivo `sql/04_validacao.sql`. Somente leitura.

### A) Conferência de totais

| Consulta | Descrição |
| --- | --- |
| R01 | Contagem por tabela (esperado: 20, 20, 29, 20, 33) |
| R02 | Vendas de fevereiro: linhas, vendas, quantidade, valor (R$) |
| R03 | Idem R02, por filial |
| R04 | Pedidos de compra de fevereiro |
| R05 | Entradas de fevereiro (notas, quantidade, valor) |

### B) Detecção de erros (0 linhas = sem ocorrência)

| Consulta | Descrição |
| --- | --- |
| V01 | Produtos vendidos sem cadastro |
| V02 | Vendas com quantidade nula, zero ou negativa |
| V03 | Vendas com valor unitário ≤ 0 |
| V04 | Vendas fora de fev/2025 |
| V05 | Unidades de medida distintas em `venda` |
| V06 | Vendas com preço diferente do cadastro |
| V07 | Vendas possivelmente duplicadas |
| P01 | Produtos de pedidos sem cadastro |
| P02 | Pedidos com fornecedor inexistente |
| P03 | Pedidos sem fornecedor |
| P04 | Pedidos com entregue > pedido |
| P05 | Pedidos com `data_entrega < data_pedido` |
| P06 | Pedidos com quantidade ou preço nulo, zero ou negativo |
| P07 | Ordens de compra repetidas entre pedidos (inclui ordem 0) |
| P08 | Descrição do pedido divergente do cadastro |
| P09 | `qtde_entregue` divergente do total das entradas |
| E01 | Entradas sem pedido correspondente |
| E02 | Entradas com quantidade > pedida |
| E03 | Entradas anteriores ao pedido |
| E04 | Entradas com custo zero ou divergente do preço do pedido |
| E05 | Entradas com quantidade nula, zero ou negativa |
| E06 | Mesma NF-e com datas de entrada distintas |
| E07 | Entradas em filial diferente da do pedido |
| F01 | Produtos com fornecedor inexistente |
| F02 | Produtos sem fornecedor |
| F03 | Produtos com estoque negativo |
| F04 | Produtos com `preco_venda <= preco_compra` |
| F05 | Mesmo produto com descrições distintas entre filiais |
| F06 | Códigos de produto com espaços ou fora do padrão |
| F07 | Fornecedores com mesma razão social e ids distintos |

### C) Respostas das Partes 2 e 3

Em `sql/02_consultas.sql` e `sql/03_transformacoes.sql`.

| Consulta | Descrição |
| --- | --- |
| C1 | Total vendido em fevereiro por produto (quantidade e R$) |
| C2 | Produtos requisitados e não recebidos |
| Transformações | Produtos com quantidade requisitada > 10, no formato `12345 - Detergente`, datas em `DD/MM/YYYY` |

## 4. Erros encontrados nos dados

| Tabela | Problema | Qtde | Consulta |
| --- | --- | --- | --- |
| venda | Produto sem cadastro em `produtos_filial` (P21–P28) | 8 combinações filial/produto | V01 |
| venda | Fora de fev/2025 (12 em janeiro, 7 em março) | 19 de 33 | V04 |
| venda | Preço divergente de `preco_venda` (todas as vendas de P1–P20) | 20 | V06 |
| pedido_compra | `ordem_compra = 0` repetida (pedidos 19–29) | 11 | P07 |
| pedido_compra | `data_entrega < data_pedido` | 20 de 29 | P05 |
| pedido_compra | `qtde_entregue` ≠ total das entradas | 18 (todos com entrada) | P09 |
| pedido_compra | Bloco de 9 linhas (P12–P20) deslocado para as colunas M–W | 9 | Detectado na leitura (aviso "colunas não usadas") |
| entradas_mercadoria | Sem pedido correspondente (NFE19 e NFE20, ordens 19 e 20) | 2 | E01 |
| entradas_mercadoria | Quantidade recebida > pedida (P2, P3, P5, P7, P11, P15, P16) | 7 | E02 |
| entradas_mercadoria | Entrada anterior ao pedido | 9 | E03 |
| entradas_mercadoria | Custo ≠ `preco_compra` do pedido | 18 (todas com pedido) | E04 |

**Sem ocorrência:** V02, V03, V05 (todas `UN`), V07, P01, P02 (após normalização do id), P03, P04, P06, P08, E05, E06, E07, F01–F07.

### Análise dos achados

- **`ordem_compra = 0`.** Os pedidos de P19 e P20 (ids 19 e 20) têm ordem 0, enquanto NFE19 e NFE20 apontam para as ordens 19 e 20 (E01). Por isso C2 os lista como não recebidos, embora tenham entrada. Os pedidos 21–29 também têm ordem 0 e entregue 0. Os pares (19, 28) e (20, 29) repetem `(ordem 0, P19|P20, item 1)`, o que impossibilita a FK entrada → pedido.
- **Bloco deslocado (colunas M–W, linhas 22–30 de `pedido_compra`).** 9 pedidos completos (P12–P20, ordens 12–20), sem `pedido_id` e `fornecedor_id`. P12–P18 são idênticos aos pedidos 12–18 carregados. P19 e P20 divergem dos carregados: ordens 19 e 20 (carregados: 0), qtde pedida 40 e 86 (carregados: 20 e 25), entregue 0 e 78. São as ordens referenciadas por NFE19 e NFE20. Sem `pedido_id`, não foram carregados; cliente deve confirmar se são válidos, duplicatas ou resíduo de colagem.
- **Possíveis cópias (hipótese).** Pedidos 21–29 repetem datas, descrição, preço e fornecedor dos pedidos 12–20, variando apenas a quantidade. Vendas 21 e 29–33 repetem valores unitários de vendas anteriores (61,85; 14,41; 139,80; 185,23; 182,51; 68,54), com códigos P21–P28 sem cadastro.
- **Divergência sistemática pedido × entrada.** Custo diverge em 18/18 entradas e `qtde_entregue` diverge em 18/18 pedidos, indicando que `qtde_entregue` e `preco_compra` do pedido não têm a mesma origem das entradas.
- **Id de fornecedor.** Cadastro em `F1`–`F20`, pedidos em `1`–`20`. A verificação `'F' || fornecedor_id` casou os 29 pedidos (diferença apenas de formato). O prefixo foi removido na carga (id numérico, conforme enunciado); P02 e F01 retornam 0 linhas.
- **Período.** Apenas 14 das 33 vendas são de fevereiro; C1 e R02 cobrem menos da metade da base.

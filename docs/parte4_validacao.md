# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

## 1. Pontos a validar
* **Faturamento e Saídas:** Confrontar o volume total vendido e o faturamento de fevereiro/2025 com o relatório gerencial do ERP legado.
* **Fluxo de Compras vs. Recebimento:** Validar por que ordens de compra constam com quantidade entregue divergente das notas fiscais de entrada.
* **Precificação e Margem:** Confirmar se os preços de compra maiores que os de venda são erros de cadastro ou liquidação de estoque.
* **Pedidos sem Ordem de Compra:** Verificar a validade dos pedidos 21 a 29 que possuem `ordem_compra = 0`.

## 2. Técnicas para garantir exatidão e precisão
* **Batimento de Totais (Checksums):** Comparar a contagem de registros e a soma financeira total entre as abas originais e as tabelas carregadas.
* **Amostragem Dirigida:** Selecionar 5 notas fiscais e 5 pedidos críticos (com divergências) para conferência documental junto ao cliente.
* **Validação de Regras de Negócio:** Execução de queries de auditoria para identificar anomalias lógicas (datas invertidas e preços invertidos).

## 3. Consultas preparadas para a reunião
As consultas estão salvas em `sql/04_validacao.sql`:
1. **Auditoria de prazos (`data_entrega < data_pedido`):** Lista pedidos cuja data de entrega registrada é anterior à própria emissão do pedido.
2. **Conciliação Pedido x NFE:** Cruza `pedido_compra` e `entradas_mercadoria` por `ordem_compra` e `produto_id` para evidenciar diferenças entre o que o pedido diz ter sido entregue e o que realmente entrou via nota fiscal.
3. **Auditoria de margem (`preco_compra > preco_venda`):** Identifica produtos cadastrados com custo superior ao preço de venda.
4. **Pedidos sem ordem de compra (`ordem_compra = 0`):** Isola os registros duplicados/incompletos no final da tabela de pedidos.

## Erros encontrados nos dados

| Tabela | Problema | Quantidade | Consulta que mostra |
| --- | --- | --- | --- |
| pedido_compra | Data de entrega anterior à data do pedido | 13 registros | Consulta 1 (`04_validacao.sql`) |
| pedido_compra / entradas_mercadoria | Divergência entre `qtde_entregue` no pedido e `qtde_recebida` na NFE | 18 ordens | Consulta 2 (`04_validacao.sql`) |
| produtos_filial | Preço de compra maior que o preço de venda | 11 produtos | Consulta 3 (`04_validacao.sql`) |
| pedido_compra | Pedidos parciais/duplicados com `ordem_compra = 0` | 9 registros | Consulta 4 (`04_validacao.sql`) |


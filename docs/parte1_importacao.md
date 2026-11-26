# Parte 1: Documentação do processo de importação

## Ferramenta utilizada
* **SGBD:** MySQL 8.0 (Linux Mint)
* **Script de Importação:** Python 3 (`pandas`, `openpyxl`, `mysql-connector-python`)
* **Cliente SQL:** MySQL Workbench / MySQL CLI

## Estrutura da planilha

| Aba | Coluna | Tipo | Observação |
| --- | --- | --- | --- |
| fornecedor | idfornecedor, razao_social | Texto | 20 registros (F1 a F20). |
| produtos_filial | filial_id, idproduto, descricao, estoque, preco_unitario, preco_compra, preco_venda, idfornecedor | Numérico / Texto | 20 produtos (P1 a P20). |
| pedido_compra | pedido_id, data_pedido, item, produto_id, descricao_produto, ordem_compra, qtde_pedida, filial_id, data_entrega, qtde_entregue, preco_compra, fornecedor_id | Numérico / Data / Texto | 29 linhas; linhas 21-29 tinham colunas extras deslocadas à direita e faltava `qtde_pendente`. |
| entradas_mercadoria | data_entrada, nro_nfe, item, produto_id, descricao_produto, ordem_compra, qtde_recebida, filial_id, custo_unitario | Data / Texto / Numérico | 20 registros de notas fiscais de entrada. |
| venda | venda_id, data_emissao, horariomov, produto_id, qtde_vendida, valor_unitario, filial_id, item, unidade_medida | Numérico / Data / Texto | 40 registros de vendas realizadas em fevereiro/2025. |

## Erros encontrados no DDL e como foram corrigidos

| Tabela | Erro | Correção |
| --- | --- | --- |
| fornecedor, produtos_filial, pedido_compra, venda | Faltava o comando `CREATE TABLE` no início e `);` no final. | Adicionada a sintaxe completa de criação de tabela em todas. |
| fornecedor | Coluna escrita `idforncedor` e PK citando `idproduto` inexistente. | Corrigido nome para `idfornecedor` e ajustada PK apenas para `(idfornecedor)`. |
| produtos_filial | Erros de digitação (`decricao`, `idfonecedor`), tipo `int4` no fornecedor, falta de vírgula na PK e PK citando `idproduto` vs `produto_id`. | Corrigidos nomes, alterado `idfornecedor` para `VARCHAR(25)`, adicionada vírgula e padronizado `idproduto`. |
| entradas_mercadoria | Chave primária citava `ordem_compra`, mas a coluna não existia na tabela. | Adicionada a coluna `ordem_compra DOUBLE DEFAULT 0 NOT NULL`. |

## Erros encontrados no script de importação e como foram corrigidos

| Erro | Efeito | Correção |
| --- | --- | --- |
| Conversão de `fornecedor_id` para `int()` na importação de `pedido_compra`. | Falha de conversão (`ValueError`) ao encontrar códigos alfanuméricos ou incompatibilidade com tipo `VARCHAR`. | Alterado para `str(row["fornecedor_id"]).strip()`. |
| Função `excel_para_data` tratava apenas números inteiros (seriais do Excel). | Datas já lidas como objeto `datetime` pelo `pandas` caíam no `except` e eram gravadas como `NULL` no banco. | Adicionada verificação `isinstance(valor, (datetime, pd.Timestamp))` para retornar `.date()`. |
| Colunas extras deslocadas nas linhas 21 a 29 da aba `pedido_compra`. | Leitura de colunas excedentes sem correspondência na tabela. | Mantido recorte `df.iloc[:, :12]` e cálculo dinâmico de `qtde_pendente = qtde_pedida - qtde_entregue`. |

## Tratamentos aplicados aos dados
* **Conversão de tipos:** Datas convertidas para o formato ISO (`YYYY-MM-DD`) e valores numéricos padronizados.
* **Normalizações:** Remoção de espaços em branco (`strip()`) nas strings e cabeçalhos das colunas.
* **Validações:** Cálculo automático de `qtde_pendente` durante a carga e uso de `INSERT IGNORE` respeitando as chaves primárias.

## Conferência final

| Tabela | Linhas na planilha | Linhas no banco |
| --- | --- | --- |
| fornecedor | 20 | 20 |
| produtos_filial | 20 | 20 |
| pedido_compra | 29 | 29 |
| entradas_mercadoria | 20 | 20 |
| venda | 40 | 40 |

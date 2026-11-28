# Parte 1: Processo de Importação

## 1. Ambiente e execução

- **Stack:** Python 3, pandas e openpyxl (leitura de `base_teste.xlsx`), psycopg2 (escrita em PostgreSQL). Script: `scripts/importar.py` (versão corrigida do original).
- **Cliente SQL:** DBeaver (DDL e consultas).
- **Procedimento:**
  1. Criar o esquema: `sql/01_ddl_postgres.sql`.
  2. Definir a senha via `PGPASSWORD` (sem credenciais no código).
  3. Executar `python scripts/importar.py --limpar` na raiz do repositório.
  4. O script reporta por aba: linhas lidas, inseridas, duplicadas e rejeitadas. O detalhe é gravado em `importacao_problemas.csv`.
- **Escopo:** carga validada no PostgreSQL. O DDL para MySQL (`sql/01_ddl_mysql.sql`) não foi executado.

## 2. Estrutura da planilha

Tipos inferidos a partir dos valores de `dados/base_teste.xlsx`.

| Aba | Coluna | Tipo | Observação |
| --- | --- | --- | --- |
| fornecedor | idfornecedor | texto (`F1`–`F20`) | Prefixo `F` removido na carga (integer) |
| fornecedor | razao_social | texto | |
| produtos_filial | filial_id | inteiro | |
| produtos_filial | idproduto | texto (`P1`…) | Cabeçalho divergente do banco; mapeado para `produto_id` |
| produtos_filial | descricao | texto | |
| produtos_filial | estoque, preco_unitario, preco_compra, preco_venda | decimal | |
| produtos_filial | idfornecedor | texto (`F1`…) | Prefixo `F` removido na carga |
| pedido_compra | pedido_id, item, ordem_compra, filial_id | inteiro | `ordem_compra = 0` em 11 pedidos |
| pedido_compra | data_pedido, data_entrega | data | |
| pedido_compra | produto_id, descricao_produto | texto | |
| pedido_compra | qtde_pedida, qtde_entregue, preco_compra | decimal | |
| pedido_compra | fornecedor_id | inteiro (1–20) | Já numérico |
| pedido_compra | qtde_pendente | n/a | Ausente; derivada: `qtde_pedida - qtde_entregue` |
| pedido_compra | colunas M–W (sem cabeçalho) | data, inteiro, texto, decimal | Bloco de 9 linhas (P12–P20) deslocado; não importado (Parte 4, achado 12) |
| entradas_mercadoria | data_entrada | data | |
| entradas_mercadoria | nro_nfe | texto (`NFE1`…) | |
| entradas_mercadoria | item, ordem_compra, filial_id | inteiro | |
| entradas_mercadoria | produto_id, descricao_produto | texto | |
| entradas_mercadoria | qtde_recebida, custo_unitario | decimal | |
| venda | venda_id, filial_id, item | inteiro | |
| venda | data_emissao | data | |
| venda | horariomov | hora (`08:00:00`) | |
| venda | produto_id | texto | |
| venda | qtde_vendida, valor_unitario | decimal | |
| venda | unidade_medida | texto (`UN`) | |

## 3. Correções no DDL

| Tabela | Defeito | Correção |
| --- | --- | --- |
| entradas_mercadoria | PK referencia `ordem_compra`, inexistente na tabela | Coluna `ordem_compra bigint NOT NULL` criada |
| produtos_filial | Vírgula ausente antes de `CONSTRAINT` (erro de sintaxe) | Vírgula adicionada |
| produtos_filial | PK referencia `idproduto` (coluna real: `produto_id`) | PK `(filial_id, produto_id)` |
| fornecedor | PK referencia `idproduto`, alheio à tabela | PK apenas em `idfornecedor` |
| fornecedor, produtos_filial | Identificadores com erro de grafia: `idforncedor`, `idfonecedor`, `decricao` | `idfornecedor`, `descricao` |
| fornecedor, produtos_filial, pedido_compra | Id de fornecedor com tipos distintos (`varchar(25)` / `int4`) e formatos distintos (`F1` / `1`) | `integer` nas três tabelas; prefixo removido na carga; FKs criadas |
| pedido_compra, entradas_mercadoria | `pedido_id`, `item`, `ordem_compra` como `float8` | `bigint` / `integer` |
| todas | Quantidades, preços e estoque como `float8` (erro de arredondamento) | `numeric` |
| produtos_filial | `produto_id varchar(255)` (demais tabelas: `varchar(25)`) | `varchar(25)` |
| venda | `filial_id int8` (demais: `int4`) | `integer` |
| venda, pedido_compra, entradas_mercadoria | Defaults que mascaram ausência de dado: `produto_id ''`, `filial_id 1`, `item 0`, `fornecedor_id 0` | Removidos das colunas-chave; fornecedor ausente = `NULL` |
| venda | PK nomeada `pk_consumo` | `pk_venda` |
| todas | Sem FKs e sem índices | FKs onde os dados permitem; índice em `pedido_compra(ordem_compra, produto_id)`. FKs violadas pelos dados estão comentadas no DDL, com justificativa |
| todas | Sintaxe específica do PostgreSQL (`public.`, `int8`, `float8`, `::character varying`) | DDL MySQL separado |
| pedido_compra | `qtde_pendente` derivada, sujeita a divergência | Mantida; calculada na carga |

## 4. Correções no script de importação

| Defeito | Efeito | Correção |
| --- | --- | --- |
| `conn.rollback()` dentro do loop | Erro em uma linha desfaz todas as inserções da aba (commit apenas ao final) | `SAVEPOINT` por linha |
| `print(len(df))` como total inserido | Reporta o total da planilha, não o efetivamente gravado | `rowcount` e `SELECT COUNT(*)` |
| `ON CONFLICT DO NOTHING` sem verificação | Duplicatas descartadas silenciosamente | Contabilizadas como DUPLICADA e registradas no log |
| `except:` genérico em `excel_para_data` | Data inválida ou já tipada vira `NULL` sem aviso | Conversor trata serial Excel, `date` e texto; erro registrado |
| `str(valor)` em campos vazios | Vazio vira `"nan"` | Conversores retornam `None` |
| Valores sintéticos: `ordem_compra`→0, `filial_id`→1, `item`→0 | Linhas órfãs agrupadas em chave falsa e descartadas pelo `DO NOTHING` | Chave vazia rejeita a linha; medida vazia (padrão 0) gera AVISO |
| `produtos_filial`: lê `row["idproduto"]` e grava em `produto_id` | Falha total se o cabeçalho divergir | Aceita nomes alternativos; imprime o mapeamento |
| `pedido_compra`: `iloc[:, :12]` e renomeação posicional | Reordenação de colunas desloca valores; colunas extras descartadas sem aviso | Leitura por nome de cabeçalho; aviso para colunas não usadas |
| `float()` em colunas inteiras | `1234.5` truncado silenciosamente | `inteiro()` rejeita não inteiros |
| `horariomov` via `str()` | `time` ou fração do dia gera texto inválido | Conversor `hora()` |
| `idfornecedor` tratado como `str` e `int` conforme a tabela | `F1` não converte para `int4`; formatos incompatíveis | `id_fornecedor()` normaliza `F12`/`12`/`12.0` para inteiro |
| Senha `"1234"` hardcoded; comentário com porta MySQL 3006 | Credencial exposta; porta correta é 3306; script só funciona com PostgreSQL | Conexão por variáveis de ambiente (`PGPASSWORD`, etc.) |
| Mensagem "concluída com sucesso" incondicional | Falso positivo com linhas perdidas | Resumo por aba, log CSV e exit code 1 em caso de rejeição ou duplicata |

## 5. Tratamento dos dados

- **Tipagem:** conversores rejeitam valores inválidos em vez de gravar lixo. Datas: serial Excel, `date` e texto (`DD/MM/YYYY`, `YYYY-MM-DD`). Leitura com `dtype=object` para evitar coerção de inteiros em float pelo pandas.
- **Id de fornecedor:** `F1`–`F20` (fornecedor, produtos_filial) e `1`–`20` (pedido_compra) convertidos para inteiro. A verificação `'F' || fornecedor_id` casou os 29 pedidos com o cadastro. O id numérico é exigido pelo enunciado e viabiliza as FKs.
- **Texto:** `strip()` em todos os campos; vazio → `NULL`.
- **Cabeçalhos:** `idproduto` → `produto_id`; leitura sempre por nome.
- **Campo derivado:** `qtde_pendente = qtde_pedida - qtde_entregue`. Se presente na origem, é comparada e a divergência gera AVISO.
- **Validações:** chave vazia rejeita a linha; medida `NOT NULL` com padrão 0 gera AVISO; chaves duplicadas são contadas e registradas; erros isolados por `SAVEPOINT`; rejeições gravadas em `importacao_problemas.csv`.
- **Colunas ignoradas:** M–W de `pedido_compra` (sem cabeçalho), 9 linhas de pedido sem `pedido_id` e `fornecedor_id`. Não importadas por impossibilidade de atribuição sem inferência de dados.
- **Pós-carga:** ajuste de sequência desnecessário (id de fornecedor numérico sem sequência; a trigger usa `MAX(idfornecedor) + 1`).

## 6. Conferência final

| Tabela | Planilha | Banco |
| --- | --- | --- |
| fornecedor | 20 | 20 |
| produtos_filial | 20 | 20 |
| pedido_compra | 29 | 29 |
| entradas_mercadoria | 20 | 20 |
| venda | 33 | 33 |

Total: 122 lidas, 122 inseridas, 0 rejeitadas, 0 duplicadas. A consulta `R01` (`sql/04_validacao.sql`) reproduz a conferência no banco.

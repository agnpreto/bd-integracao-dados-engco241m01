# Parte 1: Documentação do processo de importação

## Ferramenta utilizada

- **Importação:** script Python `scripts/importar.py` (Python , `pandas` + `openpyxl` para ler a planilha, `psycopg2` para gravar). É o script do estagiário, corrigido; as falhas dele estão na seção própria abaixo.
- **Bancos:** PostgreSQL (carga completa e conferida) e MySQL (o DDL corrigido foi executado e a trigger testada; a carga de dados foi feita só no PostgreSQL, porque o script usa `psycopg2`).
- O script é idempotente (rodar duas vezes não duplica; testado) e termina com código de saída diferente de zero se alguma linha for rejeitada ou se as contagens não baterem.
- A planilha `dados/base_teste.xlsx` não foi alterada.

## Estrutura da planilha

Cinco abas. Tipos conforme gravados no Excel; "Coluna no DDL" só aparece quando o nome muda.

| Aba | Coluna | Tipo | Observação |
| --- | --- | --- | --- |
| venda (33 linhas) | venda_id | inteiro | 1 a 33, sem repetição |
| venda | data_emissao | data | formato de exibição `m/d/aaaa`, diferente das outras abas (`aaaa-mm-dd`); o valor é uma data real, não texto |
| venda | horariomov | texto | sempre `08:00:00` nas 33 linhas |
| venda | produto_id | texto | `P1`..`P28` (só `P1`..`P20` existem em produtos_filial) |
| venda | qtde_vendida | decimal | 5 valores fracionados (38,6; 20,04; 2,86; 37,11; 3,11) |
| venda | valor_unitario | decimal | preço praticado |
| venda | filial_id | inteiro | 1, 2 e 3 |
| venda | item | inteiro | sempre 1 |
| venda | unidade_medida | texto | sempre `UN` |
| pedido_compra (29 linhas) | pedido_id, item | inteiro | |
| pedido_compra | data_pedido, data_entrega | data | `aaaa-mm-dd` |
| pedido_compra | produto_id, descricao_produto | texto | |
| pedido_compra | ordem_compra | inteiro | `0` em 11 linhas (pedidos 19 a 29) |
| pedido_compra | qtde_pedida, qtde_entregue | inteiro | |
| pedido_compra | filial_id, fornecedor_id | inteiro | `fornecedor_id` é numérico (1..20) |
| pedido_compra | preco_compra | decimal | |
| pedido_compra | **colunas M a W (sem cabeçalho)** | misto | **bloco fora do layout, com dados nas linhas 22 a 30 (9 linhas)**: repete as colunas da tabela e traz `qtde_pendente`, mas sem `pedido_id` e sem `fornecedor_id`. Não faz parte do DDL e não foi importado; ver "Tratamentos" |
| entradas_mercadoria (20 linhas) | data_entrada | data | `aaaa-mm-dd` |
| entradas_mercadoria | nro_nfe | texto | `NFE1`..`NFE20` |
| entradas_mercadoria | item, ordem_compra, qtde_recebida, filial_id | inteiro | |
| entradas_mercadoria | produto_id, descricao_produto | texto | |
| entradas_mercadoria | custo_unitario | decimal | |
| produtos_filial (20 linhas) | filial_id | inteiro | só filial 1 |
| produtos_filial | idproduto | texto | no DDL a coluna é `produto_id` |
| produtos_filial | descricao | texto | no DDL estava `decricao` |
| produtos_filial | estoque | inteiro | |
| produtos_filial | preco_unitario, preco_compra, preco_venda | decimal | |
| produtos_filial | idfornecedor | texto | `F1`..`F20`, com prefixo `F`; no DDL `idfonecedor int4` |
| fornecedor (20 linhas) | idfornecedor | texto | `F1`..`F20`; no DDL `idforncedor` |
| fornecedor | razao_social | texto | |

## Erros encontrados no DDL e como foram corrigidos

Resultado de rodar `01_ddl_enunciado.sql` no PostgreSQL: **3 das 5 tabelas falham** (`entradas_mercadoria`, `produtos_filial`, `fornecedor`). No MySQL falham **as 5**.

| Tabela | Erro | Correção |
| --- | --- | --- |
| entradas_mercadoria | `column "ordem_compra" named in key does not exist`: a PK usa `ordem_compra`, mas a coluna não foi declarada. É justamente a coluna que liga a entrada ao pedido | Criada `ordem_compra bigint NOT NULL` |
| produtos_filial | `syntax error at or near "("`: falta a vírgula depois de `idfonecedor int4 NULL` antes do `CONSTRAINT` | Vírgula adicionada |
| produtos_filial | A PK cita `idproduto`, que não existe (a coluna é `produto_id`) | PK `(filial_id, produto_id)` |
| produtos_filial | Nomes com erro de digitação: `decricao`, `idfonecedor` | `descricao`, `idfornecedor` |
| produtos_filial | `filial_id` é `NULL` mas faz parte da PK | `NOT NULL` |
| produtos_filial | `produto_id varchar(255)` enquanto nas outras tabelas é `varchar(25)` | Padronizado em `varchar(25)` |
| fornecedor | `column "idproduto" named in key does not exist`: a PK inclui `idproduto`, que não é coluna de fornecedor (fornecedor não tem produto) | PK só `idfornecedor` |
| fornecedor | Nome com erro de digitação `idforncedor`; tipo `varchar(25)` enquanto `produtos_filial.idfonecedor` e `pedido_compra.fornecedor_id` são `int4` (as três tabelas não conversavam) | `idfornecedor integer` (identity). A planilha traz `F8`; o prefixo `F` é removido na carga. Assim o id bate com `pedido_compra.fornecedor_id` e a trigger da Parte 3 pode gerar ids numéricos |
| venda | Roda no PostgreSQL, mas `DEFAULT ''::character varying` é sintaxe só do PostgreSQL (quebra no MySQL) e `produto_id DEFAULT ''` deixa gravar venda sem produto como parte da chave | Default removido; `CHECK (produto_id <> '')` |
| venda | `filial_id DEFAULT 1` mascara filial ausente como filial 1 | Default removido (`NOT NULL` sem default) |
| venda | PK chamada `pk_consumo` (nome de outra tabela) | `pk_venda` |
| venda | `horariomov varchar(8)` guarda hora como texto | `time` |
| pedido_compra | `pedido_id`, `item`, `ordem_compra` como `float8`, e `pedido_id`/`item` fazem parte da PK: igualdade e junção por número de ponto flutuante são frágeis | `bigint` / `integer` |
| pedido_compra | `ordem_compra NOT NULL DEFAULT 0`: o 0 parece uma ordem de compra real e faz requisição sem ordem parecer vinculada | `NULL` permitido; 0 da planilha vira `NULL` na carga |
| pedido_compra | `fornecedor_id DEFAULT 0`, mas o fornecedor 0 não existe | Default removido; FK para `fornecedor` |
| pedido_compra | `qtde_pendente` é coluna digitada, mas não vem da planilha e é sempre `pedida - entregue` | Coluna gerada (`GENERATED ALWAYS AS ... STORED`): não tem como ficar inconsistente |
| todas | Quantidades e preços em `float8` (erro de arredondamento binário em dinheiro) | `numeric` (quantidade `14,3`; preço `12,4`) |
| todas | Nenhuma chave estrangeira | Criadas só as que os dados do cliente respeitam: `produtos_filial.idfornecedor` e `pedido_compra.fornecedor_id` para `fornecedor`. **Não** criadas `venda -> produtos_filial` e `entradas -> pedido_compra`, porque os dados as violam (E01, E02, E14); ficam documentadas no DDL para ativar depois da correção |
| mysql | `public.` não existe, `::character varying` é inválido | `01_ddl_mysql.sql`: sem prefixo, `DECIMAL`, `AUTO_INCREMENT`; testado no MySQL 8.0 |

## Erros encontrados no script de importação e como foram corrigidos

Cada efeito abaixo foi **medido**: rodei o script original contra um DDL com só a sintaxe consertada (tipos originais) e contei o que entrou.

| Erro | Efeito | Correção |
| --- | --- | --- |
| `excel_para_data` assume que a data é um número serial do Excel (`int(valor)`), mas o pandas já entrega `Timestamp`. `int(Timestamp)` dá erro e o `except:` genérico devolve `None` | **Todas as datas viram `NULL`**: 29 pedidos e 20 entradas gravados sem data, em silêncio. As 33 vendas são **todas rejeitadas** (`data_emissao NOT NULL`): **venda fica com 0 linhas** | Conversão que aceita `Timestamp`, serial e texto `dd/mm/aaaa`, e **levanta erro** para o que não entende. Sem `except:` genérico |
| `conn.rollback()` dentro do loop, sem savepoint, com o `commit()` só no fim da tabela | Uma linha ruim **desfaz todas as linhas anteriores** da mesma tabela. Teste: 20 fornecedores com a 15ª inválida → **5** no banco (as 14 primeiras sumiram) | `SAVEPOINT` por linha: só a linha ruim é desfeita e listada |
| `print(f"{len(df)} registros inseridos")` | Mostra as linhas **lidas**, não as inseridas. No teste acima imprimiu "20 registros inseridos" com 5 no banco | Contadores reais (lidas / inseridas / duplicadas / rejeitadas) e conferência final com `COUNT(*)` |
| "Importação concluída com sucesso!" sempre | Aparece mesmo com 33 vendas rejeitadas; sem código de saída | Mensagem e `exit code` dependem do resultado; lista as linhas rejeitadas (número da linha na planilha) |
| `idfornecedor` entra como `'F8'` | Não cabe em `int4` (`produtos_filial`); inconsistente com `pedido_compra.fornecedor_id` numérico | Prefixo `F` removido (`F8` → `8`), com validação do padrão |
| `iloc[:, :12]` + renomeação por posição na aba `pedido_compra` | Descarta **em silêncio** as colunas M:W (11 colunas, 9 linhas com dados) e quebraria se uma coluna fosse inserida | Leitura **por nome** de cabeçalho; coluna ausente aborta; coluna fora do layout com dados gera aviso com as linhas (22 a 30) |
| `else 1` para `filial_id`, `else 0` para `ordem_compra`, `str(NaN)` | Valores inventados no lugar de dado ausente (filial 1, ordem 0); `str(NaN)` gravaria o texto `'nan'` | Obrigatório vazio vira erro visível; `ordem_compra = 0` vira `NULL` de forma explícita |
| `ON CONFLICT ... DO NOTHING` sem contar | Chave repetida seria descartada sem aviso | Linha ignorada é contada como "duplicada" no relatório |
| IDs e quantidades via `float(...)` | Gravados como ponto flutuante | `Decimal` e inteiros validados (`38.6` é aceito em quantidade; `1.5` num id é erro) |
| `qtde_pendente` calculada na mão (e `0` quando há `NaN`) | Pode divergir da regra | Coluna gerada no banco; o script não grava |
| Senha `1234` no código, caminho `dados/base_teste.xlsx` relativo ao diretório atual, comentário "MySQL porta 3006" | Senha versionada no Git; falha se rodado de outra pasta; a porta do MySQL é **3306** | Variáveis de ambiente `PG*`; caminho relativo ao arquivo do script (`ARQUIVO_XLSX` opcional) |
| Conexão só fechada no caminho feliz; variável `_` usada como índice | Vazamento de conexão em erro; mensagem de erro com número de linha ilegível | Número da linha reportado é o da planilha |

## Tratamentos aplicados aos dados

- **Datas:** convertidas para `date` (aceita `Timestamp`, serial do Excel e texto `dd/mm/aaaa`). Data inválida rejeita a linha, nunca vira `NULL` calado. Conferido: mínimo e máximo de cada tabela batem com a planilha.
- **Números:** `Decimal` a partir do texto da célula (sem passar por `float`); `item`, `filial_id`, `venda_id`, `pedido_id`, `ordem_compra` validados como inteiros.
- **Textos:** `strip()` em todos; vazio obrigatório gera erro; vazio opcional vira `NULL`.
- **Fornecedor:** `F8` → `8` nas abas `fornecedor` e `produtos_filial`. Depois da carga, a sequência do identity é acertada com `setval(MAX)`, para a trigger gerar o id 21 e não colidir com o 1..20.
- **`ordem_compra = 0` → `NULL`** (11 linhas, pedidos 19 a 29): 0 significa "sem ordem" e não pode casar com nenhuma entrada.
- **`horariomov`:** texto `08:00:00` → `time`.
- **`qtde_pendente`:** calculada pelo banco.
- **Bloco M22:W30 de `pedido_compra`: não importado, e o aviso aparece a cada execução.** As linhas 22 a 28 repetem os pedidos 12 a 18 (mesmos valores, com `ordem_compra` 12 a 18). As linhas 29 e 30 (P19: pedida 40; P20: pedida 86, entregue 78) **divergem** dos pedidos 19 e 20 do bloco principal (pedida 20 e 25, entregue 0) e trazem `ordem_compra` 19 e 20, justamente as ordens que NFE19 e NFE20 citam. Hipótese: restos de colagem, ou os valores corretos de P19 e P20. **Pergunta ao cliente** (E20 em `parte4_validacao.md`).
- **Dados do cliente não foram "consertados":** os erros de conteúdo (venda de produto sem cadastro, entregas antes do pedido, etc.) entram no banco como vieram, para poderem ser mostrados por consulta SQL na Parte 4. Só a representação foi normalizada (itens acima).

## Conferência final

Contagem na planilha (via `openpyxl`/`pandas`) x `SELECT COUNT(*)` no PostgreSQL:

| Tabela | Linhas na planilha | Linhas no banco |
| --- | --- | --- |
| fornecedor | 20 | 20 |
| produtos_filial | 20 | 20 |
| pedido_compra | 29 (+9 linhas no bloco M22:W30, não importadas) | 29 |
| entradas_mercadoria | 20 | 20 |
| venda | 33 | 33 |

Conferência de conteúdo (não só de contagem), planilha x banco, idênticos:

| Verificação | Planilha | Banco |
| --- | --- | --- |
| venda: soma de `qtde_vendida` | 421,720 | 421,720 |
| venda: soma de `qtde * valor_unitario` | 34.768,2152 | 34.768,2152 |
| venda: primeira e última data | 03/01/2025 e 28/03/2025 | 03/01/2025 e 28/03/2025 |
| pedido_compra: soma `qtde_pedida` / `qtde_entregue` | 1071 / 434 | 1071 / 434 |
| pedido_compra: linhas com `ordem_compra = 0` | 11 | 11 (`NULL`) |
| pedido_compra: linhas sem `data_pedido` | 0 | 0 |
| entradas_mercadoria: soma `qtde_recebida` | 1014 | 1014 |

O total de fevereiro/2025 (14 vendas, 173,220 un, R$ 14.093,17) também foi recalculado de forma independente em pandas e confere com o SQL.

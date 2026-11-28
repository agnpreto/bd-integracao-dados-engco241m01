# Parte 1 — Implantacao e importacao dos dados

**Equipe:** SELECT * FROM EU — Rick Iury Oliveira Andrade (2417667)  
**Disciplina:** Banco de Dados — ENGCO241M01  
**Base original:** dados/base_teste.xlsx (preservada sem alteracoes)

## Ferramentas e estrategia

- **PostgreSQL 13+**: DDL sql/01_ddl_postgres.sql.
- **MySQL 8+**: DDL sql/01_ddl_mysql.sql.
- **Python 3.10+ / pandas / openpyxl**: importacao via scripts/importar.py.
- **psycopg2-binary / PyMySQL**: conexao parametrizada pelo ambiente.
- **SQL de conferencia**: sql/04_validacao.sql (consulta V01 e demais verificacoes).

O DDL original foi mantido em sql/01_ddl_enunciado.sql para documentar os erros.
As tabelas foram normalizadas apenas no que diz respeito a nomes, tipos e chaves.
As relacoes entre pedido e entrada e entre venda e cadastro sao conferidas por SQL,
nao bloqueadas por FK, porque a planilha traz registros sem correspondencia
e o objetivo inclui encontrar essas divergencias.

## Estrutura da planilha — conferida sobre o arquivo original

| Aba | Registros estruturados | Colunas reconhecidas |
| --- | ---: | --- |
| fornecedor | 20 | idfornecedor, razao_social |
| produtos_filial | 20 | filial_id, idproduto, descricao, estoque, preco_unitario, preco_compra, preco_venda, idfornecedor |
| pedido_compra | 29 | pedido_id, data_pedido, item, produto_id, descricao_produto, ordem_compra, qtde_pedida, filial_id, data_entrega, qtde_entregue, preco_compra, fornecedor_id |
| entradas_mercadoria | 20 | data_entrada, nro_nfe, item, produto_id, descricao_produto, ordem_compra, qtde_recebida, filial_id, custo_unitario |
| venda | 33 | venda_id, data_emissao, horariomov, produto_id, qtde_vendida, valor_unitario, filial_id, item, unidade_medida |
| **TOTAL** | **122** | 5 abas |

**Dado fora do formato:** a aba pedido_compra inclui **99 celulas preenchidas
sem cabecalho**, distribuidas em 11 colunas extras de 9 linhas.
Sao evidencias, nao registros completos identificados no cabecalho original.
A planilha nao foi reescrita. O importador registra esses valores no arquivo
docs/celulas_sem_cabecalho.csv para posterior conciliacao com o cliente.

## Problemas no DDL original e correcoes

| Tabela | Problema identificado | Correcao aplicada |
| --- | --- | --- |
| entradas_mercadoria | Chave primaria usa ordem_compra, mas a coluna nao existe na declaracao | Adicionar ordem_compra BIGINT NOT NULL |
| produtos_filial | Falta virgula antes de CONSTRAINT | Corrigir pontuacao |
| produtos_filial | decricao, idfonecedor e idproduto com nomes divergentes | Padronizar para descricao, idfornecedor e produto_id |
| produtos_filial | filial_id admite NULL, mas integra chave primaria | Definir NOT NULL |
| fornecedor | idforncedor incorreto; chave primaria referencia idproduto inexistente | Definir idfornecedor VARCHAR(25) como PK |
| pedido_compra | Identificadores e item como FLOAT8 | Usar BIGINT/INTEGER; impedir arredondamento de chaves |
| varias | Quantidades e valores monetarios em FLOAT8 | Usar NUMERIC/DECIMAL com escala definida |
| MySQL | public., ::character varying, FLOAT8/INT8 e sintaxe especifica de PostgreSQL | DDL separado em dialeto MySQL |
| relacionamentos | IDs de fornecedor da planilha sao F1..F20 no cadastro e 1..20 no pedido | Manter FK VARCHAR(25), normalizando 1 para F1 no importador |

**Observacao:** a quantidade de comandos do DDL original que executa
antes da primeira falha depende da ferramenta, do dialeto, do schema e
do banco preexistente. Nao declarar aprovacao nos SGBDs sem executar os testes.

## Problemas no importador original e correcoes

| Problema | Consequencia | Correcao |
| --- | --- | --- |
| Senha 1234 escrita no codigo | Exposicao de credencial e dependencia de ambiente particular | Variavel de ambiente DB_PASSWORD obrigatoria |
| Tratamento exclusivo de data como serial inteiro | Datas ja convertidas pelo pandas viram NULL silenciosamente | Aceitar Timestamp, datetime, date, serial Excel e string valida; falhar em valores invalidos |
| Exceto generico na conversao de data | Oculta a causa e perde datas | Levantar erro com nome da aba e linha |
| df.iloc[:, :12] na aba pedido_compra | Ignora as 99 celulas fora do cabecalho | Colunas por nome + registro CSV de todas as celulas extras |
| int/float aplicados a identificadores e valores | Risco de perda de precisao e IDs indevidos | BIGINT, INTEGER e Decimal |
| Rollback dentro do loop e depois continuar | Um erro pode desfazer dados anteriores; contagem reportada fica enganosa | Transacao atomica, rollback completo e erro identificavel |
| len(df) dito como 'registros inseridos' | Pode nao corresponder ao banco | Contagem SQL comparada a contagem Excel |
| PostgreSQL fixo e porta MySQL citada como 3006 | Nao funciona em MySQL, porta padrao correta 3306 | DB_ENGINE=postgres/mysql, DB_PORT configuravel |
| Ausencia de importacao idempotente e conferencia final | Duplicatas ou registros desatualizados em novas execucoes | Atualizar pela chave primaria e conferir counts |

## Tratamentos aplicados aos dados

1. Preservar a planilha original como prova.
2. Normalizar apenas os nomes divergentes das colunas no destino:
   idproduto vira produto_id, e idfornecedor mantem o mesmo nome.
3. Converter IDs inteiros e datas do Excel sem perder valores validos.
4. Usar Decimal para quantidades e precos; calcular qtde_pendente
   a partir de qtde_pedida - qtde_entregue, inclusive quando o valor e suspeito.
5. Converter referencia numérica 1..20 de fornecedor no pedido em F1..F20.
6. **Nao corrigir automaticamente** pedidos com ordem zero, entradas sem
   pedido, entregas anteriores ao pedido ou vendas sem cadastro.
   Essas excecoes serao investigadas com o cliente na Parte 4.
7. Nao gerar fornecedores ficticios durante a importacao inicial.
   A trigger de cadastro provisorio e um teste separado.

## Conferencia final — executar no banco

| Tabela | Linhas na planilha | Linhas no PostgreSQL | Linhas no MySQL |
| --- | ---: | --- | --- |
| fornecedor | 20 | 20 (CI) | 20 (CI) |
| produtos_filial | 20 | 20 (CI) | 20 (CI) |
| pedido_compra | 29 | 29 (CI) | 29 (CI) |
| entradas_mercadoria | 20 | 20 (CI) | 20 (CI) |
| venda | 33 | 33 (CI) | 33 (CI) |

**Importante:** as contagens acima foram confirmadas pela execucao
em bancos temporarios PostgreSQL 16 e MySQL 8.0 no GitHub Actions.
Para demonstracao presencial, os mesmos testes podem ser repetidos
em instalacoes locais com sql/04_validacao.sql.

Resultado confirmado por consultas executadas no PostgreSQL 16 e MySQL 8.0:
**fevereiro/2025: 14 itens de venda, 173,22 unidades, R$ 14.093,1704
sem arredondar**. Para apresentacao em reais, arredondar para R$ 14.093,17,
mas preservar a precisao dos dados internamente.

## Comandos de execucao sugeridos

1. Criar um banco de testes vazio chamado integracao_dados em cada SGBD.
2. Executar o DDL corrigido do motor correspondente.
3. Instalar: python -m pip install -r scripts/requirements.txt
4. Definir DB_ENGINE, DB_HOST, DB_PORT, DB_NAME, DB_USER e DB_PASSWORD no ambiente.
5. Na raiz: python scripts/importar.py
6. Conferir a saida de contagens e rodar sql/02_consultas.sql e sql/04_validacao.sql.
7. Executar sql/03_transformacoes.sql no PostgreSQL ou
   sql/03_transformacoes_mysql.sql no MySQL; testar a trigger em transacao
   e finalizar com ROLLBACK.
8. Registrar evidencias reais de cada teste antes do Pull Request final.

Nenhuma credencial deve entrar no repositório.

## Evidencia de execucao real (GitHub Actions)

Ambos os bancos passaram nos testes automatizados de 19/11/2026:
https://github.com/Ricklindo223/bd-integracao-dados-engco241m01/actions/runs/44586259937

- PostgreSQL 16: DDL, 122 insercoes, consultas e trigger **aprovados**.
- MySQL 8.0: DDL, 122 insercoes, consultas e trigger **aprovados**.
- Todas as quatro colunas de datas testadas ficaram sem valores NULL.
- A auditoria apontou 99 celulas adicionais sem cabecalho.
- O teste da trigger inseriu fornecedor provisorio e reverteu a transacao.
- Os testes usam senhas descartaveis de bancos temporarios do CI,
  nao credenciais do usuario.

Os bancos do GitHub Actions sao temporarios, nao substituem a conferência
presencial que o professor possa solicitar no computador.

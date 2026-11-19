# Parte 1: Documentação do processo de importação

## Ferramenta utilizada

Foram utilizadas as seguintes ferramentas e tecnologias durante o processo:

- **PostgreSQL 18:** sistema gerenciador de banco de dados utilizado para criar as tabelas e armazenar os dados.
- **pgAdmin 4:** ferramenta utilizada para administrar o PostgreSQL, executar comandos SQL e conferir os registros.
- **Python 3.15:** linguagem utilizada para desenvolver e executar o script de importação.
- **Pandas:** biblioteca utilizada para ler e manipular os dados da planilha Excel.
- **OpenPyXL:** biblioteca utilizada para permitir a leitura do arquivo Excel.
- **Psycopg2:** biblioteca utilizada para conectar o Python ao PostgreSQL e inserir os dados.
- **Visual Studio Code (VS Code):** editor utilizado para visualizar e modificar os arquivos SQL e Python.
- **Git e GitHub:** ferramentas utilizadas para controle de versão e gerenciamento do projeto.

## Estrutura da planilha

| Aba | Coluna | Tipo | Observação |
| --- | --- | --- | --- |
| venda | venda_id | Inteiro | Identificador da venda. |
| venda | data_emissao | Data | Data de emissão da venda. |
| venda | horariomov | Texto | Horário da movimentação. |
| venda | produto_id | Texto | Identificador do produto. |
| venda | qtde_vendida | Decimal | Quantidade vendida. |
| venda | valor_unitario | Decimal | Valor unitário do produto. |
| venda | filial_id | Inteiro | Identificador da filial. |
| venda | item | Inteiro | Número do item. |
| venda | unidade_medida | Texto | Unidade de medida do produto. |
| pedido_compra | pedido_id | Inteiro | Identificador do pedido. |
| pedido_compra | data_pedido | Data | Data do pedido. |
| pedido_compra | item | Inteiro | Número do item. |
| pedido_compra | produto_id | Texto | Identificador do produto. |
| pedido_compra | descricao_produto | Texto | Descrição do produto. |
| pedido_compra | ordem_compra | Inteiro | Identificador da ordem de compra. |
| pedido_compra | qtde_pedida | Inteiro | Quantidade solicitada. |
| pedido_compra | filial_id | Inteiro | Identificador da filial. |
| pedido_compra | data_entrega | Data | Data de entrega prevista. |
| pedido_compra | qtde_entregue | Inteiro | Quantidade entregue. |
| pedido_compra | preco_compra | Decimal | Preço de compra. |
| pedido_compra | fornecedor_id | Inteiro | Identificador do fornecedor. |
| pedido_compra | Unnamed: 12 até Unnamed: 22 | Tipos variados | 11 colunas sem cabeçalho, mas com dados em 9 linhas. Precisam ser investigadas. |
| entradas_mercadoria | data_entrada | Data | Data de entrada da mercadoria. |
| entradas_mercadoria | nro_nfe | Texto | Número da nota fiscal. |
| entradas_mercadoria | item | Inteiro | Número do item. |
| entradas_mercadoria | produto_id | Texto | Identificador do produto. |
| entradas_mercadoria | descricao_produto | Texto | Descrição do produto. |
| entradas_mercadoria | ordem_compra | Inteiro | Identificador da ordem de compra. |
| entradas_mercadoria | qtde_recebida | Inteiro | Quantidade recebida. |
| entradas_mercadoria | filial_id | Inteiro | Identificador da filial. |
| entradas_mercadoria | custo_unitario | Decimal | Custo unitário do produto. |
| produtos_filial | filial_id | Inteiro | Identificador da filial. |
| produtos_filial | idproduto | Texto | Identificador do produto. |
| produtos_filial | descricao | Texto | Descrição do produto. |
| produtos_filial | estoque | Inteiro | Quantidade em estoque. |
| produtos_filial | preco_unitario | Decimal | Preço unitário. |
| produtos_filial | preco_compra | Decimal | Preço de compra. |
| produtos_filial | preco_venda | Decimal | Preço de venda. |
| produtos_filial | idfornecedor | Texto | Identificador alfanumérico do fornecedor. |
| fornecedor | idfornecedor | Texto | Identificador do fornecedor. |
| fornecedor | razao_social | Texto | Razão social do fornecedor. |

## Erros encontrados no DDL e como foram corrigidos

| Tabela | Erro | Correção |
| --- | --- | --- |
| entradas_mercadoria | A coluna ordem_compra foi utilizada na chave primária, mas não foi declarada. | Adicionar a coluna ordem_compra á tabela |
| produtos_filial | Faltava uma vírgula antes da declaração da chave primária. | Corrigir o nome utilizado na chave primária. |
| fornecedor | A chave primária utilizava idproduto, coluna inexistente na tabela. | Utilizar somente o identificador do fornecedor como chave primária. |
| produtos_filial | Nome de coluna escrito incorretamente: decricao. | Corrigir para descricao. |
| produtos_filial | Nome de coluna escrito incorretamente: idfonecedor. | Corrigir para idfornecedor |
| fornecedor | Nome de coluna escrito incorretamente: idforncedor. | Corrigir para idfornecedor |
| produtos_filial | O tipo int4 não comporta identificadores alfanuméricos como F1. | Utilizar um tipo textual compatível com os identificadores da planilha. |

## Erros encontrados no script de importação e como foram corrigidos

| Erro | Efeito | Correção |
| --- | --- | --- |
| A função excel_para_data() não tratava corretamente os valores de data lidos pelo Pandas. | As datas da tabela venda poderiam ser importadas como valores nulos. | Adaptar a função para tratar diferentes formatos de data, incluindo pd.Timestamp, datetime, números seriais e textos. |
| O comando SQL de inserção da tabela produtos_filial utilizava um nome de coluna diferente do definido na estrutura corrigida. | A inserção dos registros poderia falhar. | Ajustar o comando INSERT e a cláusula ON CONFLICT para utilizar o nome correto da coluna. |

## Tratamentos aplicados aos dados

Durante o processo de importação, foram realizados os seguintes tratamentos:

- **Conversão de datas:** a função `excel_para_data()` foi ajustada para reconhecer diferentes formatos de data utilizados pelo Pandas, evitando que datas válidas fossem importadas como valores nulos.
- **Adequação dos comandos SQL:** os nomes das colunas utilizados nos comandos de inserção foram ajustados para corresponder à estrutura das tabelas do PostgreSQL.
- **Identificação dos dados:** os identificadores dos fornecedores foram tratados como valores textuais, permitindo armazenar códigos alfanuméricos, como F1, F2 etc.

Esses ajustes permitiram que os dados fossem importados de acordo com os tipos e as estruturas definidos no banco de dados.

## Conferência final

| Tabela | Linhas na planilha | Linhas no banco |
| --- | --- | --- |
| fornecedor | 20 | 20 |
| produtos_filial | 20 | 20 |
| pedido_compra | 29 | 29 |
| entradas_mercadoria | 20 | 20 |
| venda | 33 | 33 |

# Parte 1 — Implantação e Importação de Dados (`scripts/importa_raniele.py`)

* **Autora:** Raniele Almeida
* **Matrícula:** 2423948
* **GitHub:** `@rhanny118`
* **Escopo:** Correção do script de importação (`scripts/importa_raniele.py`), carga dos dados no banco e documentação técnica da Etapa 1.

---

## 1. Resumo da Importação
Foi realizada a carga dos dados da planilha original `dados/base_teste.xlsx` para o banco de dados utilizando o script corrigido `scripts/importa_raniele.py`. Todas as 5 tabelas foram importadas respeitando a ordem das chaves estrangeiras (*Foreign Keys*):

| Tabela | Registros na Planilha | Registros Inseridos | Registros no Banco | Status |
| :--- | :---: | :---: | :---: | :---: |
| `fornecedor` | 20 | 20 | 20 | OK |
| `produtos_filial` | 20 | 20 | 20 | OK |
| `pedido_compra` | 29 | 29 | 29 | OK |
| `entradas_mercadoria` | 20 | 20 | 20 | OK |
| `venda` | 33 | 33 | 33 | OK |
| **Total** | **122** | **122** | **122** | **OK** |

---

## 2. Erros Encontrados no Script Original e Correções Aplicadas

### 2.1. Conversão de datas falhando silenciosamente (`NULL`)
* **Problema:** O script original tentava converter todas as datas como se fossem números seriais do Excel (`int(v)`). Como o `pandas` já lê células formatadas como data no tipo `Timestamp`, ocorria um erro capturado por um `except` genérico que retornava `None`, fazendo com que todas as datas fossem gravadas como `NULL`.
* **Correção:** Implementação da função estrita `para_data()`, que trata objetos `datetime`/`pd.Timestamp`, datas puras (`date`), números seriais do Excel e textos no padrão brasileiro (`dd/mm/aaaa`).

### 2.2. Rollback global desfazendo inserções válidas
* **Problema:** Ao encontrar erro em uma única linha, o código original executava `conn.rollback()` dentro do laço de repetição, desfazendo todas as linhas válidas já inseridas naquela tabela, além de usar `ON CONFLICT DO NOTHING`, o que mascarava registros duplicados.
* **Correção:** Uso de transações parciais linha a linha com `SAVEPOINT sp` e `ROLLBACK TO SAVEPOINT sp`. Se uma linha apresentar falha, apenas ela é descartada e registrada no relatório de rejeições.

### 2.3. Formatação do código de fornecedor (`"F12"` vs inteiro)
* **Problema:** A planilha traz o identificador do fornecedor com prefixo textual (ex.: `"F12"`), enquanto a chave primária/estrangeira no banco exige um número inteiro (`12`).
* **Correção:** Criação da função `id_fornecedor()` utilizando expressão regular (`r"\s*[Ff]?\s*(\d+)\s*"`) para extrair o valor numérico e preservar o código original na coluna `codigo_origem`.

### 2.4. Ordem de carga e integridade referencial
* **Problema:** A importação fora de ordem gerava violação de chave estrangeira (*FK*) entre tabelas dependentes.
* **Correção:** Definição explícita da lista `ORDEM_CARGA` (`fornecedor` -> `produtos_filial` -> `pedido_compra` -> `entradas_mercadoria` -> `venda`) e limpeza reversa na opção `--limpar`.

### 2.5. Dessincronia da sequência (`IDENTITY` / `SERIAL`) no PostgreSQL
* **Problema:** Como os fornecedores são inseridos com IDs explícitos vindos da planilha, a sequência interna do PostgreSQL permanecia em `1`, causando conflito de chave primária em inserções futuras.
* **Correção:** Adição da função `pos_carga()`, que atualiza a sequência via `setval` para o maior `idfornecedor` existente na tabela.

### 2.6. Exposição de credenciais no código-fonte
* **Problema:** Senhas de banco fixas diretamente no script.
* **Correção:** Leitura de todas as credenciais via variáveis de ambiente (`os.getenv`), mantendo apenas valores genéricos como fallback.

---

## 3. Consultas SQL de Conferência e Validação dos Dados

Abaixo estão as consultas utilizadas para validar a contagem de registros e identificar inconsistências nos dados importados da planilha (detalhadas também no roteiro de validação `sql/04_validacao.sql`):

```sql
-- 1. Conferência da quantidade total de registros por tabela (122 no total)
SELECT 'fornecedor' AS tabela, COUNT(*) AS total FROM fornecedor
UNION ALL
SELECT 'produtos_filial', COUNT(*) FROM produtos_filial
UNION ALL
SELECT 'pedido_compra', COUNT(*) FROM pedido_compra
UNION ALL
SELECT 'entradas_mercadoria', COUNT(*) FROM entradas_mercadoria
UNION ALL
SELECT 'venda', COUNT(*) FROM venda;

-- 2. Verificação de datas nulas após a importação
SELECT COUNT(*) AS vendas_sem_data FROM venda WHERE data_emissao IS NULL;
SELECT COUNT(*) AS pedidos_sem_data FROM pedido_compra WHERE data_pedido IS NULL;

-- 3. Verificação de pedidos sem ordem de compra vinculada (ordem_compra = 0)
SELECT pedido_id, item, produto_id, qtde_pedida, qtde_entregue, qtde_pendente
FROM pedido_compra
WHERE ordem_compra = 0;

-- 4. Verificação de integridade entre entradas de mercadoria e pedidos de compra
SELECT e.nro_nfe, e.ordem_compra, e.produto_id, e.qtde_recebida
FROM entradas_mercadoria e
LEFT JOIN pedido_compra p ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
WHERE p.pedido_id IS NULL;
```

## 4. Conclusão
A importação foi concluída sem divergências entre a quantidade de linhas válidas da planilha `base_teste.xlsx` e os registros armazenados nas 5 tabelas do banco de dados.

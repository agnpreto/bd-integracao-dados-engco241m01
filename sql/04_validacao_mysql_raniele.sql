-- 04_validacao_mysql_raniele.sql : Parte 4 ( MySQL 8)
-- Autora: Raniele Almeida | Matrícula: 2423948 | GitHub: @rhanny118
-- Foco: dados de FEVEREIRO/2025. Banco: PostgreSQL (MySQL 8: trocar TO_CHAR

-- tentando explicar cada consulta: docs/parte4_validacao.md

-- SEÇÃO A - CONFERÊNCIA NUMÉRICA DE FEVEREIRO/2025

-- A1. Resumo das vendas de fevereiro (o cliente confere com o fechamento dele)
-- Esperado: 14 linhas | 14 produtos | 2 filiais | qtde 173,22 | R$ 14.093,17
--           | 07/02/2025 a 28/02/2025
SELECT COUNT(*)                                       AS linhas_venda,
       COUNT(DISTINCT produto_id)                     AS produtos,
       COUNT(DISTINCT filial_id)                      AS filiais,
       SUM(qtde_vendida)                              AS qtde_total,
       ROUND(SUM(qtde_vendida * valor_unitario), 2)   AS valor_total_rs,
       MIN(data_emissao)                              AS primeira_venda,
       MAX(data_emissao)                              AS ultima_venda
FROM venda
WHERE data_emissao >= DATE '2025-02-01' AND data_emissao < DATE '2025-03-01';

-- A2. Vendas de fevereiro por dia.
SELECT data_emissao,
       COUNT(*)                                       AS linhas,
       SUM(qtde_vendida)                              AS qtde,
       ROUND(SUM(qtde_vendida * valor_unitario), 2)   AS valor_rs
FROM venda
WHERE data_emissao >= DATE '2025-02-01' AND data_emissao < DATE '2025-03-01'
GROUP BY data_emissao
ORDER BY data_emissao;

-- A3. Vendas de fevereiro por filial (obs; "filial 3 não aparece em fevereiro; a 2 aparece sem cadastro")
SELECT filial_id,
       COUNT(*)                                       AS linhas,
       ROUND(SUM(qtde_vendida * valor_unitario), 2)   AS valor_rs
FROM venda
WHERE data_emissao >= DATE '2025-02-01' AND data_emissao < DATE '2025-03-01'
GROUP BY filial_id
ORDER BY filial_id;

-- A4. Contagem de linhas por tabela x planilha original
-- Esperado: fornecedor 20 | produtos_filial 20 | pedido_compra 29 | entradas_mercadoria 20 | venda 33
SELECT 'fornecedor' AS tabela, COUNT(*) AS linhas_no_banco, 20 AS linhas_na_planilha FROM fornecedor
UNION ALL SELECT 'produtos_filial',     COUNT(*), 20 FROM produtos_filial
UNION ALL SELECT 'pedido_compra',       COUNT(*), 29 FROM pedido_compra
UNION ALL SELECT 'entradas_mercadoria', COUNT(*), 20 FROM entradas_mercadoria
UNION ALL SELECT 'venda',               COUNT(*), 33 FROM venda;

-- A5. Entradas de mercadoria de fevereiro (quantidade e custo pra não errar)
SELECT COUNT(*)                                       AS notas,
       SUM(qtde_recebida)                             AS qtde_recebida,
       ROUND(SUM(qtde_recebida * custo_unitario), 2)  AS custo_total_rs
FROM entradas_mercadoria
WHERE data_entrada >= DATE '2025-02-01' AND data_entrada < DATE '2025-03-01';

-- A6. Pedidos de compra feitos em fevereiro
SELECT COUNT(*)                                       AS linhas_pedido,
       SUM(qtde_pedida)                               AS qtde_pedida,
       ROUND(SUM(qtde_pedida * preco_compra), 2)      AS valor_pedido_rs
FROM pedido_compra
WHERE data_pedido >= DATE '2025-02-01' AND data_pedido < DATE '2025-03-01';

-- A7. Identificadores de venda repetidos
SELECT venda_id, COUNT(*) AS ocorrencias
FROM venda
GROUP BY venda_id
HAVING COUNT(*) > 1;

-- A8. Lista de vendas de fevereiro com data DD/MM/AAAA, para conferência linha a linha
SELECT v.venda_id,
       TO_CHAR(v.data_emissao, 'DD/MM/YYYY')                 AS data,
       v.filial_id,
       v.produto_id,
       v.qtde_vendida,
       v.valor_unitario,
       ROUND(v.qtde_vendida * v.valor_unitario, 2)           AS total_rs
FROM venda v
WHERE v.data_emissao >= DATE '2025-02-01' AND v.data_emissao < DATE '2025-03-01'
ORDER BY v.data_emissao, v.venda_id;

-- SEÇÃO B - UMA CONSULTA POR ERRO ENCONTRADO NOS DADOS
-- (cada consulta devolve as linhas com problema; "Esperado" = quantidade

-- DADOS-01 [venda] Produto vendido sem cadastro em produtos_filial (P21..P28)
SELECT v.venda_id, v.data_emissao, v.filial_id, v.produto_id, v.qtde_vendida, v.valor_unitario
FROM venda v
WHERE NOT EXISTS (SELECT 1 FROM produtos_filial p WHERE p.produto_id = v.produto_id)
ORDER BY v.venda_id;

-- DADOS-02 [venda] Venda em filial inexistente no cadastro (filiais 2 e 3)
SELECT v.venda_id, v.data_emissao, v.filial_id, v.produto_id
FROM venda v
WHERE NOT EXISTS (SELECT 1 FROM produtos_filial p WHERE p.filial_id = v.filial_id)
ORDER BY v.venda_id;

-- DADOS-03 [venda] Quantidade fracionada com unidade 'UN' (unidade não fraciona)
-- Esperado: 5 linha(s)
SELECT venda_id, produto_id, qtde_vendida, unidade_medida
FROM venda
WHERE unidade_medida = 'UN' AND qtde_vendida <> ROUND(qtde_vendida, 0)
ORDER BY venda_id;

-- DADOS-04 [venda] valor_unitario da venda diferente de preco_venda do cadastro (todas as comparáveis)
SELECT v.venda_id, v.produto_id, v.valor_unitario AS preco_na_venda, p.preco_venda AS preco_no_cadastro
FROM venda v
JOIN produtos_filial p ON p.filial_id = v.filial_id AND p.produto_id = v.produto_id
WHERE v.valor_unitario <> p.preco_venda
ORDER BY v.venda_id;

-- DADOS-05 [venda] Mesmo valor_unitario em produtos diferentes (vendas 21 a 33 parecem cópias de P13..P20)
SELECT valor_unitario, COUNT(DISTINCT produto_id) AS produtos, COUNT(*) AS linhas,
       MIN(produto_id) AS primeiro_produto, MAX(produto_id) AS ultimo_produto
FROM venda
GROUP BY valor_unitario
HAVING COUNT(DISTINCT produto_id) > 1
ORDER BY valor_unitario;

-- DADOS-06 [venda] horariomov idêntico (08:00:00) em 100% das vendas: parece valor padrão, não hora real
SELECT horariomov, COUNT(*) AS linhas
FROM venda
GROUP BY horariomov
HAVING COUNT(*) = (SELECT COUNT(*) FROM venda)
ORDER BY horariomov;

-- DADOS-07 [pedido_compra] ordem_compra = 0 (pedido sem vínculo com entrada)
SELECT pedido_id, produto_id, qtde_pedida, data_pedido, ordem_compra
FROM pedido_compra
WHERE ordem_compra = 0
ORDER BY pedido_id;

-- DADOS-08 [pedido_compra] data_entrega anterior à data_pedido
SELECT pedido_id, produto_id, data_pedido, data_entrega
FROM pedido_compra
WHERE data_entrega < data_pedido
ORDER BY pedido_id;

-- DADOS-09 [pedido_compra] Mesmo produto em dois pedidos (P12..P20 nos pedidos 12-20 e 21-29)
SELECT produto_id, COUNT(*) AS pedidos, SUM(qtde_pedida) AS qtde_total,
       MIN(pedido_id) AS primeiro_pedido, MAX(pedido_id) AS ultimo_pedido
FROM pedido_compra
GROUP BY produto_id
HAVING COUNT(*) > 1
ORDER BY produto_id;

-- DADOS-10 [pedido_compra] fornecedor_id do pedido diferente do fornecedor do cadastro do produto
SELECT pc.pedido_id, pc.produto_id, pc.fornecedor_id AS fornecedor_no_pedido, p.idfornecedor AS fornecedor_no_cadastro
FROM pedido_compra pc
JOIN produtos_filial p ON p.filial_id = pc.filial_id AND p.produto_id = pc.produto_id
WHERE pc.fornecedor_id <> p.idfornecedor
ORDER BY pc.pedido_id;

-- DADOS-11 [pedido x entrada] qtde_entregue do pedido diferente de qtde_recebida da entrada (mesma ordem_compra)
SELECT pc.pedido_id, pc.produto_id, pc.ordem_compra, pc.qtde_entregue, em.qtde_recebida
FROM pedido_compra pc
JOIN entradas_mercadoria em ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
WHERE pc.qtde_entregue <> em.qtde_recebida
ORDER BY pc.pedido_id;

-- DADOS-12 [pedido x entrada] preco_compra do pedido diferente de custo_unitario da entrada
SELECT pc.pedido_id, pc.produto_id, pc.preco_compra, em.custo_unitario
FROM pedido_compra pc
JOIN entradas_mercadoria em ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
WHERE pc.preco_compra <> em.custo_unitario
ORDER BY pc.pedido_id;

-- DADOS-13 [entradas_mercadoria] Entrada cuja ordem_compra não existe em pedido_compra (NFE19, NFE20)
SELECT em.nro_nfe, em.ordem_compra, em.produto_id, em.qtde_recebida, em.data_entrada
FROM entradas_mercadoria em
WHERE NOT EXISTS (SELECT 1 FROM pedido_compra pc
                  WHERE pc.ordem_compra = em.ordem_compra AND pc.produto_id = em.produto_id)
ORDER BY em.nro_nfe;

-- DADOS-14 [entradas_mercadoria] qtde_recebida maior que qtde_pedida (recebeu mais do que pediu)
SELECT em.nro_nfe, em.produto_id, pc.qtde_pedida, em.qtde_recebida
FROM entradas_mercadoria em
JOIN pedido_compra pc ON pc.ordem_compra = em.ordem_compra AND pc.produto_id = em.produto_id
WHERE em.qtde_recebida > pc.qtde_pedida
ORDER BY em.nro_nfe;

-- DADOS-15 [entradas_mercadoria] data_entrada anterior à data_pedido (mercadoria chegou antes de ser pedida)
SELECT em.nro_nfe, em.produto_id, pc.data_pedido, em.data_entrada
FROM entradas_mercadoria em
JOIN pedido_compra pc ON pc.ordem_compra = em.ordem_compra AND pc.produto_id = em.produto_id
WHERE em.data_entrada < pc.data_pedido
ORDER BY em.nro_nfe;

-- DADOS-16 [produtos_filial] preco_venda menor que preco_compra (margem negativa: P1, P8, P15, P18)
SELECT filial_id, produto_id, preco_compra, preco_venda
FROM produtos_filial
WHERE preco_venda < preco_compra
ORDER BY produto_id;

-- DADOS-17 [produtos_filial] preco_unitario diferente de preco_venda em todos os produtos (significado de preco_unitario indefinido)
SELECT filial_id, produto_id, preco_unitario, preco_venda
FROM produtos_filial
WHERE preco_unitario <> preco_venda
ORDER BY produto_id;

-- DADOS-18 [fornecedor] Fornecedor sem nenhum produto vinculado (F14, F15, F16)
SELECT f.idfornecedor, f.codigo_origem, f.razao_social
FROM fornecedor f
WHERE NOT EXISTS (SELECT 1 FROM produtos_filial p WHERE p.idfornecedor = f.idfornecedor)
ORDER BY f.idfornecedor;

-- SEÇÃO C - PAINEL DE VERIFICAÇÕES
-- Cada linha repete a consulta da seção B; 'encontrados' deve ser igual a
-- Quando o cliente corrigir um erro, 'encontrados' cai para 0. (0nde filho chora e o pai não ver)

SELECT 'DADOS-01' AS verificacao, 'venda' AS tabela, 'Produto vendido sem cadastro em produtos_filial (P21..P28)' AS problema,
       (SELECT COUNT(*) FROM (
SELECT v.venda_id, v.data_emissao, v.filial_id, v.produto_id, v.qtde_vendida, v.valor_unitario
FROM venda v
WHERE NOT EXISTS (SELECT 1 FROM produtos_filial p WHERE p.produto_id = v.produto_id)
       ) x) AS encontrados, 13 AS esperado
UNION ALL
SELECT 'DADOS-02' AS verificacao, 'venda' AS tabela, 'Venda em filial inexistente no cadastro (filiais 2 e 3)' AS problema,
       (SELECT COUNT(*) FROM (
SELECT v.venda_id, v.data_emissao, v.filial_id, v.produto_id
FROM venda v
WHERE NOT EXISTS (SELECT 1 FROM produtos_filial p WHERE p.filial_id = v.filial_id)
       ) x) AS encontrados, 4 AS esperado
UNION ALL
SELECT 'DADOS-03' AS verificacao, 'venda' AS tabela, 'Quantidade fracionada com unidade ''UN'' (unidade não fraciona)' AS problema,
       (SELECT COUNT(*) FROM (
SELECT venda_id, produto_id, qtde_vendida, unidade_medida
FROM venda
WHERE unidade_medida = 'UN' AND qtde_vendida <> ROUND(qtde_vendida, 0)
       ) x) AS encontrados, 5 AS esperado
UNION ALL
SELECT 'DADOS-04' AS verificacao, 'venda' AS tabela, 'valor_unitario da venda diferente de preco_venda do cadastro (todas as comparáveis)' AS problema,
       (SELECT COUNT(*) FROM (
SELECT v.venda_id, v.produto_id, v.valor_unitario AS preco_na_venda, p.preco_venda AS preco_no_cadastro
FROM venda v
JOIN produtos_filial p ON p.filial_id = v.filial_id AND p.produto_id = v.produto_id
WHERE v.valor_unitario <> p.preco_venda
       ) x) AS encontrados, 20 AS esperado
UNION ALL
SELECT 'DADOS-05' AS verificacao, 'venda' AS tabela, 'Mesmo valor_unitario em produtos diferentes (vendas 21 a 33 parecem cópias de P13..P20)' AS problema,
       (SELECT COUNT(*) FROM (
SELECT valor_unitario, COUNT(DISTINCT produto_id) AS produtos, COUNT(*) AS linhas,
       MIN(produto_id) AS primeiro_produto, MAX(produto_id) AS ultimo_produto
FROM venda
GROUP BY valor_unitario
HAVING COUNT(DISTINCT produto_id) > 1
       ) x) AS encontrados, 8 AS esperado
UNION ALL
SELECT 'DADOS-06' AS verificacao, 'venda' AS tabela, 'horariomov idêntico (08:00:00) em 100% das vendas: parece valor padrão, não hora real' AS problema,
       (SELECT COUNT(*) FROM (
SELECT horariomov, COUNT(*) AS linhas
FROM venda
GROUP BY horariomov
HAVING COUNT(*) = (SELECT COUNT(*) FROM venda)
       ) x) AS encontrados, 1 AS esperado
UNION ALL
SELECT 'DADOS-07' AS verificacao, 'pedido_compra' AS tabela, 'ordem_compra = 0 (pedido sem vínculo com entrada)' AS problema,
       (SELECT COUNT(*) FROM (
SELECT pedido_id, produto_id, qtde_pedida, data_pedido, ordem_compra
FROM pedido_compra
WHERE ordem_compra = 0
       ) x) AS encontrados, 11 AS esperado
UNION ALL
SELECT 'DADOS-08' AS verificacao, 'pedido_compra' AS tabela, 'data_entrega anterior à data_pedido' AS problema,
       (SELECT COUNT(*) FROM (
SELECT pedido_id, produto_id, data_pedido, data_entrega
FROM pedido_compra
WHERE data_entrega < data_pedido
       ) x) AS encontrados, 20 AS esperado
UNION ALL
SELECT 'DADOS-09' AS verificacao, 'pedido_compra' AS tabela, 'Mesmo produto em dois pedidos (P12..P20 nos pedidos 12-20 e 21-29)' AS problema,
       (SELECT COUNT(*) FROM (
SELECT produto_id, COUNT(*) AS pedidos, SUM(qtde_pedida) AS qtde_total,
       MIN(pedido_id) AS primeiro_pedido, MAX(pedido_id) AS ultimo_pedido
FROM pedido_compra
GROUP BY produto_id
HAVING COUNT(*) > 1
       ) x) AS encontrados, 9 AS esperado
UNION ALL
SELECT 'DADOS-10' AS verificacao, 'pedido_compra' AS tabela, 'fornecedor_id do pedido diferente do fornecedor do cadastro do produto' AS problema,
       (SELECT COUNT(*) FROM (
SELECT pc.pedido_id, pc.produto_id, pc.fornecedor_id AS fornecedor_no_pedido, p.idfornecedor AS fornecedor_no_cadastro
FROM pedido_compra pc
JOIN produtos_filial p ON p.filial_id = pc.filial_id AND p.produto_id = pc.produto_id
WHERE pc.fornecedor_id <> p.idfornecedor
       ) x) AS encontrados, 22 AS esperado
UNION ALL
SELECT 'DADOS-11' AS verificacao, 'pedido x entrada' AS tabela, 'qtde_entregue do pedido diferente de qtde_recebida da entrada (mesma ordem_compra)' AS problema,
       (SELECT COUNT(*) FROM (
SELECT pc.pedido_id, pc.produto_id, pc.ordem_compra, pc.qtde_entregue, em.qtde_recebida
FROM pedido_compra pc
JOIN entradas_mercadoria em ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
WHERE pc.qtde_entregue <> em.qtde_recebida
       ) x) AS encontrados, 18 AS esperado
UNION ALL
SELECT 'DADOS-12' AS verificacao, 'pedido x entrada' AS tabela, 'preco_compra do pedido diferente de custo_unitario da entrada' AS problema,
       (SELECT COUNT(*) FROM (
SELECT pc.pedido_id, pc.produto_id, pc.preco_compra, em.custo_unitario
FROM pedido_compra pc
JOIN entradas_mercadoria em ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
WHERE pc.preco_compra <> em.custo_unitario
       ) x) AS encontrados, 18 AS esperado
UNION ALL
SELECT 'DADOS-13' AS verificacao, 'entradas_mercadoria' AS tabela, 'Entrada cuja ordem_compra não existe em pedido_compra (NFE19, NFE20)' AS problema,
       (SELECT COUNT(*) FROM (
SELECT em.nro_nfe, em.ordem_compra, em.produto_id, em.qtde_recebida, em.data_entrada
FROM entradas_mercadoria em
WHERE NOT EXISTS (SELECT 1 FROM pedido_compra pc
                  WHERE pc.ordem_compra = em.ordem_compra AND pc.produto_id = em.produto_id)
       ) x) AS encontrados, 2 AS esperado
UNION ALL
SELECT 'DADOS-14' AS verificacao, 'entradas_mercadoria' AS tabela, 'qtde_recebida maior que qtde_pedida (recebeu mais do que pediu)' AS problema,
       (SELECT COUNT(*) FROM (
SELECT em.nro_nfe, em.produto_id, pc.qtde_pedida, em.qtde_recebida
FROM entradas_mercadoria em
JOIN pedido_compra pc ON pc.ordem_compra = em.ordem_compra AND pc.produto_id = em.produto_id
WHERE em.qtde_recebida > pc.qtde_pedida
       ) x) AS encontrados, 7 AS esperado
UNION ALL
SELECT 'DADOS-15' AS verificacao, 'entradas_mercadoria' AS tabela, 'data_entrada anterior à data_pedido (mercadoria chegou antes de ser pedida)' AS problema,
       (SELECT COUNT(*) FROM (
SELECT em.nro_nfe, em.produto_id, pc.data_pedido, em.data_entrada
FROM entradas_mercadoria em
JOIN pedido_compra pc ON pc.ordem_compra = em.ordem_compra AND pc.produto_id = em.produto_id
WHERE em.data_entrada < pc.data_pedido
       ) x) AS encontrados, 9 AS esperado
UNION ALL
SELECT 'DADOS-16' AS verificacao, 'produtos_filial' AS tabela, 'preco_venda menor que preco_compra (margem negativa: P1, P8, P15, P18)' AS problema,
       (SELECT COUNT(*) FROM (
SELECT filial_id, produto_id, preco_compra, preco_venda
FROM produtos_filial
WHERE preco_venda < preco_compra
       ) x) AS encontrados, 4 AS esperado
UNION ALL
SELECT 'DADOS-17' AS verificacao, 'produtos_filial' AS tabela, 'preco_unitario diferente de preco_venda em todos os produtos (significado de preco_unitario indefinido)' AS problema,
       (SELECT COUNT(*) FROM (
SELECT filial_id, produto_id, preco_unitario, preco_venda
FROM produtos_filial
WHERE preco_unitario <> preco_venda
       ) x) AS encontrados, 20 AS esperado
UNION ALL
SELECT 'DADOS-18' AS verificacao, 'fornecedor' AS tabela, 'Fornecedor sem nenhum produto vinculado (F14, F15, F16)' AS problema,
       (SELECT COUNT(*) FROM (
SELECT f.idfornecedor, f.codigo_origem, f.razao_social
FROM fornecedor f
WHERE NOT EXISTS (SELECT 1 FROM produtos_filial p WHERE p.idfornecedor = f.idfornecedor)
       ) x) AS encontrados, 3 AS esperado
ORDER BY verificacao;

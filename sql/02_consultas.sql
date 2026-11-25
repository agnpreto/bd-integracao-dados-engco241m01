-- 02_consultas_mysql_raniele.sql : Parte 2 (consultas básicas)
-- Autora: Raniele Almeida| Matrícula:2423948| GitHub: @rhanny118
-- Ajudante: Dalton Cauã | Matricula: 2419749| Github: daltoncaua11-png
USE integracao;
SELECT v.produto_id, 
       COALESCE(p.descricao, '(produto sem cadastro)')        AS descricao,
       SUM(v.qtde_vendida)                                     AS qtde_total,
       ROUND(SUM(v.qtde_vendida * v.valor_unitario), 2)        AS valor_total_rs
FROM venda v
LEFT JOIN (SELECT produto_id, MIN(descricao) AS descricao
           FROM produtos_filial
           GROUP BY produto_id) p ON p.produto_id = v.produto_id
WHERE v.data_emissao >= DATE '2025-02-01'
  AND v.data_emissao <  DATE '2025-03-01'
GROUP BY v.produto_id, p.descricao
ORDER BY valor_total_rs DESC;
-- resultado esperado: 14 produtos; soma da qtde = 173,22 ; soma do valor = 14.093,17

-- obs; conferência do total geral de fevereiro deve bater com a soma acima
SELECT COUNT(*)                                          AS linhas,
       SUM(qtde_vendida)                                 AS qtde_total,
       ROUND(SUM(qtde_vendida * valor_unitario), 2)      AS valor_total_rs
FROM venda
WHERE data_emissao >= DATE '2025-02-01' AND data_emissao < DATE '2025-03-01';
-- Esperado: 14 | 173,22 | 14093,17

-- 2.2  Produtos requisitados (pedido_compra) e NÃO recebidos
-- obs; "Não recebido" = linha de pedido para a qual NÃO existe entrada com a mesma ordem_compra e o mesmo produto.
-- obs; pedidos 21 a 29 repetem produtos já pedidos nos pedidos 12 a 20;
-- obs; os pedidos 19 e 20 (P19, P20) TÊM entrada (NFE19/NFE20, ordens 19 e 20),
-- obs; o pedido foi gravado com ordem_compra 0 e o elo se perdeu. Por isso

SELECT pc.pedido_id,
       pc.item,
       pc.produto_id,
       pc.descricao_produto,
       pc.ordem_compra,
       pc.qtde_pedida,
       pc.data_pedido,
       CASE
         WHEN pc.ordem_compra = 0
              AND EXISTS (SELECT 1 FROM entradas_mercadoria e2
                          WHERE e2.produto_id = pc.produto_id)
           THEN 'ordem_compra = 0, mas o produto tem entrada (elo perdido?)'
         WHEN pc.ordem_compra = 0 THEN 'ordem_compra = 0'
         ELSE 'ordem_compra sem entrada'
       END AS motivo
FROM pedido_compra pc
WHERE NOT EXISTS (SELECT 1
                  FROM entradas_mercadoria em
                  WHERE em.ordem_compra = pc.ordem_compra
                    AND em.produto_id   = pc.produto_id)
ORDER BY pc.pedido_id;

-- obs; Visão por PRODUTO (um produto só é "não recebido" se nenhuma de suas entradas existir).
SELECT pc.produto_id, MIN(pc.descricao_produto) AS descricao,
       SUM(pc.qtde_pedida) AS qtde_requisitada
FROM pedido_compra pc
WHERE NOT EXISTS (SELECT 1 FROM entradas_mercadoria em
                  WHERE em.produto_id = pc.produto_id)
GROUP BY pc.produto_id
ORDER BY pc.produto_id;


--  obs; Recebimento PARCIAL 
SELECT pc.pedido_id, pc.produto_id, pc.ordem_compra,
       pc.qtde_pedida, em.qtde_recebida,
       pc.qtde_pedida - em.qtde_recebida AS faltou_receber
FROM pedido_compra pc
JOIN entradas_mercadoria em
  ON em.ordem_compra = pc.ordem_compra AND em.produto_id = pc.produto_id
WHERE em.qtde_recebida < pc.qtde_pedida
ORDER BY pc.pedido_id;


-- 02_consultas
-- NOme:
-- Consulta 1: a quantidade vendida e valor total por produto em fevereiro de 2025.
SELECT
    produto_id AS produto,
    SUM(qtde_vendida) AS quantidade_vendida,
    ROUND(SUM(qtde_vendida * valor_unitario), 2) AS total_em_reais
FROM venda
WHERE data_emissao >= DATE '2025-02-01'
  AND data_emissao < DATE '2025-03-01'
GROUP BY produto_id
ORDER BY produto_id;

-- Consulta 2: itens de pedido sem recebimento registrado na base.
-- A ligação considera a ordem de compra, o produto e a filial.
-- Quando a ordem está zerada ou ausente, o recebimento exige conferência.
SELECT
    p.pedido_id,
    p.ordem_compra,
    p.filial_id,
    p.produto_id,
    p.descricao_produto,
    p.qtde_pedida,
    CASE
        WHEN COALESCE(p.ordem_compra, 0) = 0
            THEN 'Conferir: pedido sem número de ordem válido'
        ELSE 'Sem recebimento registrado'
    END AS situacao
FROM pedido_compra AS p
WHERE NOT EXISTS (
    SELECT 1
    FROM entradas_mercadoria AS e
    WHERE p.ordem_compra > 0
      AND e.ordem_compra = p.ordem_compra
      AND e.produto_id = p.produto_id
      AND e.filial_id = p.filial_id
      AND e.qtde_recebida > 0
)
ORDER BY p.pedido_id, p.item;

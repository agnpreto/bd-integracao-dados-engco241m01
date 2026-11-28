-- 02_consultas
-- Nome: yana sayuri ribeiro taketomi

USE integracao_dados;

-- 1. Consumo por produto no mês de fevereiro/2025
SELECT 
    v.produto_id,
    p.descricao AS descricao_produto,
    SUM(v.qtde_vendida) AS total_qtde_consumida,
    SUM(v.qtde_vendida * v.valor_unitario) AS valor_total_consumido
FROM venda v
LEFT JOIN produtos_filial p ON v.produto_id = p.idproduto
WHERE v.data_emissao BETWEEN '2025-02-01' AND '2025-02-28'
GROUP BY v.produto_id, p.descricao
ORDER BY total_qtde_consumida DESC;

-- 2. Produtos com requisição pendente (qtde entregue menor que pedida)
SELECT 
    pedido_id,
    ordem_compra,
    produto_id,
    descricao_produto,
    qtde_pedida,
    qtde_entregue,
    (qtde_pedida - qtde_entregue) AS saldo_pendente
FROM pedido_compra
WHERE qtde_entregue < qtde_pedida
ORDER BY pedido_id;

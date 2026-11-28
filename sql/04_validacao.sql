-- 04_validacao
-- Nome: yana sayuri ribeiro taketomi

USE integracao_dados;

-- 1. Pedidos com data de entrega anterior à data do pedido
SELECT pedido_id, produto_id, data_pedido, data_entrega
FROM pedido_compra
WHERE data_entrega < data_pedido;

-- 2. Divergência entre quantidade entregue no pedido e recebida na NFE
SELECT 
    p.ordem_compra,
    p.produto_id,
    p.qtde_pedida,
    p.qtde_entregue AS entregue_no_pedido,
    COALESCE(SUM(e.qtde_recebida), 0) AS recebido_na_nfe
FROM pedido_compra p
LEFT JOIN entradas_mercadoria e 
    ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
WHERE p.ordem_compra > 0
GROUP BY p.ordem_compra, p.produto_id, p.qtde_pedida, p.qtde_entregue
HAVING p.qtde_entregue <> COALESCE(SUM(e.qtde_recebida), 0);

-- 3. Produtos cadastrados com preço de compra maior que o preço de venda (prejuízo)
SELECT idproduto, descricao, preco_compra, preco_venda
FROM produtos_filial
WHERE preco_compra > preco_venda;

-- 4. Pedidos suspeitos/corrompidos (ordem de compra zerada)
SELECT pedido_id, produto_id, qtde_pedida, ordem_compra
FROM pedido_compra
WHERE ordem_compra = 0;

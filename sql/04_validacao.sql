-- 04_validacao
-- Nome:Beatriz Souza Da Silva
-- 1. Conferir a quantidade de registros em cada tabela
SELECT 'fornecedor' AS tabela, COUNT(*) AS quantidade
FROM fornecedor
UNION ALL
SELECT 'produtos_filial', COUNT(*)
FROM produtos_filial
UNION ALL
SELECT 'pedido_compra', COUNT(*)
FROM pedido_compra
UNION ALL
SELECT 'entradas_mercadoria', COUNT(*)
FROM entradas_mercadoria
UNION ALL
SELECT 'venda', COUNT(*)
FROM venda;


-- 2. Conferir as vendas de fevereiro de 2025
SELECT
    COUNT(*) AS quantidade_vendas,
    SUM(qtde_vendida) AS quantidade_produtos_vendidos,
    SUM(qtde_vendida * valor_unitario) AS valor_total_vendido
FROM venda
WHERE data_emissao >= '2025-02-01'
  AND data_emissao < '2025-03-01';


-- 3. Verificar vendas sem data, quantidade ou produto
SELECT *
FROM venda
WHERE data_emissao IS NULL
   OR qtde_vendida IS NULL
   OR produto_id IS NULL;


-- 4. Verificar valores negativos nas vendas
SELECT *
FROM venda
WHERE qtde_vendida < 0
   OR valor_unitario < 0;


-- 5. Verificar produtos de vendas que não existem no cadastro
SELECT v.*
FROM venda v
LEFT JOIN produtos_filial p
    ON v.filial_id = p.filial_id
   AND v.produto_id = p.idproduto
WHERE p.idproduto IS NULL;


-- 6. Verificar quantidades negativas nos pedidos de compra
SELECT *
FROM pedido_compra
WHERE qtde_pedida < 0
   OR qtde_entregue < 0
   OR qtde_pendente < 0;


-- 7. Verificar pedidos com quantidade entregue
-- maior que a quantidade solicitada
SELECT *
FROM pedido_compra
WHERE qtde_entregue > qtde_pedida;

-- 8. Verificar pedidos com informações ausentes
SELECT *
FROM pedido_compra
WHERE data_pedido IS NULL
   OR qtde_pedida IS NULL
   OR filial_id IS NULL;

-- 9. Contar informações ausentes nos pedidos de compra
SELECT
    COUNT(*) FILTER (WHERE data_pedido IS NULL) AS sem_data_pedido,
    COUNT(*) FILTER (WHERE qtde_pedida IS NULL) AS sem_quantidade_pedida,
    COUNT(*) FILTER (WHERE filial_id IS NULL) AS sem_filial
FROM pedido_compra;

-- 10. Contar pedidos sem data do pedido ou da entrega
SELECT
    COUNT(*) FILTER (WHERE data_pedido IS NULL) AS sem_data_pedido,
    COUNT(*) FILTER (WHERE data_entrega IS NULL) AS sem_data_entrega
FROM pedido_compra;

-- 11. Verificar entradas com informações ausentes
SELECT *
FROM entradas_mercadoria
WHERE data_entrada IS NULL
   OR qtde_recebida IS NULL
   OR filial_id IS NULL;

-- 12. Verificar quantidades e custos negativos
SELECT *
FROM entradas_mercadoria
WHERE qtde_recebida < 0
   OR custo_unitario < 0;

-- 13. Identificar entradas sem pedido de compra correspondente
SELECT e.*
FROM entradas_mercadoria e
LEFT JOIN pedido_compra p
    ON e.ordem_compra = p.pedido_id
   AND e.produto_id = p.produto_id
   AND e.item = p.item
WHERE p.pedido_id IS NULL;

-- 14. Contar campos ausentes nas entradas
SELECT
    COUNT(*) FILTER (WHERE data_entrada IS NULL) AS sem_data_entrada,
    COUNT(*) FILTER (WHERE qtde_recebida IS NULL) AS sem_quantidade_recebida,
    COUNT(*) FILTER (WHERE filial_id IS NULL) AS sem_filial
FROM entradas_mercadoria;

-- 15. Detalhar entradas sem pedido correspondente
SELECT
    e.ordem_compra,
    e.item,
    e.produto_id,
    e.nro_nfe,
    e.qtde_recebida
FROM entradas_mercadoria e
LEFT JOIN pedido_compra p
    ON e.ordem_compra = p.pedido_id
   AND e.produto_id = p.produto_id
   AND e.item = p.item
WHERE p.pedido_id IS NULL;

-- 16. Comparar quantidades entregues e recebidas
SELECT
    p.pedido_id,
    p.produto_id,
    p.item,
    p.qtde_entregue,
    e.qtde_recebida
FROM pedido_compra p
INNER JOIN entradas_mercadoria e
    ON p.pedido_id = e.ordem_compra
   AND p.produto_id = e.produto_id
   AND p.item = e.item;

-- 17. Identificar divergências entre quantidades
SELECT
    p.pedido_id,
    p.produto_id,
    p.qtde_entregue,
    e.qtde_recebida
FROM pedido_compra p
INNER JOIN entradas_mercadoria e
    ON p.pedido_id = e.ordem_compra
   AND p.produto_id = e.produto_id
   AND p.item = e.item
WHERE p.qtde_entregue IS DISTINCT FROM e.qtde_recebida;

-- 18. Classificar divergências entre pedidos e entradas
SELECT
    p.pedido_id,
    p.produto_id,
    p.qtde_entregue,
    e.qtde_recebida,
    CASE
        WHEN e.ordem_compra IS NULL
            THEN 'Sem entrada correspondente'
        WHEN p.qtde_entregue IS DISTINCT FROM e.qtde_recebida
            THEN 'Quantidade divergente'
        ELSE 'Quantidade correspondente'
    END AS situacao
FROM pedido_compra p
LEFT JOIN entradas_mercadoria e
    ON p.pedido_id = e.ordem_compra
   AND p.produto_id = e.produto_id
   AND p.item = e.item
WHERE e.ordem_compra IS NULL
   OR p.qtde_entregue IS DISTINCT FROM e.qtde_recebida;

-- 19. Verificar pedidos de compra duplicados
SELECT
    pedido_id,
    produto_id,
    item,
    COUNT(*) AS quantidade
FROM pedido_compra
GROUP BY pedido_id, produto_id, item
HAVING COUNT(*) > 1;

-- 20. Verificar entradas de mercadoria duplicadas
SELECT
    ordem_compra,
    item,
    produto_id,
    nro_nfe,
    COUNT(*) AS quantidade
FROM entradas_mercadoria
GROUP BY ordem_compra, item, produto_id, nro_nfe
HAVING COUNT(*) > 1;

-- 21. Verificar vendas duplicadas
SELECT
    filial_id,
    venda_id,
    data_emissao,
    produto_id,
    item,
    horariomov,
    COUNT(*) AS quantidade
FROM venda
GROUP BY
    filial_id,
    venda_id,
    data_emissao,
    produto_id,
    item,
    horariomov
HAVING COUNT(*) > 1;

-- 22. Verificar produtos sem identificação de fornecedor
SELECT *
FROM produtos_filial
WHERE idfornecedor IS NULL;

-- 23. Verificar produtos com fornecedor inexistente
SELECT p.*
FROM produtos_filial p
LEFT JOIN fornecedor f
    ON p.idfornecedor = f.idfornecedor
WHERE f.idfornecedor IS NULL;

-- 24. Contar produtos com fornecedores não cadastrados
SELECT COUNT(*) AS produtos_sem_fornecedor_valido
FROM produtos_filial p
LEFT JOIN fornecedor f
    ON p.idfornecedor = f.idfornecedor
WHERE f.idfornecedor IS NULL;

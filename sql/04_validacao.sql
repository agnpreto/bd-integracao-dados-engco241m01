-- 04_validacao
-- V1. Fechamento de fevereiro de 2025 por filial e total da rede.
SELECT
    CASE WHEN GROUPING(filial_id) = 1 THEN 'Total da rede'
         ELSE filial_id::text
    END AS filial,
    COUNT(*) AS linhas_de_venda,
    SUM(qtde_vendida) AS unidades,
    ROUND(SUM(qtde_vendida * valor_unitario), 2) AS total_reais
FROM venda
WHERE data_emissao >= DATE '2025-02-01'
  AND data_emissao < DATE '2025-03-01'
GROUP BY GROUPING SETS ((filial_id), ())
ORDER BY GROUPING(filial_id), filial_id;

-- V2. Vendas de produtos sem cadastro na respectiva filial.
SELECT v.venda_id, v.data_emissao, v.filial_id, v.produto_id
FROM venda AS v
WHERE NOT EXISTS (
    SELECT 1
    FROM produtos_filial AS p
    WHERE p.filial_id = v.filial_id
      AND p.produto_id = v.produto_id
)
ORDER BY v.venda_id;

-- V3. Quantidades fracionárias em vendas cuja unidade está marcada como UN.
SELECT venda_id, produto_id, unidade_medida, qtde_vendida
FROM venda
WHERE unidade_medida = 'UN'
  AND qtde_vendida <> TRUNC(qtde_vendida)
ORDER BY venda_id;

-- V4. Pedidos com data de entrega anterior à data do pedido.
SELECT pedido_id, produto_id, data_pedido, data_entrega
FROM pedido_compra
WHERE data_entrega < data_pedido
ORDER BY pedido_id;

-- V5. Pedidos sem número de ordem válido para localizar o recebimento.
SELECT pedido_id, produto_id, ordem_compra, qtde_pedida
FROM pedido_compra
WHERE ordem_compra IS NULL OR ordem_compra = 0
ORDER BY pedido_id;

-- V6. Notas de entrada sem pedido correspondente na mesma filial.
SELECT e.nro_nfe, e.ordem_compra, e.produto_id, e.filial_id
FROM entradas_mercadoria AS e
WHERE NOT EXISTS (
    SELECT 1
    FROM pedido_compra AS p
    WHERE p.ordem_compra = e.ordem_compra
      AND p.produto_id = e.produto_id
      AND p.filial_id = e.filial_id
)
ORDER BY e.ordem_compra;

-- V7. Divergências entre o pedido e as notas de entrada.
-- As notas são somadas antes da comparação para considerar entregas parciais.
WITH notas AS (
    SELECT ordem_compra, filial_id, produto_id,
           SUM(qtde_recebida) AS recebido_nas_notas,
           MIN(data_entrada) AS primeira_entrada
    FROM entradas_mercadoria
    GROUP BY ordem_compra, filial_id, produto_id
)
SELECT p.pedido_id, p.produto_id, p.qtde_pedida, p.qtde_entregue,
       n.recebido_nas_notas, p.data_pedido, n.primeira_entrada
FROM pedido_compra AS p
JOIN notas AS n USING (ordem_compra, filial_id, produto_id)
WHERE p.qtde_entregue <> n.recebido_nas_notas
   OR n.recebido_nas_notas > p.qtde_pedida
   OR n.primeira_entrada < p.data_pedido
ORDER BY p.pedido_id;

-- V8. Valores encontrados em colunas sem cabeçalho na planilha original.
SELECT linha_excel, pedido_id, valores
FROM pedido_colunas_extras
ORDER BY linha_excel;

-- V9. Conferência do filtro "mais de 10 vezes" em fevereiro.
SELECT produto_id, COUNT(DISTINCT pedido_id) AS numero_de_pedidos
FROM pedido_compra
WHERE data_pedido >= DATE '2025-02-01'
  AND data_pedido < DATE '2025-03-01'
GROUP BY produto_id
ORDER BY numero_de_pedidos DESC, produto_id;

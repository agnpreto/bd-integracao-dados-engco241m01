-- 05_relatorio_estoque.sql
-- Relatorio de estoque e valor total por filial

SELECT
    filial_id,
    COUNT(DISTINCT idproduto) AS total_produtos,
    SUM(estoque) AS quantidade_total_estoque,
    ROUND(SUM(estoque * preco_venda)::numeric, 2) AS valor_total_estoque
FROM public.produtos_filial
GROUP BY filial_id
ORDER BY filial_id;

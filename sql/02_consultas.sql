-- 02_consultas.sql  (PostgreSQL)

-- ---------------------------------------------------------------------------
-- C1) Total vendido por produto em fevereiro/2025 (quantidade e valor em R$)
--     Valor = quantidade * valor unitario de cada linha de venda.
--     Linhas com qtde_vendida NULL nao entram na soma (ver V02 em 04_validacao.sql).
-- ---------------------------------------------------------------------------
SELECT v.produto_id,
       SUM(v.qtde_vendida)                    AS qtde_total,
       SUM(v.qtde_vendida * v.valor_unitario) AS valor_total_rs
FROM   public.venda v
WHERE  v.data_emissao >= DATE '2025-02-01'
  AND  v.data_emissao <  DATE '2025-03-01'
GROUP  BY v.produto_id
ORDER  BY valor_total_rs DESC;

-- ---------------------------------------------------------------------------
-- C2) Produtos requisitados e NAO recebidos
--     A entrada se liga ao pedido por ordem_compra (+ produto_id).
--     "Nao recebido" = nenhuma entrada de mercadoria para aquela ordem e produto.
--     ATENCAO: pedidos com ordem_compra = 0 nunca casam com entrada; nos dados, os
--     pedidos 19 e 20 aparecem aqui embora existam as entradas NFE19/NFE20 (ordens 19 e 20).
--     Ver achados P07 e E01 em 04_validacao.sql.
-- ---------------------------------------------------------------------------
SELECT p.pedido_id, p.ordem_compra, p.item, p.produto_id,
       p.descricao_produto, p.qtde_pedida, p.data_pedido
FROM   public.pedido_compra p
WHERE  NOT EXISTS (
         SELECT 1
         FROM   public.entradas_mercadoria e
         WHERE  e.ordem_compra = p.ordem_compra
           AND  e.produto_id   = p.produto_id)
ORDER  BY p.data_pedido, p.pedido_id, p.item;

-- C2b) Mesma ideia, resumida por produto (lista de produtos nunca recebidos)
SELECT p.produto_id,
       MAX(p.descricao_produto) AS descricao_produto,
       SUM(p.qtde_pedida)       AS qtde_requisitada
FROM   public.pedido_compra p
WHERE  NOT EXISTS (
         SELECT 1
         FROM   public.entradas_mercadoria e
         WHERE  e.ordem_compra = p.ordem_compra
           AND  e.produto_id   = p.produto_id)
GROUP  BY p.produto_id
ORDER  BY p.produto_id;

-- C2c) Variante: recebidos PARCIALMENTE (recebido < pedido), util para a validacao
SELECT p.pedido_id, p.ordem_compra, p.produto_id, p.qtde_pedida,
       COALESCE(SUM(e.qtde_recebida), 0) AS qtde_recebida
FROM   public.pedido_compra p
LEFT   JOIN public.entradas_mercadoria e
       ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
GROUP  BY p.pedido_id, p.produto_id, p.item, p.ordem_compra, p.qtde_pedida
HAVING COALESCE(SUM(e.qtde_recebida), 0) < p.qtde_pedida;

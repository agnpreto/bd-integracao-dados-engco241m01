-- 02_consultas
-- Nome:Pedro Almeida

SELECT v.produto_id,
       COALESCE(p.descricao, '(produto sem cadastro)')          AS descricao,
       SUM(v.qtde_vendida)                                       AS qtde_total,
       ROUND(SUM(v.qtde_vendida * v.valor_unitario), 2)          AS valor_total_rs
FROM   public.venda v
LEFT JOIN (SELECT produto_id, MIN(descricao) AS descricao
           FROM   public.produtos_filial
           GROUP  BY produto_id) p ON p.produto_id = v.produto_id
WHERE  v.data_emissao >= DATE '2025-02-01'
  AND  v.data_emissao <  DATE '2025-03-01'
GROUP  BY v.produto_id, p.descricao
ORDER  BY valor_total_rs DESC;

-- Totalizador para conferir com o cliente
SELECT COUNT(*)                                          AS linhas_de_venda,
       SUM(qtde_vendida)                                 AS qtde_total,
       ROUND(SUM(qtde_vendida * valor_unitario), 2)      AS valor_total_rs
FROM   public.venda
WHERE  data_emissao >= DATE '2025-02-01' AND data_emissao < DATE '2025-03-01';


--nenhuma entrada de mercadoria vinculada ao pedido.
SELECT pc.pedido_id,
       pc.produto_id,
       pc.descricao_produto,
       pc.data_pedido,
       pc.qtde_pedida,
       pc.ordem_compra,
       CASE WHEN pc.ordem_compra IS NULL THEN 'sem ordem de compra'
            ELSE 'ordem emitida, sem NF de entrada' END       AS situacao
FROM   public.pedido_compra pc
WHERE  NOT EXISTS (SELECT 1
                   FROM   public.entradas_mercadoria em
                   WHERE  em.ordem_compra = pc.ordem_compra
                     AND  em.produto_id   = pc.produto_id
                     AND  em.item         = pc.item
                     AND  em.filial_id IS NOT DISTINCT FROM pc.filial_id)
ORDER  BY pc.produto_id, pc.pedido_id;

--recebimento PARCIAL

SELECT pc.pedido_id,
       pc.produto_id,
       pc.descricao_produto,
       pc.data_pedido,
       pc.qtde_pedida,
       COALESCE(r.qtde_recebida, 0)                           AS qtde_recebida,
       pc.qtde_pedida - COALESCE(r.qtde_recebida, 0)          AS saldo_pendente,
       CASE WHEN r.qtde_recebida IS NULL THEN 'NÃO RECEBIDO'
            ELSE 'RECEBIDO PARCIAL' END                       AS situacao
FROM   public.pedido_compra pc
LEFT JOIN (SELECT ordem_compra, produto_id, item, filial_id, SUM(qtde_recebida) AS qtde_recebida
           FROM   public.entradas_mercadoria
           GROUP  BY ordem_compra, produto_id, item, filial_id) r
       ON  r.ordem_compra = pc.ordem_compra
       AND r.produto_id   = pc.produto_id
       AND r.item         = pc.item
       AND r.filial_id IS NOT DISTINCT FROM pc.filial_id
WHERE  pc.qtde_pedida - COALESCE(r.qtde_recebida, 0) > 0
ORDER  BY situacao, pc.produto_id, pc.pedido_id;


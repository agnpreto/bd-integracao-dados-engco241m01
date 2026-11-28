-- Parte 2 - consultas SQL (compativeis com PostgreSQL e MySQL 8)
-- Equipe: SELECT * FROM EU | Rick Iury Oliveira Andrade - 2417667
-- Periodo fechado-aberto evita ambiguidades entre DATE e TIMESTAMP.

-- 2.1 Quantidade e receita por produto vendido durante fevereiro/2025.
-- LEFT JOIN preserva vendas de produtos sem cadastro.
-- O total nao e arredondado dentro da consulta, para permitir conferencia.
SELECT
    v.produto_id,
    COALESCE(MAX(p.descricao), 'SEM CADASTRO NA FILIAL') AS descricao,
    SUM(v.qtde_vendida) AS quantidade_vendida,
    SUM(v.qtde_vendida * v.valor_unitario) AS valor_total_bruto
FROM venda v
LEFT JOIN produtos_filial p
    ON p.filial_id = v.filial_id AND p.produto_id = v.produto_id
WHERE v.data_emissao >= '2025-02-01'
  AND v.data_emissao < '2025-03-01'
GROUP BY v.produto_id
ORDER BY v.produto_id;

-- 2.2 Total geral para conferencia contra a planilha.
SELECT COUNT(*) AS itens_venda,
       SUM(qtde_vendida) AS quantidade_total,
       SUM(qtde_vendida * valor_unitario) AS valor_total_sem_arredondar
FROM venda
WHERE data_emissao >= '2025-02-01'
  AND data_emissao < '2025-03-01';

-- 2.3 Produtos requisitados SEM recebimento comprovado em entradas_mercadoria.
-- Nao usar apenas pedido_compra.qtde_entregue: e um campo informado,
-- que pode divergir dos lancamentos efetivos de mercadorias.
-- ordem_compra = 0 nao identifica uma compra e nao deve gerar vinculacao falsa.
SELECT
    pc.pedido_id, pc.produto_id, pc.descricao_produto, pc.ordem_compra,
    pc.data_pedido, pc.qtde_pedida, pc.qtde_entregue AS entregue_informada,
    COALESCE(rec.total_recebido, 0) AS recebida_em_notas,
    CASE WHEN pc.ordem_compra = 0 THEN 'SEM ORDEM DE COMPRA VALIDA'
         ELSE 'SEM RECEBIMENTO REGISTRADO' END AS situacao
FROM pedido_compra pc
LEFT JOIN (
    SELECT ordem_compra, produto_id, item,
           SUM(COALESCE(qtde_recebida, 0)) AS total_recebido
    FROM entradas_mercadoria
    GROUP BY ordem_compra, produto_id, item
) rec ON pc.ordem_compra <> 0
     AND rec.ordem_compra = pc.ordem_compra
     AND rec.produto_id = pc.produto_id
     AND rec.item = pc.item
WHERE COALESCE(rec.total_recebido, 0) = 0
ORDER BY pc.pedido_id, pc.item;

-- 2.4 Situacao completa (inclui recebimento parcial e recebimento maior que o pedido).
SELECT pc.pedido_id, pc.produto_id, pc.qtde_pedida,
       pc.qtde_entregue AS qtde_declarada_no_pedido,
       COALESCE(rec.total_recebido, 0) AS qtde_com_nfe,
       pc.qtde_pedida - COALESCE(rec.total_recebido, 0) AS saldo_por_nfe
FROM pedido_compra pc
LEFT JOIN (
    SELECT ordem_compra, produto_id, item, SUM(qtde_recebida) total_recebido
    FROM entradas_mercadoria GROUP BY ordem_compra, produto_id, item
) rec ON pc.ordem_compra <> 0
     AND rec.ordem_compra = pc.ordem_compra
     AND rec.produto_id = pc.produto_id
     AND rec.item = pc.item
ORDER BY pc.pedido_id;

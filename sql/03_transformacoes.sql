-- 03_transformacoes_mysql_raniele.sql : Parte 3 (transformações + trigger)
-- Autora: Raniele Almeida| matrícula:2423948| GitHub: @rhanny118
-- obs; pedido_compra descricao_produto vem na própria tabela
USE integracao;
SELECT pedido_id,
       CONCAT_WS(' - ', produto_id, NULLIF(TRIM(descricao_produto), '')) AS produto
FROM pedido_compra
ORDER BY pedido_id;

-- obs; P21..P28 não têm cadastro e saem só com o código.
SELECT v.venda_id,
       CONCAT_WS(' - ', v.produto_id, NULLIF(TRIM(p.descricao), '')) AS produto
FROM venda v
LEFT JOIN (SELECT produto_id, MIN(descricao) AS descricao
           FROM produtos_filial GROUP BY produto_id) p
       ON p.produto_id = v.produto_id
ORDER BY v.venda_id;

-- obs; produtos_filial (a coluna se chama descricao)
SELECT filial_id,
       CONCAT_WS(' - ', produto_id, NULLIF(TRIM(descricao), '')) AS produto
FROM produtos_filial
ORDER BY filial_id, produto_id;

-- Datas no formato %d/%m/%Y
SELECT pedido_id,
       DATE_FORMAT(data_pedido,  '%d/%m/%Y') AS data_pedido,
       date_FORMAT(data_entrega, '%d/%m/%Y') AS data_entrega
FROM pedido_compra
ORDER BY pedido_id;

SELECT venda_id, DATE_FORMAT(data_emissao, '%d/%m/%Y') AS data_emissao
FROM venda
ORDER BY venda_id;

SELECT nro_nfe, DATE_FORMAT(data_entrada, '%d/%m/%Y') AS data_entrada
FROM entradas_mercadoria
ORDER BY nro_nfe;

-- obs; só produtos requisitados "mais de 10 vezes" no período
-- obs; com estes dados todos os 20 produtos passam (menor total: P3 = 12).
WITH periodo AS (
    SELECT DATE '2025-01-01' AS ini, DATE '2025-03-31' AS fim
),
elegiveis AS (
    SELECT pc.produto_id
    FROM pedido_compra pc
    JOIN periodo p ON pc.data_pedido BETWEEN p.ini AND p.fim
    GROUP BY pc.produto_id
    HAVING SUM(pc.qtde_pedida) > 10
)
SELECT CONCAT_WS(' - ', pc.produto_id, NULLIF(TRIM(pc.descricao_produto), '')) AS "Produto",
       pc.qtde_pedida                                  AS "Qtde Requisitada",
       DATE_FORMAT(pc.data_pedido, '%d/m/%Y')           AS "Data Solicitação"
FROM pedido_compra pc
JOIN periodo p     ON pc.data_pedido BETWEEN p.ini AND p.fim
JOIN elegiveis e   ON e.produto_id = pc.produto_id
ORDER BY pc.data_pedido, pc.produto_id;

WITH periodo AS (
    SELECT DATE '2025-01-01' AS ini, DATE '2025-03-31' AS fim
)
SELECT CONCAT_WS(' - ', pc.produto_id, NULLIF(TRIM(MIN(pc.descricao_produto)), '')) AS "Produto",
       COUNT(*)                AS "Vezes requisitado",
       SUM(pc.qtde_pedida)     AS "Qtde Requisitada"
FROM pedido_compra pc
JOIN periodo p ON pc.data_pedido BETWEEN p.ini AND p.fim
GROUP BY pc.produto_id
HAVING COUNT(*) > 10;
/*
CREATE OR REPLACE FUNCTION public.fn_produtos_filial_gera_fornecedor()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_id integer;
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        INSERT INTO public.fornecedor (razao_social)
        VALUES ('A DEFINIR - fornecedor do produto ' || NEW.produto_id)
        RETURNING idfornecedor INTO v_id;
        NEW.idfornecedor := v_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_produtos_filial_fornecedor ON public.produtos_filial;
CREATE TRIGGER trg_produtos_filial_fornecedor
    BEFORE INSERT ON public.produtos_filial
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_produtos_filial_gera_fornecedor(); 
*/
-- obs; de teste a transação é desfeita no fim pra não suja a base
BEGIN;
    INSERT INTO produtos_filial (filial_id, produto_id, descricao, estoque, preco_unitario, preco_compra, preco_venda)
    VALUES (1, 'P99', 'Produto de teste da trigger', 1, 1, 1, 1);   
    SELECT p.produto_id, p.idfornecedor, f.razao_social
    FROM produtos_filial p JOIN fornecedor f ON f.idfornecedor = p.idfornecedor
    WHERE p.produto_id = 'P99';
    
ROLLBACK;


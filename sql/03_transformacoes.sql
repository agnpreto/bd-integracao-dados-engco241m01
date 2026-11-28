-- 03_transformacoes.sql  (PostgreSQL)
-- Requisitos (enunciado, Parte 3), para pedidos de compra, vendas e produtos:
--   1) concatenar produto_id e descricao (onde houver) no formato "12345 - Detergente"
--   2) datas no formato DD/MM/YYYY
--   3) so produtos requisitados mais de 10 vezes no periodo
--   4) trigger que gera automaticamente um novo idfornecedor NUMERICO na tabela de produtos,
--      relacionado a tabela de fornecedor

-- ===========================================================================
-- PEDIDOS DE COMPRA  (requisitos 1, 2 e 3)
-- Saida: Produto | Qtde Requisitada | Data Solicitacao   (ex.: 12345 - Detergente | 15 | 01/01/2025)
--
-- INTERPRETACAO de "requisitados mais de 10 vezes": QUANTIDADE requisitada maior que 10
-- (qtde_pedida > 10), como no exemplo do enunciado (15 unidades numa linha). A leitura
-- alternativa (produto presente em mais de 10 pedidos) esta comentada abaixo e, nesta base,
-- nao retorna nenhuma linha (cada produto aparece no maximo 2 vezes).
-- PERIODO: por padrao todo o periodo da base; para outro periodo, troque as datas da CTE.
-- ===========================================================================
WITH periodo AS (
    SELECT MIN(data_pedido) AS ini, MAX(data_pedido) AS fim
    FROM   public.pedido_compra
    -- Para um periodo fixo, use: SELECT DATE '2025-02-01' AS ini, DATE '2025-02-28' AS fim
)
SELECT concat_ws(' - ', p.produto_id,
                 COALESCE(p.descricao_produto, pf.descricao)) AS "Produto",
       p.qtde_pedida                                          AS "Qtde Requisitada",
       to_char(p.data_pedido, 'DD/MM/YYYY')                   AS "Data Solicitação"
FROM   public.pedido_compra p
LEFT   JOIN public.produtos_filial pf
       ON pf.filial_id = p.filial_id AND pf.produto_id = p.produto_id
CROSS  JOIN periodo
WHERE  p.qtde_pedida > 10
  AND  p.data_pedido BETWEEN periodo.ini AND periodo.fim
ORDER  BY p.data_pedido, p.produto_id;

-- Leitura alternativa: produtos requisitados em MAIS DE 10 pedidos no periodo
-- SELECT concat_ws(' - ', p.produto_id, MAX(p.descricao_produto)) AS "Produto",
--        SUM(p.qtde_pedida)                                       AS "Qtde Requisitada",
--        to_char(MIN(p.data_pedido), 'DD/MM/YYYY')                AS "Data Solicitação"
-- FROM   public.pedido_compra p
-- GROUP  BY p.produto_id
-- HAVING COUNT(*) > 10;

-- ===========================================================================
-- VENDAS  (requisitos 1 e 2; "requisitado" so se aplica a pedidos de compra)
-- A venda nao tem descricao: ela vem de produtos_filial (LEFT JOIN: "onde houver").
-- Saida: Produto | Qtde Vendida | Data Emissão
-- ===========================================================================
SELECT concat_ws(' - ', v.produto_id, pf.descricao) AS "Produto",
       v.qtde_vendida                               AS "Qtde Vendida",
       to_char(v.data_emissao, 'DD/MM/YYYY')        AS "Data Emissão"
FROM   public.venda v
LEFT   JOIN public.produtos_filial pf
       ON pf.filial_id = v.filial_id AND pf.produto_id = v.produto_id
ORDER  BY v.data_emissao, v.produto_id;

-- ===========================================================================
-- PRODUTOS  (requisito 1; produtos_filial nao tem campo de data)
-- Saida: Produto | Fornecedor
-- ===========================================================================
SELECT concat_ws(' - ', pf.produto_id, pf.descricao) AS "Produto",
       pf.filial_id                                  AS "Filial",
       f.razao_social                                AS "Fornecedor"
FROM   public.produtos_filial pf
LEFT   JOIN public.fornecedor f ON f.idfornecedor = pf.idfornecedor
ORDER  BY pf.filial_id, pf.produto_id;

-- ===========================================================================
-- TRIGGER (requisito 4)
-- Quando um produto e inserido em produtos_filial SEM fornecedor, a trigger gera um novo
-- idfornecedor numerico (maior id existente + 1), cria o registro correspondente em
-- fornecedor (razao social provisoria) e liga o produto a ele, mantendo a relacao
-- produtos_filial -> fornecedor. Produto inserido COM fornecedor nao e alterado.
-- Instalar DEPOIS da carga (senao a carga criaria fornecedores para produtos sem fornecedor).
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.fn_gera_fornecedor()
RETURNS trigger AS $$
DECLARE
    v_id integer;
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        -- evita que dois inserts simultaneos gerem o mesmo id
        PERFORM pg_advisory_xact_lock(hashtext('fornecedor_novo_id'));

        SELECT COALESCE(MAX(idfornecedor), 0) + 1 INTO v_id FROM public.fornecedor;

        INSERT INTO public.fornecedor (idfornecedor, razao_social)
        VALUES (v_id, 'Fornecedor ' || v_id || ' (gerado automaticamente)');

        NEW.idfornecedor := v_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_produtos_filial_fornecedor ON public.produtos_filial;
CREATE TRIGGER trg_produtos_filial_fornecedor
BEFORE INSERT ON public.produtos_filial
FOR EACH ROW EXECUTE FUNCTION public.fn_gera_fornecedor();

-- Teste (desfaz tudo no fim):
-- BEGIN;
-- INSERT INTO public.produtos_filial (filial_id, produto_id, descricao) VALUES (1, 'TESTE-1', 'Produto de teste');
-- SELECT pf.produto_id, pf.idfornecedor, f.razao_social
-- FROM   public.produtos_filial pf JOIN public.fornecedor f ON f.idfornecedor = pf.idfornecedor
-- WHERE  pf.produto_id = 'TESTE-1';     -- esperado: 21 | Fornecedor 21 (gerado automaticamente)
-- ROLLBACK;

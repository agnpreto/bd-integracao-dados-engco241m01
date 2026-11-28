-- Parte 3 - PostgreSQL 13+
-- Equipe: SELECT * FROM EU | Rick Iury Oliveira Andrade - 2417667

-- 3.1 Produto formatado e data no formato DD/MM/YYYY.
SELECT pc.pedido_id,
       CONCAT(pc.produto_id, ' - ', COALESCE(pc.descricao_produto, 'Sem descricao')) AS produto,
       pc.qtde_pedida AS quantidade_requisitada,
       TO_CHAR(pc.data_pedido, 'DD/MM/YYYY') AS data_solicitacao
FROM pedido_compra pc
WHERE pc.data_pedido >= '2025-02-01'
  AND pc.data_pedido < '2025-03-01'
ORDER BY pc.data_pedido, pc.pedido_id;

-- 3.2 INTERPRETACAO DA EXPRESSAO "mais de 10 vezes":
-- Significa MAIS DE 10 REQUISICOES (pedidos distintos) do mesmo produto,
-- no periodo de fevereiro/2025; nao significa quantidade superior a 10.
-- Na base de teste e possivel que esta consulta retorne ZERO linhas.
SELECT pc.produto_id,
       CONCAT(pc.produto_id, ' - ', MAX(pc.descricao_produto)) AS produto,
       COUNT(DISTINCT pc.pedido_id) AS vezes_requisitado,
       SUM(COALESCE(pc.qtde_pedida, 0)) AS total_unidades_requisitadas
FROM pedido_compra pc
WHERE pc.data_pedido >= '2025-02-01'
  AND pc.data_pedido < '2025-03-01'
GROUP BY pc.produto_id
HAVING COUNT(DISTINCT pc.pedido_id) > 10
ORDER BY vezes_requisitado DESC;

-- 3.3 Consulta adicional para interpretar quantidade MAIOR QUE 10 unidades,
-- caso o cliente/professor use "vezes" com o sentido de unidades.
SELECT CONCAT(pc.produto_id, ' - ', COALESCE(pc.descricao_produto, 'Sem descricao')) AS produto,
       pc.qtde_pedida AS quantidade_requisitada,
       TO_CHAR(pc.data_pedido, 'DD/MM/YYYY') AS data_solicitacao
FROM pedido_compra pc
WHERE pc.data_pedido >= '2025-02-01'
  AND pc.data_pedido < '2025-03-01'
  AND pc.qtde_pedida > 10
ORDER BY pc.data_pedido, pc.pedido_id;

-- 3.4 TRIGGER: ao cadastrar novo produto sem idfornecedor, cria uma referencia
-- AUTO_n na tabela fornecedor e associa essa chave ao produto.
-- A razao_social gerada e PROVISORIA; nao e um fornecedor verificado.
-- Nao modifica fornecedor ja preenchido (FK valida identificadores existentes).
CREATE SEQUENCE IF NOT EXISTS public.seq_fornecedor_automatico START 1;

CREATE OR REPLACE FUNCTION public.atribuir_fornecedor_automatico()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    novo_id VARCHAR(25);
BEGIN
    IF NEW.idfornecedor IS NULL OR BTRIM(NEW.idfornecedor) = '' THEN
        LOOP
            novo_id := 'AUTO_' || NEXTVAL('public.seq_fornecedor_automatico')::TEXT;
            INSERT INTO public.fornecedor (idfornecedor, razao_social)
            VALUES (novo_id, 'CADASTRO PROVISORIO - ' || novo_id)
            ON CONFLICT (idfornecedor) DO NOTHING;
            EXIT WHEN FOUND;
        END LOOP;
        NEW.idfornecedor := novo_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_fornecedor_automatico ON public.produtos_filial;
CREATE TRIGGER trg_fornecedor_automatico
BEFORE INSERT ON public.produtos_filial
FOR EACH ROW
EXECUTE FUNCTION public.atribuir_fornecedor_automatico();

-- Teste NAO destrutivo da trigger, para executar manualmente:
-- BEGIN;
-- INSERT INTO produtos_filial
-- (filial_id, produto_id, descricao, estoque, preco_unitario, preco_compra, preco_venda)
-- VALUES (999, 'P_TESTE_TRIGGER', 'Teste da trigger', 0, 0, 0, 0);
-- SELECT p.produto_id, p.idfornecedor, f.razao_social
-- FROM produtos_filial p JOIN fornecedor f ON f.idfornecedor = p.idfornecedor
-- WHERE p.filial_id = 999 AND p.produto_id = 'P_TESTE_TRIGGER';
-- ROLLBACK;

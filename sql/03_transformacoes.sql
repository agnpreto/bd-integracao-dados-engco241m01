-- 03_transformacoes
-- relatório de pedidos de fevereiro de 2025.
-- Interpretei "mais de 10 vezes" como aparecer em pelo menos 11 pedidos
-- distintos no mês. Um pedido de 15 unidades conta como uma solicitação.

WITH pedidos_do_mes AS (
    SELECT *
    FROM pedido_compra
    WHERE data_pedido >= DATE '2025-02-01'
      AND data_pedido < DATE '2025-03-01'
),
produtos_frequentes AS (
    SELECT produto_id
    FROM pedidos_do_mes
    GROUP BY produto_id
    HAVING COUNT(DISTINCT pedido_id) > 10
)
SELECT
    CONCAT_WS(' - ', p.produto_id, NULLIF(p.descricao_produto, '')) AS "Produto",
    p.qtde_pedida AS "Qtde Requisitada",
    TO_CHAR(p.data_pedido, 'DD/MM/YYYY') AS "Data Solicitação"
FROM pedidos_do_mes AS p
JOIN produtos_frequentes AS f ON f.produto_id = p.produto_id
ORDER BY p.data_pedido, p.pedido_id, p.item;

-- Exibição das vendas com data formatada e descrição quando disponível.
SELECT
    CONCAT_WS(' - ', v.produto_id, NULLIF(p.descricao, '')) AS "Produto",
    v.qtde_vendida AS "Qtde Vendida",
    TO_CHAR(v.data_emissao, 'DD/MM/YYYY') AS "Data da Venda"
FROM venda AS v
LEFT JOIN produtos_filial AS p
    ON p.produto_id = v.produto_id
   AND p.filial_id = v.filial_id
ORDER BY v.data_emissao, v.venda_id;

-- Exibição do cadastro de produtos por filial.
SELECT
    filial_id,
    CONCAT_WS(' - ', produto_id, NULLIF(descricao, '')) AS "Produto",
    estoque
FROM produtos_filial
ORDER BY filial_id, produto_id;

-- Função executada pelo trigger antes de cadastrar um produto.
CREATE OR REPLACE FUNCTION atribuir_fornecedor()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        INSERT INTO fornecedor (razao_social)
        VALUES ('Cadastro provisório - confirmar')
        RETURNING idfornecedor INTO NEW.idfornecedor;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER produto_fornecedor
BEFORE INSERT ON produtos_filial
FOR EACH ROW
EXECUTE FUNCTION atribuir_fornecedor();

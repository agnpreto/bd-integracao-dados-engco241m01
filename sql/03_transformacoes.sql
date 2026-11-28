-- 03_transformacoes
-- Nome:Luiz Cabral

-- Concatenar produto_id e descricao_produto

CREATE OR REPLACE FUNCTION public.fn_produto_descricao(p_produto_id text, p_descricao text)
RETURNS text LANGUAGE sql STABLE AS $$
    SELECT CONCAT_WS(' - ', NULLIF(TRIM(p_produto_id), ''), NULLIF(TRIM(p_descricao), ''))
$$;

-- Datas no formato DD/MM/YYYY

CREATE OR REPLACE FUNCTION public.fn_data_br(p_data date)
RETURNS text LANGUAGE sql STABLE AS $$
    SELECT to_char(p_data, 'DD/MM/YYYY')
$$;

-- Views de apresentação para pedidos

CREATE OR REPLACE VIEW public.v_pedido_compra_fmt AS
SELECT pc.pedido_id,
       public.fn_produto_descricao(pc.produto_id, pc.descricao_produto) AS produto,
       pc.qtde_pedida                                                   AS qtde_requisitada,
       public.fn_data_br(pc.data_pedido)                                AS data_solicitacao,
       public.fn_data_br(pc.data_entrega)                               AS data_entrega
FROM   public.pedido_compra pc;


CREATE OR REPLACE VIEW public.v_venda_fmt AS
SELECT v.venda_id,
       public.fn_produto_descricao(v.produto_id, p.descricao)           AS produto,
       v.qtde_vendida,
       v.valor_unitario,
       public.fn_data_br(v.data_emissao)                                AS data_emissao
FROM   public.venda v
LEFT JOIN public.produtos_filial p
       ON p.filial_id = v.filial_id AND p.produto_id = v.produto_id;

CREATE OR REPLACE VIEW public.v_produtos_filial_fmt AS
SELECT p.filial_id,
       public.fn_produto_descricao(p.produto_id, p.descricao)           AS produto,
       p.estoque, p.preco_venda, p.idfornecedor
FROM   public.produtos_filial p;

SELECT * FROM public.v_pedido_compra_fmt  ORDER BY pedido_id LIMIT 5;
SELECT * FROM public.v_venda_fmt          ORDER BY venda_id  LIMIT 5;
SELECT * FROM public.v_venda_fmt          WHERE venda_id IN (20, 21);   -- 21: produto sem cadastro, só o código
SELECT * FROM public.v_produtos_filial_fmt ORDER BY produto LIMIT 5;

-- "mais de 10 vezes"
 
CREATE OR REPLACE FUNCTION public.fn_produtos_requisitados(
        p_ini      date    DEFAULT NULL,
        p_fim      date    DEFAULT NULL,
        p_minimo   numeric DEFAULT 10,
        p_criterio text    DEFAULT 'QTDE')
RETURNS TABLE (produto text, qtde_requisitada numeric, data_solicitacao text)
LANGUAGE sql STABLE AS $$
    WITH no_periodo AS (
        SELECT pc.*
        FROM   public.pedido_compra pc
        WHERE  (p_ini IS NULL OR pc.data_pedido >= p_ini)
          AND  (p_fim IS NULL OR pc.data_pedido <= p_fim)
    ),
    qualificados AS (
        SELECT produto_id
        FROM   no_periodo
        GROUP  BY produto_id
        HAVING CASE upper(p_criterio)
                   WHEN 'QTDE'  THEN SUM(qtde_pedida) > p_minimo
                   WHEN 'VEZES' THEN COUNT(*)         > p_minimo
               END
    )
    SELECT public.fn_produto_descricao(np.produto_id, np.descricao_produto),
           np.qtde_pedida,
           public.fn_data_br(np.data_pedido)
    FROM   no_periodo np
    JOIN   qualificados q USING (produto_id)
    ORDER  BY np.data_pedido, np.produto_id, np.pedido_id
$$;

SELECT * FROM public.fn_produtos_requisitados();                                  -- toda a base, soma > 10
SELECT * FROM public.fn_produtos_requisitados('2025-02-01', '2025-02-28');        -- só fevereiro
SELECT * FROM public.fn_produtos_requisitados(NULL, NULL, 10, 'VEZES');           -- alternativa: 0 linhas

-- Trigger

SELECT setval(pg_get_serial_sequence('public.fornecedor', 'idfornecedor'),
              COALESCE((SELECT MAX(idfornecedor) FROM public.fornecedor), 1));

CREATE OR REPLACE FUNCTION public.fn_gera_idfornecedor() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        INSERT INTO public.fornecedor (razao_social)
        VALUES ('FORNECEDOR A CADASTRAR - produto ' || NEW.produto_id)
        RETURNING idfornecedor INTO NEW.idfornecedor;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_produtos_filial_idfornecedor ON public.produtos_filial;
CREATE TRIGGER trg_produtos_filial_idfornecedor
    BEFORE INSERT ON public.produtos_filial
    FOR EACH ROW EXECUTE FUNCTION public.fn_gera_idfornecedor();

-- Demonstração
    INSERT INTO public.produtos_filial (filial_id, produto_id, descricao, estoque, preco_venda)
    VALUES (1, 'P900', 'Produto de teste da trigger', 5, 9.90);          -- idfornecedor omitido

    SELECT p.produto_id, p.idfornecedor, f.razao_social                    -- esperado: 21 'FORNECEDOR A CADASTRAR...'
    FROM   public.produtos_filial p
    JOIN   public.fornecedor f ON f.idfornecedor = p.idfornecedor
    WHERE  p.produto_id = 'P900';
ROLLBACK;

/*
DELIMITER $$
CREATE TRIGGER trg_produtos_filial_idfornecedor
BEFORE INSERT ON produtos_filial
FOR EACH ROW
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        INSERT INTO fornecedor (razao_social)
        VALUES (CONCAT('FORNECEDOR A CADASTRAR - produto ', NEW.produto_id));
        SET NEW.idfornecedor = LAST_INSERT_ID();
    END IF;
END$$
DELIMITER ;

*/

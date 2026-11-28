-- 04_validacao
-- Nome: Luiz Cabral

SELECT 'fornecedor' AS tabela, COUNT(*) AS linhas FROM public.fornecedor
UNION ALL SELECT 'produtos_filial',      COUNT(*) FROM public.produtos_filial
UNION ALL SELECT 'pedido_compra',        COUNT(*) FROM public.pedido_compra
UNION ALL SELECT 'entradas_mercadoria',  COUNT(*) FROM public.entradas_mercadoria
UNION ALL SELECT 'venda',                COUNT(*) FROM public.venda;

-- Distribuição por mês

SELECT to_char(data_emissao, 'YYYY-MM') AS mes, COUNT(*) AS vendas,
       SUM(qtde_vendida) AS qtde, ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_rs
FROM   public.venda GROUP BY 1 ORDER BY 1;


-- FECHAMENTO DE FEVEREIRO/2025 
SELECT COUNT(*) AS vendas, SUM(qtde_vendida) AS qtde, ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_rs
FROM   public.venda
WHERE  data_emissao >= DATE '2025-02-01' AND data_emissao < DATE '2025-03-01';

-- Venda a venda, para o cliente conferir linha por linha com o sistema dele

SELECT v.venda_id, public.fn_data_br(v.data_emissao) AS data, v.filial_id,
       public.fn_produto_descricao(v.produto_id, p.descricao) AS produto,
       v.qtde_vendida, v.unidade_medida, v.valor_unitario,
       ROUND(v.qtde_vendida * v.valor_unitario, 2) AS total_linha
FROM   public.venda v
LEFT JOIN public.produtos_filial p ON p.filial_id = v.filial_id AND p.produto_id = v.produto_id
WHERE  v.data_emissao >= DATE '2025-02-01' AND v.data_emissao < DATE '2025-03-01'
ORDER  BY v.data_emissao, v.venda_id;

-- Por filial

SELECT filial_id, COUNT(*) AS vendas, SUM(qtde_vendida) AS qtde,
       ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_rs
FROM   public.venda
WHERE  data_emissao >= DATE '2025-02-01' AND data_emissao < DATE '2025-03-01'
GROUP  BY filial_id ORDER BY filial_id;

-- Compras de fevereiro

SELECT 'pedidos feitos em fev' AS item, COUNT(*) AS linhas, SUM(qtde_pedida) AS qtde
FROM   public.pedido_compra WHERE data_pedido >= DATE '2025-02-01' AND data_pedido < DATE '2025-03-01'
UNION ALL
SELECT 'entradas (NF) em fev', COUNT(*), SUM(qtde_recebida)
FROM   public.entradas_mercadoria WHERE data_entrada >= DATE '2025-02-01' AND data_entrada < DATE '2025-03-01';


--Erro nos dados

-- 1 venda: produto sem cadastro em produtos_filial (13 linhas, produtos P21..P28)

SELECT v.venda_id, v.data_emissao, v.filial_id, v.produto_id
FROM   public.venda v
WHERE  NOT EXISTS (SELECT 1 FROM public.produtos_filial p
                   WHERE p.filial_id = v.filial_id AND p.produto_id = v.produto_id)
ORDER  BY v.venda_id;

--2 venda: filial que não existe no cadastro (filiais 2 e 3; só a 1 tem produtos)

SELECT v.venda_id, v.data_emissao, v.filial_id, v.produto_id
FROM   public.venda v
WHERE  v.filial_id NOT IN (SELECT DISTINCT filial_id FROM public.produtos_filial)
ORDER  BY v.venda_id;

--3 venda: quantidade fracionada em unidade UN (5 linhas)

SELECT venda_id, produto_id, qtde_vendida, unidade_medida
FROM   public.venda
WHERE  unidade_medida = 'UN' AND qtde_vendida <> TRUNC(qtde_vendida)
ORDER  BY venda_id;

--4  venda: preço praticado diferente do preco_venda do cadastro (20 de 20 comparáveis)

SELECT v.venda_id, v.produto_id, v.valor_unitario AS preco_na_venda, p.preco_venda AS preco_cadastro
FROM   public.venda v JOIN public.produtos_filial p USING (filial_id, produto_id)
WHERE  v.valor_unitario <> p.preco_venda
ORDER  BY v.venda_id;

--5  venda: vendida abaixo do custo de cadastro (7 linhas)

SELECT v.venda_id, v.produto_id, v.valor_unitario AS preco_na_venda, p.preco_compra AS custo_cadastro
FROM   public.venda v JOIN public.produtos_filial p USING (filial_id, produto_id)
WHERE  v.valor_unitario < p.preco_compra
ORDER  BY v.venda_id;

--6  venda: mesma data e mesmo valor unitário em PRODUTOS diferentes (7 pares: suspeita de linha copiada)

SELECT a.venda_id AS venda_a, a.produto_id AS produto_a, b.venda_id AS venda_b, b.produto_id AS produto_b,
       a.data_emissao, a.valor_unitario
FROM   public.venda a JOIN public.venda b
       ON a.data_emissao = b.data_emissao AND a.valor_unitario = b.valor_unitario
      AND a.venda_id < b.venda_id AND a.produto_id <> b.produto_id
ORDER  BY a.venda_id;

--7  venda: horário idêntico em todas as vendas (08:00:00 em 33 de 33; o horário não é real)

SELECT horariomov, COUNT(*) AS vendas FROM public.venda GROUP BY horariomov;

--8  pedido_compra: data de entrega ANTERIOR à data do pedido (20 linhas)

SELECT pedido_id, produto_id, data_pedido, data_entrega, data_entrega - data_pedido AS dias
FROM   public.pedido_compra
WHERE  data_entrega < data_pedido
ORDER  BY pedido_id;

--9  pedido_compra: sem ordem_compra (era 0 na planilha) (11 linhas: pedidos 19..29)

SELECT pedido_id, produto_id, data_pedido, qtde_pedida
FROM   public.pedido_compra
WHERE  ordem_compra IS NULL
ORDER  BY pedido_id;

--10  pedido_compra: possíveis requisições duplicadas (9 pares: pedidos 12..20 x 21..29)
   
SELECT a.pedido_id AS pedido, b.pedido_id AS repetido, a.produto_id, a.data_pedido, a.data_entrega,
       a.preco_compra, a.qtde_pedida AS qtde_pedido, b.qtde_pedida AS qtde_repetido,
       a.ordem_compra AS ordem_pedido, b.ordem_compra AS ordem_repetido
FROM   public.pedido_compra a JOIN public.pedido_compra b
       ON a.produto_id = b.produto_id AND a.data_pedido = b.data_pedido
      AND a.data_entrega = b.data_entrega AND a.preco_compra = b.preco_compra
      AND a.fornecedor_id = b.fornecedor_id AND a.pedido_id < b.pedido_id
ORDER  BY a.pedido_id;

--11  pedido_compra: qtde_entregue diferente do que as entradas registram (18 de 18 pareados)

SELECT p.pedido_id, p.produto_id, p.qtde_pedida, p.qtde_entregue AS entregue_no_pedido,
       e.nro_nfe, e.qtde_recebida AS recebido_na_nf
FROM   public.pedido_compra p
JOIN   public.entradas_mercadoria e
       ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id AND e.item = p.item
WHERE  p.qtde_entregue <> e.qtde_recebida
ORDER  BY p.pedido_id;

--12  pedido_compra: fornecedor do pedido diferente do fornecedor do cadastro do produto (22 de 29)

SELECT p.pedido_id, p.produto_id, p.fornecedor_id AS fornecedor_no_pedido, f.idfornecedor AS fornecedor_no_cadastro
FROM   public.pedido_compra p
JOIN   public.produtos_filial f ON f.filial_id = p.filial_id AND f.produto_id = p.produto_id
WHERE  p.fornecedor_id IS DISTINCT FROM f.idfornecedor
ORDER  BY p.pedido_id;

--13  pedido_compra: preço de compra do pedido diferente do cadastro (29 de 29)

SELECT p.pedido_id, p.produto_id, p.preco_compra AS preco_pedido, f.preco_compra AS preco_cadastro
FROM   public.pedido_compra p
JOIN   public.produtos_filial f ON f.filial_id = p.filial_id AND f.produto_id = p.produto_id
WHERE  p.preco_compra <> f.preco_compra
ORDER  BY p.pedido_id;

--14  entradas_mercadoria: NF cuja ordem_compra não existe em nenhum pedido (2 linhas: NFE19, NFE20)

SELECT e.nro_nfe, e.ordem_compra, e.produto_id, e.qtde_recebida, e.data_entrada
FROM   public.entradas_mercadoria e
WHERE  NOT EXISTS (SELECT 1 FROM public.pedido_compra p WHERE p.ordem_compra = e.ordem_compra)
ORDER  BY e.nro_nfe;

--15  entradas_mercadoria: recebido MAIOR que o pedido (7 linhas)

SELECT p.pedido_id, p.produto_id, p.qtde_pedida, e.nro_nfe, e.qtde_recebida,
       e.qtde_recebida - p.qtde_pedida AS excesso
FROM   public.pedido_compra p
JOIN   public.entradas_mercadoria e
       ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id AND e.item = p.item
WHERE  e.qtde_recebida > p.qtde_pedida
ORDER  BY p.pedido_id;

--16  entradas_mercadoria: NF com data ANTERIOR à data do pedido (9 linhas)

SELECT p.pedido_id, p.produto_id, p.data_pedido, e.nro_nfe, e.data_entrada
FROM   public.pedido_compra p
JOIN   public.entradas_mercadoria e
       ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id AND e.item = p.item
WHERE  e.data_entrada < p.data_pedido
ORDER  BY p.pedido_id;

--17  entradas_mercadoria: custo da NF diferente do preço do pedido (18 de 18 pareados)

SELECT p.pedido_id, p.produto_id, p.preco_compra AS preco_pedido, e.nro_nfe, e.custo_unitario AS custo_nf
FROM   public.pedido_compra p
JOIN   public.entradas_mercadoria e
       ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id AND e.item = p.item
WHERE  e.custo_unitario <> p.preco_compra
ORDER  BY p.pedido_id;

--18  produtos_filial: preço de venda MENOR que o preço de compra (4 produtos: P1, P8, P15, P18)

SELECT produto_id, preco_compra, preco_venda, preco_venda - preco_compra AS margem
FROM   public.produtos_filial
WHERE  preco_venda < preco_compra
ORDER  BY produto_id;

--19  produtos_filial: preco_unitario diferente de preco_venda (20 de 20; o campo não tem definição clara)

SELECT produto_id, preco_unitario, preco_venda, preco_compra
FROM   public.produtos_filial
WHERE  preco_unitario <> preco_venda
ORDER  BY produto_id;

-- BLOCO D. PAINEL CONSOLIDADO (uma linha por erro; é a tabela de parte4_validacao.md)

SELECT * FROM (
  SELECT 'E01' AS id, 'venda' AS tabela, 'produto sem cadastro em produtos_filial' AS problema,
         (SELECT COUNT(*) FROM public.venda v WHERE NOT EXISTS (SELECT 1 FROM public.produtos_filial p
                 WHERE p.filial_id=v.filial_id AND p.produto_id=v.produto_id)) AS quantidade,
         (SELECT COUNT(*) FROM public.venda) AS universo
  UNION ALL SELECT 'E02','venda','filial sem cadastro (2 e 3)',
         (SELECT COUNT(*) FROM public.venda WHERE filial_id NOT IN (SELECT filial_id FROM public.produtos_filial)),
         (SELECT COUNT(*) FROM public.venda)
  UNION ALL SELECT 'E03','venda','quantidade fracionada em unidade UN',
         (SELECT COUNT(*) FROM public.venda WHERE unidade_medida='UN' AND qtde_vendida<>TRUNC(qtde_vendida)),
         (SELECT COUNT(*) FROM public.venda)
  UNION ALL SELECT 'E04','venda','preço da venda diferente do preco_venda do cadastro',
         (SELECT COUNT(*) FROM public.venda v JOIN public.produtos_filial p USING (filial_id,produto_id) WHERE v.valor_unitario<>p.preco_venda),
         (SELECT COUNT(*) FROM public.venda v JOIN public.produtos_filial p USING (filial_id,produto_id))
  UNION ALL SELECT 'E05','venda','vendida abaixo do custo de cadastro',
         (SELECT COUNT(*) FROM public.venda v JOIN public.produtos_filial p USING (filial_id,produto_id) WHERE v.valor_unitario<p.preco_compra),
         (SELECT COUNT(*) FROM public.venda v JOIN public.produtos_filial p USING (filial_id,produto_id))
  UNION ALL SELECT 'E06','venda','mesma data e valor unitário em produtos diferentes (pares)',
         (SELECT COUNT(*) FROM public.venda a JOIN public.venda b ON a.data_emissao=b.data_emissao AND a.valor_unitario=b.valor_unitario AND a.venda_id<b.venda_id AND a.produto_id<>b.produto_id),
         (SELECT COUNT(*) FROM public.venda)
  UNION ALL SELECT 'E07','venda','horário igual (08:00:00) em todas as vendas',
         (SELECT COUNT(*) FROM public.venda WHERE horariomov = (SELECT MIN(horariomov) FROM public.venda)),
         (SELECT COUNT(*) FROM public.venda)
  UNION ALL SELECT 'E08','pedido_compra','data de entrega anterior à data do pedido',
         (SELECT COUNT(*) FROM public.pedido_compra WHERE data_entrega<data_pedido),
         (SELECT COUNT(*) FROM public.pedido_compra)
  UNION ALL SELECT 'E09','pedido_compra','sem ordem_compra (0 na planilha)',
         (SELECT COUNT(*) FROM public.pedido_compra WHERE ordem_compra IS NULL),
         (SELECT COUNT(*) FROM public.pedido_compra)
  UNION ALL SELECT 'E10','pedido_compra','possíveis requisições duplicadas (pares)',
         (SELECT COUNT(*) FROM public.pedido_compra a JOIN public.pedido_compra b ON a.produto_id=b.produto_id AND a.data_pedido=b.data_pedido AND a.data_entrega=b.data_entrega AND a.preco_compra=b.preco_compra AND a.fornecedor_id=b.fornecedor_id AND a.pedido_id<b.pedido_id),
         (SELECT COUNT(*) FROM public.pedido_compra)
  UNION ALL SELECT 'E11','pedido_compra','qtde_entregue diferente do recebido nas entradas',
         (SELECT COUNT(*) FROM public.pedido_compra p JOIN public.entradas_mercadoria e ON e.ordem_compra=p.ordem_compra AND e.produto_id=p.produto_id AND e.item=p.item WHERE p.qtde_entregue<>e.qtde_recebida),
         (SELECT COUNT(*) FROM public.pedido_compra p JOIN public.entradas_mercadoria e ON e.ordem_compra=p.ordem_compra AND e.produto_id=p.produto_id AND e.item=p.item)
  UNION ALL SELECT 'E12','pedido_compra','fornecedor do pedido diferente do cadastro do produto',
         (SELECT COUNT(*) FROM public.pedido_compra p JOIN public.produtos_filial f ON f.filial_id=p.filial_id AND f.produto_id=p.produto_id WHERE p.fornecedor_id IS DISTINCT FROM f.idfornecedor),
         (SELECT COUNT(*) FROM public.pedido_compra p JOIN public.produtos_filial f ON f.filial_id=p.filial_id AND f.produto_id=p.produto_id)
  UNION ALL SELECT 'E13','pedido_compra','preço de compra do pedido diferente do cadastro',
         (SELECT COUNT(*) FROM public.pedido_compra p JOIN public.produtos_filial f ON f.filial_id=p.filial_id AND f.produto_id=p.produto_id WHERE p.preco_compra<>f.preco_compra),
         (SELECT COUNT(*) FROM public.pedido_compra p JOIN public.produtos_filial f ON f.filial_id=p.filial_id AND f.produto_id=p.produto_id)
  UNION ALL SELECT 'E14','entradas_mercadoria','NF com ordem_compra sem pedido',
         (SELECT COUNT(*) FROM public.entradas_mercadoria e WHERE NOT EXISTS (SELECT 1 FROM public.pedido_compra p WHERE p.ordem_compra=e.ordem_compra)),
         (SELECT COUNT(*) FROM public.entradas_mercadoria)
  UNION ALL SELECT 'E15','entradas_mercadoria','recebido maior que o pedido',
         (SELECT COUNT(*) FROM public.pedido_compra p JOIN public.entradas_mercadoria e ON e.ordem_compra=p.ordem_compra AND e.produto_id=p.produto_id AND e.item=p.item WHERE e.qtde_recebida>p.qtde_pedida),
         (SELECT COUNT(*) FROM public.pedido_compra p JOIN public.entradas_mercadoria e ON e.ordem_compra=p.ordem_compra AND e.produto_id=p.produto_id AND e.item=p.item)
  UNION ALL SELECT 'E16','entradas_mercadoria','NF anterior à data do pedido',
         (SELECT COUNT(*) FROM public.pedido_compra p JOIN public.entradas_mercadoria e ON e.ordem_compra=p.ordem_compra AND e.produto_id=p.produto_id AND e.item=p.item WHERE e.data_entrada<p.data_pedido),
         (SELECT COUNT(*) FROM public.pedido_compra p JOIN public.entradas_mercadoria e ON e.ordem_compra=p.ordem_compra AND e.produto_id=p.produto_id AND e.item=p.item)
  UNION ALL SELECT 'E17','entradas_mercadoria','custo da NF diferente do preço do pedido',
         (SELECT COUNT(*) FROM public.pedido_compra p JOIN public.entradas_mercadoria e ON e.ordem_compra=p.ordem_compra AND e.produto_id=p.produto_id AND e.item=p.item WHERE e.custo_unitario<>p.preco_compra),
         (SELECT COUNT(*) FROM public.pedido_compra p JOIN public.entradas_mercadoria e ON e.ordem_compra=p.ordem_compra AND e.produto_id=p.produto_id AND e.item=p.item)
  UNION ALL SELECT 'E18','produtos_filial','preço de venda menor que o de compra',
         (SELECT COUNT(*) FROM public.produtos_filial WHERE preco_venda<preco_compra),
         (SELECT COUNT(*) FROM public.produtos_filial)
  UNION ALL SELECT 'E19','produtos_filial','preco_unitario diferente de preco_venda',
         (SELECT COUNT(*) FROM public.produtos_filial WHERE preco_unitario<>preco_venda),
         (SELECT COUNT(*) FROM public.produtos_filial)
) t ORDER BY id;

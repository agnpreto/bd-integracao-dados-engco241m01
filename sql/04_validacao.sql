-- 04_validacao.sql  (PostgreSQL)
-- Consultas para a reunião de validação. Duas partes:
--   A) CONFERENCIA DE TOTAIS (R01-R05): numeros para o cliente confirmar com o sistema dele.
--   B) BUSCA DE ERROS (V, P, E, F): cada consulta devolve as linhas problematicas (0 linhas = sem achado).

-- ======================= A) CONFERENCIA DE TOTAIS ==========================
-- R01 Quantidade de linhas carregadas em cada tabela (comparar com a planilha: 20/20/29/20/33)
SELECT 'fornecedor' AS tabela, COUNT(*) AS linhas FROM public.fornecedor
UNION ALL SELECT 'produtos_filial',      COUNT(*) FROM public.produtos_filial
UNION ALL SELECT 'pedido_compra',        COUNT(*) FROM public.pedido_compra
UNION ALL SELECT 'entradas_mercadoria',  COUNT(*) FROM public.entradas_mercadoria
UNION ALL SELECT 'venda',                COUNT(*) FROM public.venda;

-- R02 Total de vendas de fevereiro/2025 (esperado nesta base: 14 linhas, 173,22 unidades, R$ 14.093,17)
SELECT COUNT(*)                                  AS linhas_de_venda,
       COUNT(DISTINCT venda_id)                  AS vendas,
       SUM(qtde_vendida)                         AS qtde_total,
       ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_total_rs
FROM   public.venda
WHERE  data_emissao >= DATE '2025-02-01' AND data_emissao < DATE '2025-03-01';

-- R03 Vendas de fevereiro por filial
SELECT filial_id, COUNT(*) AS linhas, SUM(qtde_vendida) AS qtde_total,
       ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_total_rs
FROM   public.venda
WHERE  data_emissao >= DATE '2025-02-01' AND data_emissao < DATE '2025-03-01'
GROUP  BY filial_id ORDER BY filial_id;

-- R04 Pedidos de compra feitos em fevereiro/2025
SELECT COUNT(*) AS linhas, COUNT(DISTINCT pedido_id) AS pedidos, SUM(qtde_pedida) AS qtde_pedida
FROM   public.pedido_compra
WHERE  data_pedido >= DATE '2025-02-01' AND data_pedido < DATE '2025-03-01';

-- R05 Entradas de mercadoria em fevereiro/2025
SELECT COUNT(*) AS linhas, COUNT(DISTINCT nro_nfe) AS notas, SUM(qtde_recebida) AS qtde_recebida,
       ROUND(SUM(qtde_recebida * custo_unitario), 2) AS valor_rs
FROM   public.entradas_mercadoria
WHERE  data_entrada >= DATE '2025-02-01' AND data_entrada < DATE '2025-03-01';

-- ========================= B) BUSCA DE ERROS ===============================
-- ============================== VENDA ======================================
-- V01 Produto vendido sem cadastro na filial
SELECT DISTINCT v.filial_id, v.produto_id
FROM   public.venda v
LEFT   JOIN public.produtos_filial pf
       ON pf.filial_id = v.filial_id AND pf.produto_id = v.produto_id
WHERE  pf.produto_id IS NULL;

-- V02 Quantidade ausente, zero ou negativa
SELECT * FROM public.venda WHERE qtde_vendida IS NULL OR qtde_vendida <= 0;

-- V03 Valor unitario zero ou negativo
SELECT * FROM public.venda WHERE valor_unitario <= 0;

-- V04 Vendas fora do periodo em validacao (fev/2025)
SELECT * FROM public.venda
WHERE  data_emissao < DATE '2025-02-01' OR data_emissao >= DATE '2025-03-01';

-- V05 Unidades de medida usadas (procurar grafias estranhas)
SELECT unidade_medida, COUNT(*) FROM public.venda GROUP BY 1 ORDER BY 2 DESC;

-- V06 Preco praticado diferente do preco_venda cadastrado
SELECT v.venda_id, v.data_emissao, v.produto_id, v.valor_unitario, pf.preco_venda
FROM   public.venda v
JOIN   public.produtos_filial pf
       ON pf.filial_id = v.filial_id AND pf.produto_id = v.produto_id
WHERE  v.valor_unitario <> pf.preco_venda;

-- V07 Possivel venda em duplicidade (mesmo item, data, hora, quantidade e valor em venda_id diferentes)
SELECT filial_id, data_emissao, horariomov, produto_id, qtde_vendida, valor_unitario,
       COUNT(DISTINCT venda_id) AS qtd_vendas
FROM   public.venda
GROUP  BY filial_id, data_emissao, horariomov, produto_id, qtde_vendida, valor_unitario
HAVING COUNT(DISTINCT venda_id) > 1;

-- ========================== PEDIDO_COMPRA ==================================
-- P01 Produto do pedido sem cadastro na filial
SELECT p.* FROM public.pedido_compra p
LEFT JOIN public.produtos_filial pf
       ON pf.filial_id = p.filial_id AND pf.produto_id = p.produto_id
WHERE pf.produto_id IS NULL;

-- P02 fornecedor_id que nao existe em fornecedor
-- (a planilha traz 'F1' no cadastro e 1 no pedido; apos normalizar para numerico na carga, deve retornar 0 linhas)
SELECT p.* FROM public.pedido_compra p
LEFT JOIN public.fornecedor f ON f.idfornecedor = p.fornecedor_id
WHERE p.fornecedor_id IS NOT NULL AND f.idfornecedor IS NULL;

-- P03 Pedido sem fornecedor
SELECT * FROM public.pedido_compra WHERE fornecedor_id IS NULL;

-- P04 Entregue maior que pedido
SELECT * FROM public.pedido_compra WHERE qtde_entregue > qtde_pedida;

-- P05 Entrega anterior ao pedido
SELECT * FROM public.pedido_compra WHERE data_entrega < data_pedido;

-- P06 Quantidade ou preco ausente / nao positivo
SELECT * FROM public.pedido_compra
WHERE  qtde_pedida IS NULL OR qtde_pedida <= 0
   OR  preco_compra IS NULL OR preco_compra <= 0;

-- P07 Mesma ordem_compra usada em pedidos diferentes
SELECT ordem_compra, COUNT(DISTINCT pedido_id) AS pedidos
FROM   public.pedido_compra
GROUP  BY ordem_compra
HAVING COUNT(DISTINCT pedido_id) > 1;

-- P08 Descricao do pedido diferente do cadastro do produto
SELECT p.pedido_id, p.produto_id, p.descricao_produto, pf.descricao AS descricao_cadastro
FROM   public.pedido_compra p
JOIN   public.produtos_filial pf
       ON pf.filial_id = p.filial_id AND pf.produto_id = p.produto_id
WHERE  p.descricao_produto <> pf.descricao;

-- P09 qtde_entregue do pedido diverge do que realmente entrou em entradas_mercadoria
SELECT p.pedido_id, p.ordem_compra, p.item, p.produto_id, p.qtde_entregue,
       COALESCE(SUM(e.qtde_recebida), 0) AS recebido_nas_entradas
FROM   public.pedido_compra p
LEFT   JOIN public.entradas_mercadoria e
       ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
GROUP  BY p.pedido_id, p.produto_id, p.item
HAVING p.qtde_entregue <> COALESCE(SUM(e.qtde_recebida), 0);

-- ======================= ENTRADAS_MERCADORIA ===============================
-- E01 Entrada sem pedido correspondente (ordem_compra + produto)
SELECT e.* FROM public.entradas_mercadoria e
WHERE NOT EXISTS (SELECT 1 FROM public.pedido_compra p
                  WHERE p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id);

-- E02 Recebido acima do pedido
SELECT p.ordem_compra, p.produto_id, p.qtde_pedida, SUM(e.qtde_recebida) AS recebido
FROM   public.pedido_compra p
JOIN   public.entradas_mercadoria e
       ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
GROUP  BY p.ordem_compra, p.produto_id, p.pedido_id, p.item, p.qtde_pedida
HAVING SUM(e.qtde_recebida) > p.qtde_pedida;

-- E03 Entrada anterior ao pedido
SELECT e.nro_nfe, e.ordem_compra, e.produto_id, e.data_entrada, p.data_pedido
FROM   public.entradas_mercadoria e
JOIN   public.pedido_compra p
       ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
WHERE  e.data_entrada < p.data_pedido;

-- E04 Custo da entrada zero ou diferente do preco de compra do pedido
SELECT e.nro_nfe, e.ordem_compra, e.produto_id, e.custo_unitario, p.preco_compra
FROM   public.entradas_mercadoria e
JOIN   public.pedido_compra p
       ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
WHERE  e.custo_unitario = 0 OR e.custo_unitario <> p.preco_compra;

-- E05 Quantidade recebida ausente ou nao positiva
SELECT * FROM public.entradas_mercadoria WHERE qtde_recebida IS NULL OR qtde_recebida <= 0;

-- E06 Mesma NF-e com datas de entrada diferentes
SELECT nro_nfe, COUNT(DISTINCT data_entrada) AS datas
FROM   public.entradas_mercadoria
GROUP  BY nro_nfe
HAVING COUNT(DISTINCT data_entrada) > 1;

-- E07 Filial da entrada diferente da filial do pedido
SELECT e.nro_nfe, e.ordem_compra, e.produto_id, e.filial_id AS filial_entrada, p.filial_id AS filial_pedido
FROM   public.entradas_mercadoria e
JOIN   public.pedido_compra p
       ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
WHERE  e.filial_id <> p.filial_id;

-- ========================= PRODUTOS_FILIAL / FORNECEDOR ====================
-- F01 Produto com fornecedor inexistente
SELECT pf.* FROM public.produtos_filial pf
LEFT JOIN public.fornecedor f ON f.idfornecedor = pf.idfornecedor
WHERE pf.idfornecedor IS NOT NULL AND f.idfornecedor IS NULL;

-- F02 Produto sem fornecedor
SELECT * FROM public.produtos_filial WHERE idfornecedor IS NULL;

-- F03 Estoque negativo
SELECT * FROM public.produtos_filial WHERE estoque < 0;

-- F04 Preco de venda menor ou igual ao de compra (margem negativa ou nula)
SELECT * FROM public.produtos_filial WHERE preco_venda <= preco_compra;

-- F05 Mesmo produto com descricoes diferentes entre filiais
SELECT produto_id, COUNT(DISTINCT descricao) AS descricoes
FROM   public.produtos_filial
GROUP  BY produto_id
HAVING COUNT(DISTINCT descricao) > 1;

-- F06 Codigos de produto com espacos nas pontas ou sem padrao (comparar tabelas)
SELECT 'venda' AS tabela, produto_id FROM public.venda WHERE produto_id <> btrim(produto_id)
UNION ALL SELECT 'pedido_compra', produto_id FROM public.pedido_compra WHERE produto_id <> btrim(produto_id)
UNION ALL SELECT 'entradas_mercadoria', produto_id FROM public.entradas_mercadoria WHERE produto_id <> btrim(produto_id)
UNION ALL SELECT 'produtos_filial', produto_id FROM public.produtos_filial WHERE produto_id <> btrim(produto_id);

-- F07 Fornecedores com a mesma razao social e ids diferentes
SELECT razao_social, COUNT(*) AS ids FROM public.fornecedor
GROUP BY razao_social HAVING COUNT(*) > 1;

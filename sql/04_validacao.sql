-- Parte 4 - consultas para reuniao de validacao dos dados (fevereiro/2025)
-- Compatibilidade: PostgreSQL 13+ e MySQL 8.0+
-- Execute depois do DDL e da importacao. Nao modifica dados.
-- As consultas exibem LINHAS SUSPEITAS, nao corrigem a planilha automaticamente.

-- V01: Conferencia de quantidade por tabela.
SELECT 'fornecedor' tabela, COUNT(*) registros FROM fornecedor
UNION ALL SELECT 'produtos_filial', COUNT(*) FROM produtos_filial
UNION ALL SELECT 'pedido_compra', COUNT(*) FROM pedido_compra
UNION ALL SELECT 'entradas_mercadoria', COUNT(*) FROM entradas_mercadoria
UNION ALL SELECT 'venda', COUNT(*) FROM venda;

-- V02: Total de vendas em fevereiro/2025.
SELECT COUNT(*) AS itens_venda,
       SUM(qtde_vendida) AS quantidade_total,
       SUM(qtde_vendida * valor_unitario) AS valor_total_exato
FROM venda
WHERE data_emissao >= '2025-02-01'
  AND data_emissao < '2025-03-01';

-- V03: Vendas de produto sem cadastro NA MESMA FILIAL.
-- Se a loja vendeu produto sem cadastro, nao se deve excluir a venda do total.
SELECT v.venda_id, v.filial_id, v.produto_id, v.data_emissao, v.qtde_vendida
FROM venda v
WHERE NOT EXISTS (
    SELECT 1 FROM produtos_filial p
    WHERE p.filial_id = v.filial_id AND p.produto_id = v.produto_id
)
ORDER BY v.venda_id;

-- V04: Pedidos sem ordem valida (ordem_compra = 0).
SELECT pedido_id, produto_id, data_pedido, ordem_compra, qtde_pedida
FROM pedido_compra
WHERE ordem_compra = 0
ORDER BY pedido_id;

-- V05: Pedidos sem entrada comprovada na mesma ordem, item e produto.
SELECT p.pedido_id, p.ordem_compra, p.item, p.produto_id,
       p.qtde_pedida, p.qtde_entregue
FROM pedido_compra p
WHERE p.ordem_compra = 0
   OR NOT EXISTS (
       SELECT 1 FROM entradas_mercadoria e
       WHERE e.ordem_compra = p.ordem_compra
         AND e.item = p.item
         AND e.produto_id = p.produto_id
   )
ORDER BY p.pedido_id;

-- V06: Entradas de mercadoria sem pedido correspondente.
SELECT e.nro_nfe, e.ordem_compra, e.item, e.produto_id,
       e.data_entrada, e.qtde_recebida
FROM entradas_mercadoria e
WHERE NOT EXISTS (
    SELECT 1 FROM pedido_compra p
    WHERE p.ordem_compra = e.ordem_compra
      AND p.item = e.item
      AND p.produto_id = e.produto_id
      AND p.ordem_compra <> 0
)
ORDER BY e.nro_nfe;

-- V07: Quantidade recebida maior que a quantidade solicitada.
SELECT p.pedido_id, p.produto_id, p.qtde_pedida,
       SUM(COALESCE(e.qtde_recebida, 0)) AS qtde_recebida,
       SUM(COALESCE(e.qtde_recebida, 0)) - p.qtde_pedida AS excesso
FROM pedido_compra p
JOIN entradas_mercadoria e
    ON e.ordem_compra = p.ordem_compra AND p.ordem_compra <> 0
   AND e.item = p.item AND e.produto_id = p.produto_id
GROUP BY p.pedido_id, p.produto_id, p.qtde_pedida
HAVING SUM(COALESCE(e.qtde_recebida, 0)) > p.qtde_pedida
ORDER BY p.pedido_id;

-- V08: Entrada de mercadoria anterior a data do pedido.
SELECT p.pedido_id, p.data_pedido, e.nro_nfe, e.data_entrada, e.produto_id
FROM pedido_compra p
JOIN entradas_mercadoria e
    ON e.ordem_compra = p.ordem_compra AND p.ordem_compra <> 0
   AND e.item = p.item AND e.produto_id = p.produto_id
WHERE e.data_entrada < p.data_pedido
ORDER BY p.pedido_id;

-- V09: Data de entrega informada anterior a data de pedido.
SELECT pedido_id, produto_id, data_pedido, data_entrega
FROM pedido_compra
WHERE data_entrega IS NOT NULL AND data_pedido IS NOT NULL
  AND data_entrega < data_pedido
ORDER BY pedido_id;

-- V10: Divergencia entre qtde_entregue informada no pedido e notas fiscais.
SELECT p.pedido_id, p.produto_id, p.qtde_entregue,
       COALESCE(SUM(e.qtde_recebida), 0) AS total_em_nfe,
       p.qtde_entregue - COALESCE(SUM(e.qtde_recebida), 0) AS diferenca
FROM pedido_compra p
LEFT JOIN entradas_mercadoria e
    ON p.ordem_compra <> 0 AND p.ordem_compra = e.ordem_compra
   AND p.item = e.item AND p.produto_id = e.produto_id
GROUP BY p.pedido_id, p.produto_id, p.qtde_entregue
HAVING p.qtde_entregue <> COALESCE(SUM(e.qtde_recebida), 0)
ORDER BY p.pedido_id;

-- V11: Saldo pendente calculado difere da coluna importada.
SELECT pedido_id, produto_id, qtde_pedida, qtde_entregue, qtde_pendente
FROM pedido_compra
WHERE qtde_pedida IS NOT NULL
  AND qtde_pendente <> qtde_pedida - qtde_entregue;

-- V12: Fornecedores inexistentes referenciados por produtos.
SELECT p.filial_id, p.produto_id, p.idfornecedor
FROM produtos_filial p
LEFT JOIN fornecedor f ON f.idfornecedor = p.idfornecedor
WHERE p.idfornecedor IS NOT NULL AND f.idfornecedor IS NULL;

-- V13: Fornecedores inexistentes referenciados por pedidos.
SELECT p.pedido_id, p.produto_id, p.fornecedor_id
FROM pedido_compra p
LEFT JOIN fornecedor f ON f.idfornecedor = p.fornecedor_id
WHERE p.fornecedor_id IS NOT NULL AND f.idfornecedor IS NULL;

-- V14: Quantidades invalidas (em geral deveriam ser >= 0).
SELECT 'venda' AS tabela, venda_id AS identificador, produto_id,
       qtde_vendida AS quantidade
FROM venda WHERE qtde_vendida IS NULL OR qtde_vendida < 0
UNION ALL
SELECT 'pedido_compra', pedido_id, produto_id, qtde_pedida
FROM pedido_compra WHERE qtde_pedida IS NULL OR qtde_pedida < 0
UNION ALL
SELECT 'entradas_mercadoria', ordem_compra, produto_id, qtde_recebida
FROM entradas_mercadoria WHERE qtde_recebida IS NULL OR qtde_recebida < 0;

-- V15: Precos unitarios nao positivos / negativos (revisao comercial).
SELECT venda_id, produto_id, data_emissao, valor_unitario
FROM venda WHERE valor_unitario <= 0;

-- V16: Entregas no periodo de reuniao (fevereiro/2025).
SELECT e.data_entrada, e.nro_nfe, e.produto_id, e.qtde_recebida,
       e.ordem_compra
FROM entradas_mercadoria e
WHERE e.data_entrada >= '2025-02-01'
  AND e.data_entrada < '2025-03-01'
ORDER BY e.data_entrada, e.nro_nfe;

-- V17: Produtos cadastrados com fornecedor criado automaticamente,
-- que exigem confirmacao do cliente.
SELECT p.filial_id, p.produto_id, p.idfornecedor, f.razao_social
FROM produtos_filial p JOIN fornecedor f ON f.idfornecedor = p.idfornecedor
WHERE p.idfornecedor LIKE 'AUTO_%';

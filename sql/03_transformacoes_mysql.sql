-- Parte 3 - versao MySQL 8.0+
-- Execute apos sql/01_ddl_mysql.sql e importacao.
-- Em Workbench execute o arquivo como script (usa DELIMITER).

-- 3.1 Texto de produto e data DD/MM/YYYY.
SELECT pedido_id,
       CONCAT(produto_id, ' - ', COALESCE(descricao_produto, 'Sem descricao')) AS produto,
       qtde_pedida AS quantidade_requisitada,
       DATE_FORMAT(data_pedido, '%d/%m/%Y') AS data_solicitacao
FROM pedido_compra
WHERE data_pedido >= '2025-02-01' AND data_pedido < '2025-03-01'
ORDER BY data_pedido, pedido_id;

-- 3.2 Interpretacao: mais de 10 PEDIDOS distintos por produto no periodo.
SELECT produto_id,
       CONCAT(produto_id, ' - ', MAX(descricao_produto)) AS produto,
       COUNT(DISTINCT pedido_id) AS vezes_requisitado,
       SUM(COALESCE(qtde_pedida, 0)) AS quantidade_total
FROM pedido_compra
WHERE data_pedido >= '2025-02-01' AND data_pedido < '2025-03-01'
GROUP BY produto_id
HAVING COUNT(DISTINCT pedido_id) > 10
ORDER BY vezes_requisitado DESC;

-- Consulta alternativa: pedido com mais de 10 UNIDADES.
SELECT CONCAT(produto_id, ' - ', COALESCE(descricao_produto, 'Sem descricao')) AS produto,
       qtde_pedida,
       DATE_FORMAT(data_pedido, '%d/%m/%Y') AS data_solicitacao
FROM pedido_compra
WHERE data_pedido >= '2025-02-01' AND data_pedido < '2025-03-01'
  AND qtde_pedida > 10;

-- 3.3 Trigger MySQL: sequência dedicada evita conflito com F1..F20.
CREATE TABLE IF NOT EXISTS sequencia_fornecedor_auto (
    contador BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY
) ENGINE=InnoDB;

DROP TRIGGER IF EXISTS trg_fornecedor_automatico;
DELIMITER $$
CREATE TRIGGER trg_fornecedor_automatico
BEFORE INSERT ON produtos_filial
FOR EACH ROW
BEGIN
    IF NEW.idfornecedor IS NULL OR TRIM(NEW.idfornecedor) = '' THEN
        INSERT INTO sequencia_fornecedor_auto (contador) VALUES (NULL);
        SET NEW.idfornecedor = CONCAT('AUTO_', LAST_INSERT_ID());
        INSERT INTO fornecedor (idfornecedor, razao_social)
        VALUES (NEW.idfornecedor, CONCAT('CADASTRO PROVISORIO - ', NEW.idfornecedor));
    END IF;
END$$
DELIMITER ;

-- Teste transacional (executar e conferir antes de ROLLBACK):
-- START TRANSACTION;
-- INSERT INTO produtos_filial (filial_id, produto_id, descricao)
-- VALUES (999, 'P_TESTE_TRIGGER', 'Teste trigger');
-- SELECT p.produto_id, p.idfornecedor, f.razao_social
-- FROM produtos_filial p JOIN fornecedor f ON f.idfornecedor = p.idfornecedor
-- WHERE p.filial_id = 999 AND p.produto_id = 'P_TESTE_TRIGGER';
-- ROLLBACK;

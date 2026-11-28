-- 03_transformacoes
-- Nome: yana sayuri ribeiro taketomi

USE integracao_dados;

-- Itens 1, 2 e 3: Concatenação de produto, data DD/MM/YYYY e filtro > 10
-- Interpretação: considera pedidos com quantidade requisitada (qtde_pedida) maior que 10 unidades no período.
SELECT 
    pedido_id,
    ordem_compra,
    CONCAT(produto_id, ' - ', COALESCE(descricao_produto, 'Sem descrição')) AS produto_completo,
    DATE_FORMAT(data_pedido, '%d/%m/%Y') AS data_pedido_formatada,
    DATE_FORMAT(data_entrega, '%d/%m/%Y') AS data_entrega_formatada,
    qtde_pedida
FROM pedido_compra
WHERE qtde_pedida > 10;

-- Item 4: Trigger para gerar novo idfornecedor automaticamente ao inserir produto sem fornecedor
CREATE TABLE IF NOT EXISTS seq_fornecedor (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY
);
ALTER TABLE seq_fornecedor AUTO_INCREMENT = 21;

DROP TRIGGER IF EXISTS trg_novo_fornecedor_produto;
DELIMITER //
CREATE TRIGGER trg_novo_fornecedor_produto
BEFORE INSERT ON produtos_filial
FOR EACH ROW
BEGIN
    DECLARE novo_id VARCHAR(25);
    IF NEW.idfornecedor IS NULL OR TRIM(NEW.idfornecedor) = '' THEN
        INSERT INTO seq_fornecedor VALUES (NULL);
        SET novo_id = CONCAT('F', LAST_INSERT_ID());
        
        INSERT IGNORE INTO fornecedor (idfornecedor, razao_social)
        VALUES (novo_id, CONCAT('Fornecedor Auto ', novo_id));
        
        SET NEW.idfornecedor = novo_id;
    END IF;
END;
//
DELIMITER ;

-- 01_ddl_mysql
-- Nome: [Seu Nome Completo]

CREATE DATABASE IF NOT EXISTS integracao_dados;
USE integracao_dados;

CREATE TABLE IF NOT EXISTS fornecedor (
    idfornecedor VARCHAR(25) NOT NULL,
    razao_social VARCHAR(50) NULL,
    PRIMARY KEY (idfornecedor)
);

CREATE TABLE IF NOT EXISTS produtos_filial (
    filial_id INT NULL,
    idproduto VARCHAR(25) NOT NULL,
    descricao VARCHAR(50) NULL,
    estoque DOUBLE DEFAULT 0 NOT NULL,
    preco_unitario DOUBLE DEFAULT 0 NOT NULL,
    preco_compra DOUBLE DEFAULT 0 NOT NULL,
    preco_venda DOUBLE DEFAULT 0 NOT NULL,
    idfornecedor VARCHAR(25) NULL,
    PRIMARY KEY (idproduto)
);

CREATE TABLE IF NOT EXISTS pedido_compra (
    pedido_id DOUBLE DEFAULT 0 NOT NULL,
    data_pedido DATE NULL,
    item DOUBLE DEFAULT 0 NOT NULL,
    produto_id VARCHAR(25) NULL,
    descricao_produto VARCHAR(50) NULL,
    ordem_compra DOUBLE DEFAULT 0 NOT NULL,
    qtde_pedida DOUBLE NULL,
    filial_id INT NULL,
    data_entrega DATE NULL,
    qtde_entregue DOUBLE DEFAULT 0 NOT NULL,
    qtde_pendente DOUBLE DEFAULT 0 NOT NULL,
    preco_compra DOUBLE DEFAULT 0 NULL,
    fornecedor_id VARCHAR(25) NULL,
    PRIMARY KEY (pedido_id, item)
);

CREATE TABLE IF NOT EXISTS entradas_mercadoria (
    data_entrada DATE NULL,
    nro_nfe VARCHAR(25) NOT NULL,
    item DOUBLE DEFAULT 0 NOT NULL,
    produto_id VARCHAR(25) NULL,
    descricao_produto VARCHAR(50) NULL,
    ordem_compra DOUBLE DEFAULT 0 NOT NULL,
    qtde_recebida DOUBLE NULL,
    filial_id INT NULL,
    custo_unitario DOUBLE DEFAULT 0 NOT NULL,
    PRIMARY KEY (nro_nfe, item, ordem_compra)
);

CREATE TABLE IF NOT EXISTS venda (
    venda_id BIGINT NOT NULL,
    data_emissao DATE NOT NULL,
    horariomov VARCHAR(8) DEFAULT '00:00:00' NOT NULL,
    produto_id VARCHAR(25) DEFAULT '' NOT NULL,
    qtde_vendida DOUBLE NULL,
    valor_unitario DECIMAL(12, 4) DEFAULT 0 NOT NULL,
    filial_id BIGINT DEFAULT 1 NOT NULL,
    item INT DEFAULT 0 NOT NULL,
    unidade_medida VARCHAR(3) NULL,
    PRIMARY KEY (venda_id, item)
);
